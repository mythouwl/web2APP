#!/usr/bin/env bash
# Package the swift-built WebWrap binary + WebWrapRuntime helper into 灵镜.app
set -euo pipefail

CONFIG="${1:-debug}"
BUILD_DIR=".build/$CONFIG"
APP_NAME="灵镜"
APP_DIR="build/${APP_NAME}.app"

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

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>WebWrap</string>
  <key>CFBundleIdentifier</key><string>com.webwrap.generator</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST

# Carry over a baked-in icon if present in repo, else from /tmp
if [[ -f "Resources/AppIcon.icns" ]]; then
  cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
elif [[ -f "/tmp/AppIcon.icns" ]]; then
  cp "/tmp/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"
