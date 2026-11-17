#!/usr/bin/env bash
set -euo pipefail
recipe() { "$ROOT/bin/recipe" postgres "$1"; }
jobs="$(getconf _NPROCESSORS_ONLN)"

flags=(--prefix="$OUT" --with-openssl --with-icu --with-lz4 --with-zstd --with-libxml --with-libxslt
  --with-uuid=e2fs --with-libedit-preferred)
if [ "$(uname)" = Darwin ]; then
  brew_prefix="$(brew --prefix)"
  export LDFLAGS="-Wl,-headerpad_max_install_names ${LDFLAGS:-}"
  export PKG_CONFIG_PATH="$brew_prefix/opt/icu4c/lib/pkgconfig:$brew_prefix/opt/openssl@3/lib/pkgconfig:$brew_prefix/opt/libxml2/lib/pkgconfig:$brew_prefix/opt/libxslt/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  cmake_extra=(-DOPENSSL_ROOT_DIR="$brew_prefix/opt/openssl@3")
  flags+=(--with-includes="$brew_prefix/opt/openssl@3/include:$brew_prefix/include"
    --with-libraries="$brew_prefix/opt/openssl@3/lib:$brew_prefix/lib")
else
  cmake_extra=()
  flags+=(--disable-rpath)
fi

cd "$SRC"
./configure "${flags[@]}"
make -j"$jobs" world-bin
make install-world-bin

export PATH="$OUT/bin:$PATH" LD_LIBRARY_PATH="$OUT/lib"
pg_config="$OUT/bin/pg_config"
for ext in $(recipe '.extensions | keys | .[]'); do
  repo="$(recipe ".extensions.$ext.repo")" tag="$(recipe ".extensions.$ext.tag")"
  url="$(recipe ".extensions.$ext.url")" style="$(recipe ".extensions.$ext.build")"
  [ -n "$url" ] || url="https://github.com/$repo/archive/refs/tags/{tag}.tar.gz"
  mkdir -p "$WORK/$ext"
  curl -fsSL --retry 3 "${url//\{tag\}/$tag}" | tar -xzf - -C "$WORK/$ext" --strip-components=1
  case "$style" in
    configure)
      (cd "$WORK/$ext" && ./configure --prefix="$OUT" --with-pgconfig="$pg_config" --without-raster --without-sfcgal && make -j"$jobs" && make install)
      ;;
    bootstrap)
      (cd "$WORK/$ext" && ./bootstrap -DPG_CONFIG="$pg_config" -DAPACHE_ONLY=ON -DREGRESS_CHECKS=OFF -DTAP_CHECKS=OFF \
        -DWARNINGS_AS_ERRORS=OFF -DSEND_TELEMETRY_DEFAULT=OFF ${cmake_extra[@]+"${cmake_extra[@]}"} && make -C build -j"$jobs" && make -C build install)
      ;;
    *)
      make -C "$WORK/$ext" -j"$jobs" USE_PGXS=1 PG_CONFIG="$pg_config"
      make -C "$WORK/$ext" install USE_PGXS=1 PG_CONFIG="$pg_config"
      ;;
  esac
  mkdir -p "$OUT/licenses/$ext"
  for f in LICENSE LICENSE.md LICENSE.txt LICENSE.TXT LICENSE-APACHE COPYING COPYRIGHT; do
    [ ! -f "$WORK/$ext/$f" ] || cp "$WORK/$ext/$f" "$OUT/licenses/$ext/"
  done
done

proj_data=/usr/share/proj
[ "$(uname)" != Darwin ] || proj_data="$brew_prefix/opt/proj/share/proj"
mkdir -p "$OUT/share/proj"
cp "$proj_data/proj.db" "$OUT/share/proj/"

python3 -I "$ROOT/lib/bundle.py" "$OUT"
cp COPYRIGHT "$OUT/LICENSE"
