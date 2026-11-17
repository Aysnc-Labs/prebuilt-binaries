#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
server="$root/libexec/redis-server"

case "${1:-}" in -v | --version | -h | --help | --test-memory | --check-system) exec "$server" "$@" ;; esac
case " $* " in *" --sentinel "*) exec "$server" "$@" ;; esac

modules=()
for module in "$root"/lib/redis/modules/*.so; do
  modules+=(--loadmodule "$module")
done
if [ $# -gt 0 ] && { [ "$1" = - ] || [ "${1#-}" = "$1" ]; }; then
  config="$1"
  shift
  exec "$server" "$config" "${modules[@]}" "$@"
fi
exec "$server" "${modules[@]}" "$@"
