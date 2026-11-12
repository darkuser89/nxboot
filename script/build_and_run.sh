#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--debug|--logs|--telemetry) ;; *) echo "usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2;; esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${NXBOOT_BUILD_ROOT:-$ROOT_DIR/../NXBootModern-Build}"
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
CONFIGURATION="${NXBOOT_CONFIGURATION:-debug}"
case "$CONFIGURATION" in debug|release) ;; *) echo "Invalid NXBOOT_CONFIGURATION" >&2; exit 2;; esac
APP_VERSION="$(tr -d '\r\n' < "$ROOT_DIR/VERSION")"
if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Invalid VERSION" >&2; exit 2; fi
APP_NAME="NXBootModern"
APP_BUNDLE="$BUILD_ROOT/NXBoot Modern.app"
STAGING="$BUILD_ROOT/.NXBootModern-staging.app"
PREVIOUS="$BUILD_ROOT/.NXBootModern-previous.app"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/ModuleCache"

if [[ "$(uname -m)" != arm64 ]]; then echo "Dieser Build ist für Apple-Silicon-Macs vorgesehen." >&2; exit 1; fi
mkdir -p "$BUILD_ROOT"
/usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -rf "$BUILD_ROOT/.NXBootModern-icon-update"
swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT/swiftpm" \
    --configuration "$CONFIGURATION" \
    --cache-path "$BUILD_ROOT/cache" --config-path "$BUILD_ROOT/config" \
    --security-path "$BUILD_ROOT/security" --disable-sandbox --arch arm64
BIN_DIR="$(swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT/swiftpm" \
    --configuration "$CONFIGURATION" \
    --cache-path "$BUILD_ROOT/cache" --config-path "$BUILD_ROOT/config" \
    --security-path "$BUILD_ROOT/security" --disable-sandbox --arch arm64 --show-bin-path)"
rm -rf "$STAGING"
mkdir -p "$STAGING/Contents/MacOS" "$STAGING/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$STAGING/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Shared/intermezzo.bin" "$STAGING/Contents/Resources/intermezzo.bin"
cp "$ROOT_DIR/COPYING.md" "$STAGING/Contents/Resources/COPYING.md"
/usr/bin/sips -z 1024 1024 "$ROOT_DIR/Assets/AppIcon.png" \
    --out "$STAGING/Contents/Resources/AppIconTemplate.png" >/dev/null

# Build all standard macOS icon resolutions from the single versioned master.
ICON_WORK="$BUILD_ROOT/.AppIcon-work"
trap 'rm -rf "$ICON_WORK"' EXIT
mkdir -p "$ICON_WORK/AppIcon.iconset"
for ICON_SIZE in 16 32 128 256 512; do
    /usr/bin/sips -z "$ICON_SIZE" "$ICON_SIZE" "$ROOT_DIR/Assets/AppIcon.png" \
        --out "$ICON_WORK/AppIcon.iconset/icon_${ICON_SIZE}x${ICON_SIZE}.png" >/dev/null
    ICON_RETINA_SIZE=$((ICON_SIZE * 2))
    /usr/bin/sips -z "$ICON_RETINA_SIZE" "$ICON_RETINA_SIZE" "$ROOT_DIR/Assets/AppIcon.png" \
        --out "$ICON_WORK/AppIcon.iconset/icon_${ICON_SIZE}x${ICON_SIZE}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICON_WORK/AppIcon.iconset" \
    -o "$STAGING/Contents/Resources/AppIcon.icns"

cat > "$STAGING/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NXBootModern</string>
<key>CFBundleIdentifier</key><string>de.nxboot.modern</string>
<key>CFBundleName</key><string>NXBoot Modern</string>
<key>CFBundleDisplayName</key><string>NXBoot Modern</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.0.0</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Based on NXBoot © Oliver Kuckertz. GPLv3.</string>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$STAGING/Contents/Info.plist"

/usr/bin/codesign --force --sign - "$STAGING"
/usr/bin/codesign --verify --strict "$STAGING"
/usr/bin/lipo "$STAGING/Contents/MacOS/$APP_NAME" -verify_arch arm64
if [[ -e "$PREVIOUS" ]]; then echo "Unvollständiger früherer App-Austausch: $PREVIOUS" >&2; exit 1; fi
if [[ -e "$APP_BUNDLE" ]]; then mv "$APP_BUNDLE" "$PREVIOUS"; fi
mv "$STAGING" "$APP_BUNDLE"

if [[ "$MODE" != --build-only ]]; then
    if ! /usr/bin/open -n "$APP_BUNDLE"; then
        rm -rf "$APP_BUNDLE"
        if [[ -e "$PREVIOUS" ]]; then mv "$PREVIOUS" "$APP_BUNDLE"; fi
        exit 1
    fi
    sleep 2
    if ! /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
        echo "Die App blieb nach dem Start nicht aktiv." >&2
        rm -rf "$APP_BUNDLE"
        if [[ -e "$PREVIOUS" ]]; then mv "$PREVIOUS" "$APP_BUNDLE"; fi
        exit 1
    fi
fi
rm -rf "$PREVIOUS"
echo "App: $APP_BUNDLE"
case "$MODE" in
    --debug) /usr/bin/lldb -n "$APP_NAME" ;;
    --logs) /usr/bin/log stream --info --style compact --predicate 'process == "NXBootModern"' ;;
    --telemetry) /usr/bin/log stream --info --style compact --predicate 'process == "NXBootModern"' ;;
esac
