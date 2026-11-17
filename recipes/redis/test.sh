#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
export REDIS_PORT=56379

if ! command -v mise >/dev/null; then
  if [ "$(uname)" = Linux ] && [ "$(id -u)" = 0 ]; then
    apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null
  fi
  for i in 1 2 3; do curl -fsSL https://mise.run | sh >/dev/null && break; [ $i = 3 ] && exit 1; sleep 10; done
  export PATH="$HOME/.local/bin:$PATH"
fi
php="github:aysnc-labs/prebuilt-binaries@$("$ROOT/bin/recipe" php tag)"
mise install -q "$php" node@24
PATH="$(mise where "$php")/bin:$(mise where node@24)/bin:$PATH"

echo "== shared libraries"
lib="$BIN_DIR/../lib"
if [ "$(uname)" = Darwin ]; then
  outside="$(for f in "$BIN_DIR/../libexec/redis-server" "$BIN_DIR"/redis-cli "$lib"/redis/modules/*.so "$lib"/*.dylib; do
    [ ! -e "$f" ] || otool -L "$f" | tail -n +2; done | awk '{print $1}' | grep -vE '^(@rpath/|@loader_path/|/usr/lib/|/System/)' | sort -u || true)"
else
  outside="$(for f in "$BIN_DIR/../libexec/redis-server" "$BIN_DIR"/redis-cli "$lib"/redis/modules/*.so "$lib"/*.so*; do
    [ ! -e "$f" ] || ldd "$f" 2>/dev/null || true; done | grep -E 'not found' | sort -u || true)"
fi
[ -z "$outside" ] || { echo "$outside"; echo "libraries outside the archive" >&2; exit 1; }
echo ok

echo "== server"
redis-server --port "$REDIS_PORT" --bind 127.0.0.1 --dir "$work" --save "" --appendonly no \
  --logfile "$work/redis.log" --daemonize yes
stop() { redis-cli -p "$REDIS_PORT" shutdown nosave >/dev/null 2>&1 || true; rm -rf "$work"; }
trap stop EXIT
for _ in $(seq 1 50); do [ "$(redis-cli -p "$REDIS_PORT" ping 2>/dev/null)" = PONG ] && break; sleep 0.1; done
redis-cli -p "$REDIS_PORT" info server | grep -E '^redis_version:'
[ "$(redis-cli -p "$REDIS_PORT" eval "return cmsgpack.unpack(cmsgpack.pack(cjson.decode('[1]')))[1]" 0)" = 1 ]
echo ok

echo "== modules"
cli() { redis-cli -p "$REDIS_PORT" "$@"; }
expect() { local want=$1; shift; local got; got="$(cli "$@")"; [ "$got" = "$want" ] || { echo "$*: got $got, want $want" >&2; exit 1; }; }
loaded="$(cli module list)"
for name in ReJSON search timeseries bf vectorset; do
  grep -qx "$name" <<<"$loaded" || { echo "$loaded"; echo "module $name isn't loaded" >&2; exit 1; }
done
expect OK json.set doc '$' '{"a":[1,2]}'
expect '[2]' json.get doc '$.a[1]'
expect 1 ts.add temps 1 20.5
expect 1 bf.add seen alice
expect 1 bf.exists seen alice
expect 1 vadd points VALUES 2 1 0 a
expect 1 vcard points
echo ok

echo "== Laravel"
php "$here/test/laravel.php"

echo "== Next.js and NestJS"
cd "$here/test"
[ -d node_modules ] || npm ci --silent >/dev/null
node node-clients.mjs

echo "== benchmark"
redis-benchmark -p "$REDIS_PORT" -q -n 2000 -t set,get
