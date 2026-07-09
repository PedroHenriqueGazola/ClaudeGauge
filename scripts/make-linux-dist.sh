#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

DIST="claudegauge-linux-x86_64"

echo "Building release binary (static Swift stdlib)..."
swift build -c release --product claudegauge --static-swift-stdlib
BIN="$(swift build -c release --show-bin-path)/claudegauge"

# Garante os ícones (gera se faltarem no checkout).
[ -f Resources/linux/claudegauge.png ] || ./scripts/make-linux-icons.sh

rm -rf "$DIST" "$DIST.tar.gz"
mkdir -p "$DIST"
install -m755 "$BIN" "$DIST/claudegauge"
install -m644 \
  Resources/linux/claudegauge.png \
  Resources/linux/claudegauge-warn.png \
  Resources/linux/claudegauge-critical.png \
  "$DIST/"

# Instalador da distribuição pronta: copia o binário/ícones (sem compilar).
cat > "$DIST/install.sh" <<'SH'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

install -Dm755 claudegauge "$BIN_DIR/claudegauge"
for icon in claudegauge claudegauge-warn claudegauge-critical; do
  install -Dm644 "$icon.png" "$DATA_DIR/icons/hicolor/22x22/apps/$icon.png"
  install -Dm644 "$icon.png" "$DATA_DIR/claudegauge/icons/$icon.png"
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

echo "Instalado: $BIN_DIR/claudegauge"
echo "Rode com:  claudegauge   (garanta que ~/.local/bin está no PATH)"
SH
chmod +x "$DIST/install.sh"

cat > "$DIST/LEIAME.txt" <<'TXT'
ClaudeGauge — Linux (x86_64)

Requer as libs de sistema (runtime):
  sudo apt-get install libayatana-appindicator3-dev libnotify-dev

Instalar:
  ./install.sh
  claudegauge

Login próprio (opcional, sem Claude Code):  claudegauge login
GNOME puro precisa da extensão "AppIndicator Support".
O binário tem a stdlib do Swift embutida (não precisa do Swift instalado).
TXT

tar -czf "$DIST.tar.gz" "$DIST"
echo "Done: $DIST.tar.gz"
