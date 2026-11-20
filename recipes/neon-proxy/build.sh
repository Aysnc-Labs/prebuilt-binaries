#!/usr/bin/env bash
set -euo pipefail
if ! command -v rustup >/dev/null; then
  "$ROOT/bin/fetch" neon-proxy ".rustup.downloads.\"$TARGET\"" "$WORK/rustup-init"
  chmod +x "$WORK/rustup-init"
  "$WORK/rustup-init" -y --no-modify-path --profile minimal --default-toolchain none
  export PATH="$HOME/.cargo/bin:$PATH"
fi
cd "$SRC"
rustup show active-toolchain >/dev/null 2>&1 || rustup toolchain install
cargo build --locked --release -p proxy --bin proxy --features testing
mkdir -p "$OUT/bin"
cp target/release/proxy "$OUT/bin/neon-proxy"
strip "$OUT/bin/neon-proxy"
cp LICENSE "$OUT/LICENSE"
