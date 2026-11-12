#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${NXBOOT_BUILD_ROOT:-$ROOT_DIR/../NXBootModern-Build}"
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
CHECKER="$BUILD_ROOT/.FinderIconSignatureCheck"
"$ROOT_DIR/script/build_and_run.sh" --build-only
trap 'rm -f "$CHECKER"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$BUILD_ROOT/ModuleCache" \
    "$ROOT_DIR/Modern/Models/JoyConAccent.swift" \
    "$ROOT_DIR/Modern/Services/AppIconRenderer.swift" \
    "$ROOT_DIR/Modern/Services/FinderIconService.swift" \
    "$ROOT_DIR/Tests/Integration/FinderIconSignatureCheck.swift" -o "$CHECKER"
"$CHECKER" "$BUILD_ROOT/NXBoot Modern.app"
