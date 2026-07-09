#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

echo "Building release binary..."
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/claudegauge"

install -Dm755 "$BIN_PATH" "$BIN_DIR/claudegauge"

for icon in claudegauge claudegauge-warn claudegauge-critical; do
  install -Dm644 "Resources/linux/$icon.png" "$DATA_DIR/icons/hicolor/22x22/apps/$icon.png"
  install -Dm644 "Resources/linux/$icon.png" "$DATA_DIR/claudegauge/icons/$icon.png"
done

mkdir -p "$DATA_DIR/applications"
cat > "$DATA_DIR/applications/claudegauge.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=ClaudeGauge
Comment=Uso do Claude na bandeja do sistema
Exec=$BIN_DIR/claudegauge
Icon=claudegauge
Terminal=false
Categories=Utility;
DESKTOP

command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q "$DATA_DIR/icons/hicolor" || true

echo "Done: $BIN_DIR/claudegauge"
echo "Rode com:  claudegauge"
echo "Login próprio (opcional):  claudegauge login"
