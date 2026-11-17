#!/usr/bin/env bash
set -euo pipefail

recipe() { "$ROOT/bin/recipe" php "$1"; }
spc_version="$(recipe .spc.version)"
exts="$(recipe '.spc.extensions | join(",")')"
libs="$(recipe '.spc.libs | join(",")')"

case "$TARGET" in
  macos-arm64) spc_asset="spc-macos-aarch64" ;;
  linux-x64) spc_asset="spc-linux-x86_64" ;;
  linux-arm64) spc_asset="spc-linux-aarch64" ;;
  *) echo "php: no spc for $TARGET" >&2; exit 1 ;;
esac

mkdir -p "$WORK/spc" "$CACHE/downloads" "$CACHE/spc-$spc_version"
spc="$CACHE/spc-$spc_version/spc"
if [ ! -x "$spc" ]; then
  curl -fsSL --retry 3 "https://github.com/crazywhalecc/static-php-cli/releases/download/$spc_version/$spc_asset.tar.gz" |
    tar -xz -C "$CACHE/spc-$spc_version"
fi
cd "$WORK/spc"
ln -sfn "$CACHE/downloads" downloads

if command -v apt-get >/dev/null; then
  if [ "$(id -u)" = 0 ]; then apt-get update -qq; else sudo apt-get update -qq; fi
fi
if [ "$(uname)" = Linux ] && [ "$(id -u)" != 0 ]; then
  status=0
  sudo -E "$spc" doctor --auto-fix || status=$?
  sudo chown -R "$(id -u):$(id -g)" "$WORK/spc" "$CACHE"
  [ "$status" = 0 ] || exit "$status"
else
  "$spc" doctor --auto-fix
fi

"$spc" download --for-extensions="$exts" --for-libs="$libs" --retry=3 \
  --custom-url="php-src:https://www.php.net/distributions/php-$VERSION.tar.xz"
"$spc" build "$exts" --with-libs="$libs" --build-cli --build-fpm
"$spc" dump-license --for-extensions="$exts" --for-libs="$libs" --dump-dir="$OUT/licenses"

mkdir -p "$OUT/bin"
cp buildroot/bin/php buildroot/bin/php-fpm "$OUT/bin/"
cp source/php-src/LICENSE "$OUT/LICENSE"
