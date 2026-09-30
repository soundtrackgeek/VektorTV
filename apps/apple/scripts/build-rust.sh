#!/bin/bash
set -euo pipefail
export PATH="$HOME/.cargo/bin:$PATH"
root="$(cd "$(dirname "$0")/../../.." && pwd)"
toolchain=1.98.1
case "${PLATFORM_NAME:-}" in
  iphoneos) target=aarch64-apple-ios ;;
  iphonesimulator)
    case "${CURRENT_ARCH:-arm64}" in
      x86_64) target=x86_64-apple-ios ;;
      *) target=aarch64-apple-ios-sim ;;
    esac ;;
  appletvos) target=aarch64-apple-tvos ;;
  appletvsimulator) target=aarch64-apple-tvos-sim ;;
  *) printf 'Unsupported Apple platform: %s\n' "${PLATFORM_NAME:-unset}" >&2; exit 1 ;;
esac
if ! rustup run "$toolchain" rustc --version >/dev/null 2>&1; then
  printf 'Install Rust with: rustup toolchain install %s --profile minimal\n' "$toolchain" >&2
  exit 1
fi
export CARGO_TARGET_DIR="$root/apps/apple/build/rust"
profile=debug
set -- cargo +"$toolchain" build --manifest-path "$root/Cargo.toml" --locked -p vektortv-apple --target "$target"
if [[ "${CONFIGURATION:-Debug}" == Release ]]; then profile=release; set -- "$@" --release; fi
"$@"
mkdir -p "${BUILT_PRODUCTS_DIR:?}"
cp "$CARGO_TARGET_DIR/$target/$profile/libvektortv_apple.a" "$BUILT_PRODUCTS_DIR/libvektortv_apple.a"
