#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
port=55432
as_pg() { "$@"; }
if [ "$(id -u)" = 0 ]; then
  id pgtest >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin pgtest
  d="$BIN_DIR"; while [ "$d" != / ]; do chmod o+x "$d"; d="$(dirname "$d")"; done
  chown pgtest "$work"
  as_pg() { runuser -u pgtest -- "$@"; }
fi
stop() { as_pg pg_ctl -D "$work/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$work"; }
trap stop EXIT

echo "== shared libraries"
if [ "$(uname)" = Darwin ]; then
  outside="$(for f in "$BIN_DIR"/* "$BIN_DIR"/../lib/*.dylib; do otool -L "$f" | tail -n +2; done |
    awk '{print $1}' | grep -vE '^(@rpath/|/usr/lib/|/System/)' | sort -u || true)"
else
  outside="$(for f in "$BIN_DIR"/* "$BIN_DIR"/../lib/*.so*; do ldd "$f" 2>/dev/null || true; done |
    grep -E 'not found' | sort -u || true)"
fi
[ -z "$outside" ] || { echo "$outside"; echo "libraries outside the archive" >&2; exit 1; }
echo ok

echo "== server"
as_pg initdb -D "$work/data" -U postgres --auth=trust --encoding=UTF8 --locale-provider=icu --icu-locale=en >/dev/null
cat >> "$work/data/postgresql.conf" <<CONF
port = $port
listen_addresses = '127.0.0.1'
unix_socket_directories = '$work'
shared_preload_libraries = 'timescaledb,pg_cron,pg_stat_statements,pgaudit,pg_hint_plan'
timescaledb.telemetry_level = off
cron.database_name = 'postgres'
wal_level = logical
output_plugin_libraries = 'wal2json'
CONF
as_pg pg_ctl -D "$work/data" -l "$work/log" -w start >/dev/null || { cat "$work/log"; exit 1; }
psql -h 127.0.0.1 -p "$port" -U postgres -v ON_ERROR_STOP=1 -qtAX -f "$here/test/extensions.sql"

echo "== client tools"
pg_dump -h 127.0.0.1 -p "$port" -U postgres -s postgres | grep -c 'CREATE EXTENSION' | sed 's/^/extensions in the dump: /'
pg_repack --version
