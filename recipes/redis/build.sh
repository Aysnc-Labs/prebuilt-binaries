#!/usr/bin/env bash
set -euo pipefail
cd "$SRC"
GIT_CEILING_DIRECTORIES="$(dirname "$SRC")"
export GIT_CEILING_DIRECTORIES
make -C src -j"$(getconf _NPROCESSORS_ONLN)"
make -C src install PREFIX="$OUT"
strip "$OUT/bin/redis-server" "$OUT/bin/redis-cli" "$OUT/bin/redis-benchmark"
cp LICENSE.txt "$OUT/LICENSE"
for dep in fpconv hdr_histogram hiredis jemalloc lua tre xxhash; do
  mkdir -p "$OUT/licenses/$dep"
  for f in COPYING COPYING.txt COPYRIGHT LICENSE LICENSE.txt; do
    [ ! -f "deps/$dep/$f" ] || cp "deps/$dep/$f" "$OUT/licenses/$dep/"
  done
done
mkdir -p "$OUT/licenses/linenoise"
sed -n '/Copyright/,/\*\//p' deps/linenoise/linenoise.c > "$OUT/licenses/linenoise/LICENSE"
