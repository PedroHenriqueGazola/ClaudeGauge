#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
MASTER="$TMP/master.png"
RENDER="$TMP/render.swift"

cat > "$RENDER" <<'SWIFT'
import AppKit

let outPath = CommandLine.arguments[1]
let px = 1024

let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let canvas = CGFloat(px)
let squircle = NSRect(x: 56, y: 56, width: canvas - 112, height: canvas - 112)
let clip = NSBezierPath(roundedRect: squircle, xRadius: 205, yRadius: 205)
clip.addClip()

let gradient = NSGradient(
  starting: NSColor(srgbRed: 0.886, green: 0.545, blue: 0.376, alpha: 1),
  ending: NSColor(srgbRed: 0.729, green: 0.365, blue: 0.231, alpha: 1))!
gradient.draw(in: squircle, angle: -90)

let configuration = NSImage.SymbolConfiguration(pointSize: 560, weight: .semibold)
  .applying(NSImage.SymbolConfiguration(paletteColors: [
    NSColor(srgbRed: 0.99, green: 0.965, blue: 0.933, alpha: 1)
  ]))
if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
  .withSymbolConfiguration(configuration)
{
  let size = symbol.size
  symbol.draw(in: NSRect(
    x: (canvas - size.width) / 2, y: (canvas - size.height) / 2,
    width: size.width, height: size.height))
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: outPath))
SWIFT

echo "Renderizando master 1024px..."
swift "$RENDER" "$MASTER"

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$MASTER" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$MASTER" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
cp "$MASTER" docs/icon.png 2>/dev/null || true

echo "Gerado: Resources/AppIcon.icns"
