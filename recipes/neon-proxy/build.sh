#!/usr/bin/env bash
set -euo pipefail
cd "$SRC"
rustup show active-toolchain >/dev/null 2>&1 || rustup toolchain install
cargo build --locked --release -p proxy --bin proxy --features testing
mkdir -p "$OUT/bin"
cp target/release/proxy "$OUT/bin/neon-proxy"
strip "$OUT/bin/neon-proxy"
cp LICENSE "$OUT/LICENSE"
