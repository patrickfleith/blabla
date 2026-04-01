#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "Usage: ./scripts/build_app.sh [debug|release]" >&2
  exit 1
fi

CACHE_ROOT="${TMPDIR%/}/blabla-swiftpm-cache"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swiftpm"

export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$CACHE_ROOT/swiftpm"

pushd "$ROOT_DIR" >/dev/null

swift build -c "$CONFIGURATION" --product Blabla
BIN_PATH="$(swift build -c "$CONFIGURATION" --product Blabla --show-bin-path)"

APP_DIR="$ROOT_DIR/dist/Blabla.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH/Blabla" "$MACOS_DIR/Blabla"

cat > "$CONTENTS_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Blabla</string>
    <key>CFBundleExecutable</key>
    <string>Blabla</string>
    <key>CFBundleIdentifier</key>
    <string>com.astro.blabla</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Blabla</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Blabla needs microphone access to record audio for transcription.</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

popd >/dev/null

echo "Built $APP_DIR"
