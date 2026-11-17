#!/usr/bin/env bash
set -euo pipefail
PROXY_BIN="${BIN_DIR:?}/neon-proxy"
PGPORT="${PGPORT:-5432}"
WSS_PORT="${WSS_PORT:-4444}"
WORK="${WORK:-/tmp/neon-proxy-test}"
PG_USER=pgsmoke

if ! command -v mise >/dev/null; then
  if [ "$(uname)" = Linux ] && [ "$(id -u)" = 0 ]; then
    apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null
  fi
  for i in 1 2 3; do curl -fsSL https://mise.run | sh >/dev/null && break; [ $i = 3 ] && exit 1; sleep 10; done
  export PATH="$HOME/.local/bin:$PATH"
fi
postgres="github:aysnc-labs/prebuilt-binaries@$("$ROOT/bin/recipe" postgres tag)"
mise install -q "$postgres" node@24
PGBIN="$(mise where "$postgres")/bin"
NODEBIN="$(mise where node@24)/bin"
export PATH="$PGBIN:$NODEBIN:$PATH"

run_pg() { "$@"; }
if [ "$(id -u)" = 0 ]; then
  d="$PGBIN"; while [ "$d" != / ]; do chmod o+x "$d"; d=$(dirname "$d"); done
  id "$PG_USER" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$PG_USER"
  run_pg() { runuser -u "$PG_USER" -- "$@"; }
fi

rm -rf "$WORK" && mkdir -p "$WORK" && echo postgres > "$WORK/pw"
if [ "$(id -u)" = 0 ]; then chown -R "$PG_USER": "$WORK"; fi
run_pg initdb -D "$WORK/data" -U postgres --auth=scram-sha-256 --pwfile="$WORK/pw" \
  --encoding=UTF8 --locale-provider=builtin --locale=C.UTF-8 >/dev/null
run_pg pg_ctl -D "$WORK/data" -o "-p $PGPORT -k $WORK -c listen_addresses=127.0.0.1" -l "$WORK/pg.log" -w start >/dev/null
export PGPASSWORD=postgres
q() { psql -h 127.0.0.1 -p "$PGPORT" -U postgres -qtAX "$@"; }
q -c "select version()"

q -c "create schema neon_control_plane; create table neon_control_plane.endpoints(endpoint_id text primary key, allowed_ips text)"
for db in alpha beta; do
  q -c "create database $db"
  q -d $db -c "create table t(name text); insert into t values ('$db row')"
done

LOGFMT=text "$PROXY_BIN" --auth-backend=postgres \
  --auth-endpoint="postgres://postgres:postgres@127.0.0.1:$PGPORT/postgres" \
  --wss "127.0.0.1:$WSS_PORT" > "$WORK/proxy.log" 2>&1 &
PROXY_PID=$!
for _ in $(seq 1 50); do (exec 3<>/dev/tcp/127.0.0.1/"$WSS_PORT") 2>/dev/null && break; sleep 0.2; done

cd "$(dirname "$0")/test"
[ -d node_modules ] || npm ci --silent >/dev/null
PROXY="localhost:$WSS_PORT" PGPORT="$PGPORT" node two-dbs.mjs || { tail -30 "$WORK/proxy.log"; exit 1; }

kill $PROXY_PID; run_pg pg_ctl -D "$WORK/data" -m fast stop >/dev/null
