#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${NXBOOT_BUILD_ROOT:-$ROOT_DIR/../NXBootModern-Build}"
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/ModuleCache"
exec swift test --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT/swiftpm" \
    --cache-path "$BUILD_ROOT/cache" --config-path "$BUILD_ROOT/config" \
    --security-path "$BUILD_ROOT/security" --disable-sandbox --arch arm64
