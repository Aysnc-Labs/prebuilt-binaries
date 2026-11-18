#!/usr/bin/env bash
set -euo pipefail
recipe() { "$ROOT/bin/recipe" redis "$1"; }
make="make"
if [ "$(uname)" = Darwin ]; then
  make=gmake
  openssl="$(brew --prefix openssl@3)"
  PATH="$openssl/bin:$PATH"
  export PKG_CONFIG_PATH="$openssl/lib/pkgconfig"
fi
cd "$SRC"

boost_tag="$(recipe .boost.tag)"
if ! grep -q "boost-$boost_tag-b2-nodocs.tar.gz" modules/redisearch/src/build/boost/boost.cmake; then
  grep -o 'boost-[0-9.]*-b2-nodocs.tar.gz' modules/redisearch/src/build/boost/boost.cmake >&2
  echo "RediSearch wants another Boost: move .boost.tag in recipe.yaml and run bin/lock redis" >&2
  exit 1
fi
boost="modules/redisearch/src/.install/boost"
"$ROOT/bin/fetch" redis .boost "$WORK/boost.tar.gz"
mkdir -p "$boost"
tar -xzf "$WORK/boost.tar.gz" -C "$boost" --strip-components=1

out="$OUT"
above_src="$(dirname "$SRC")"
modules_make() {
  env -u ROOT -u VERSION -u TARGET -u SRC -u WORK -u CACHE -u OUT GIT_CEILING_DIRECTORIES="$above_src" LTO=0 "$make" "$@"
}
modules_make -j"$(getconf _NPROCESSORS_ONLN)" all
modules_make -C src install PREFIX="$out"

mkdir -p "$OUT/libexec" "$OUT/lib/redis/modules"
mv "$OUT/bin/redis-server" "$OUT/libexec/redis-server"
for tool in redis-check-aof redis-check-rdb redis-sentinel; do
  ln -sf ../libexec/redis-server "$OUT/bin/$tool"
done
cp "$ROOT/recipes/redis/redis-server.sh" "$OUT/bin/redis-server"
awk '$1 == "loadmodule:" { print $2 }' modules/modules.yaml | while read -r module; do
  [ -f "$module" ] || { echo "module $module didn't build" >&2; exit 1; }
  cp "$module" "$OUT/lib/redis/modules/"
  name="$(basename "$(dirname "$module")")"
  mkdir -p "$OUT/licenses/$name"
  cp modules/"$name"/src/LICENSE* "$OUT/licenses/$name/"
done
strip "$OUT/libexec/redis-server" "$OUT/bin/redis-cli" "$OUT/bin/redis-benchmark"
strip -x "$OUT"/lib/redis/modules/*.so

cp LICENSE.txt "$OUT/LICENSE"
for dep in fpconv hdr_histogram hiredis jemalloc lua tre xxhash; do
  mkdir -p "$OUT/licenses/$dep"
  for f in COPYING COPYING.txt COPYRIGHT LICENSE LICENSE.txt; do
    [ ! -f "deps/$dep/$f" ] || cp "deps/$dep/$f" "$OUT/licenses/$dep/"
  done
done
mkdir -p "$OUT/licenses/linenoise" "$OUT/licenses/boost"
sed -n '/Copyright/,/\*\//p' deps/linenoise/linenoise.c > "$OUT/licenses/linenoise/LICENSE"
cp "$boost/LICENSE_1_0.txt" "$OUT/licenses/boost/"

python3 -I "$ROOT/lib/bundle.py" "$OUT"
