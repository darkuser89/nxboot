#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
    echo "Release archives are produced by GitHub Actions." >&2
    exit 2
fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(tr -d '\r\n' < "$ROOT_DIR/VERSION")"
if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Invalid VERSION" >&2; exit 2; fi
APP_BUNDLE="$NXBOOT_BUILD_ROOT/NXBoot Modern.app"
RELEASE_DIR="$RUNNER_TEMP/NXBootModern-Release"
ZIP_NAME="NXBoot-Modern-v${APP_VERSION}-macOS-arm64.zip"

/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
/usr/bin/lipo "$APP_BUNDLE/Contents/MacOS/NXBootModern" -verify_arch arm64
BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
[[ "$BUNDLE_VERSION" == "$APP_VERSION" ]]
mkdir -p "$RELEASE_DIR"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$RELEASE_DIR/$ZIP_NAME"
(
    cd "$RELEASE_DIR"
    /usr/bin/shasum -a 256 "$ZIP_NAME" > SHA256SUMS.txt
)
{
    echo "version=$APP_VERSION"
    echo "directory=$RELEASE_DIR"
} >> "$GITHUB_OUTPUT"
