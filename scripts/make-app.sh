#!/bin/bash
set -euo pipefail

APP_NAME="ClaudeGauge"
DISPLAY_NAME="Claude Gauge"
BUNDLE_ID="com.pedrogazola.claudegauge"
VERSION="${APP_VERSION:-0.1.0}"
VERSION="${VERSION#v}"

cd "$(dirname "$0")/.."

echo "Building release binary..."
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"

APP_BUNDLE="$APP_NAME.app"
echo "Assembling ${APP_BUNDLE}..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
  if security find-identity -p codesigning 2>/dev/null | grep -q "ClaudeGauge Dev"; then
    SIGN_IDENTITY="ClaudeGauge Dev"
  else
    SIGN_IDENTITY="-"
  fi
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "Assinando ad-hoc (a cada rebuild o macOS repede acesso ao Keychain)."
  echo "Para parar de repedir: crie um cert 'ClaudeGauge Dev' (veja README)."
else
  echo "Assinando com identidade estável: $SIGN_IDENTITY"
fi
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
echo "Run it with:  open $APP_BUNDLE"
