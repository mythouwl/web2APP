#!/usr/bin/env bash
# Package the swift-built WebWrap executable + WebWrapRuntime helper into WebWrap.app
set -euo pipefail

CONFIG="${1:-debug}"
BUILD_DIR=".build/$CONFIG"
APP_DIR="build/WebWrap.app"

if [[ ! -x "$BUILD_DIR/WebWrap" ]]; then
  echo "error: $BUILD_DIR/WebWrap not found. Run 'swift build' first." >&2
  exit 1
fi
if [[ ! -x "$BUILD_DIR/WebWrapRuntime" ]]; then
  echo "error: $BUILD_DIR/WebWrapRuntime not found. Run 'swift build' first." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/WebWrap"        "$APP_DIR/Contents/MacOS/WebWrap"
cp "$BUILD_DIR/WebWrapRuntime" "$APP_DIR/Contents/Resources/WebWrapRuntime"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>WebWrap</string>
  <key>CFBundleIdentifier</key><string>com.webwrap.generator</string>
  <key>CFBundleName</key><string>WebWrap</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"
