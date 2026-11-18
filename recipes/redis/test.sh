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
mise install -q "$php" node@latest
PATH="$(mise where "$php")/bin:$(mise where node@latest)/bin:$PATH"

echo "== server"
redis-server --port "$REDIS_PORT" --bind 127.0.0.1 --dir "$work" --save "" --appendonly no \
  --logfile "$work/redis.log" --daemonize yes
stop() { redis-cli -p "$REDIS_PORT" shutdown nosave >/dev/null 2>&1 || true; rm -rf "$work"; }
trap stop EXIT
for _ in $(seq 1 50); do [ "$(redis-cli -p "$REDIS_PORT" ping 2>/dev/null)" = PONG ] && break; sleep 0.1; done
redis-cli -p "$REDIS_PORT" info server | grep -E '^redis_version:'
[ "$(redis-cli -p "$REDIS_PORT" eval "return cmsgpack.unpack(cmsgpack.pack(cjson.decode('[1]')))[1]" 0)" = 1 ]
echo ok

echo "== Laravel"
php "$here/test/laravel.php"

echo "== Next.js and NestJS"
cd "$here/test"
[ -d node_modules ] || npm ci --silent >/dev/null
node node-clients.mjs

echo "== benchmark"
redis-benchmark -p "$REDIS_PORT" -q -n 2000 -t set,get
