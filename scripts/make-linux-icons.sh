#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p Resources/linux

python3 - <<'PY'
import math
import struct
import zlib

SIZE = 22
SCALE = 4
CANVAS = SIZE * SCALE
CENTER = CANVAS / 2
OUTER = CANVAS * 0.42
INNER = CANVAS * 0.26
NEEDLE_WIDTH = CANVAS * 0.07
START = math.radians(135)
SWEEP = math.radians(270)

VARIANTS = {
    "claudegauge": (0xDC, 0xDC, 0xDC),
    "claudegauge-warn": (0xFF, 0xB3, 0x40),
    "claudegauge-critical": (0xFF, 0x45, 0x3A),
}


def in_arc(x, y):
    dx, dy = x - CENTER, y - CENTER
    distance = math.hypot(dx, dy)
    if not INNER <= distance <= OUTER:
        return False
    angle = math.atan2(dy, dx) % (2 * math.pi)
    offset = (angle - START) % (2 * math.pi)
    return offset <= SWEEP


def in_needle(x, y):
    angle = START + SWEEP * 0.78
    tip = (CENTER + math.cos(angle) * OUTER, CENTER + math.sin(angle) * OUTER)
    dx, dy = tip[0] - CENTER, tip[1] - CENTER
    length = math.hypot(dx, dy)
    t = max(0, min(1, ((x - CENTER) * dx + (y - CENTER) * dy) / (length * length)))
    px, py = CENTER + t * dx, CENTER + t * dy
    return math.hypot(x - px, y - py) <= NEEDLE_WIDTH


def render(color):
    rows = []
    for py in range(SIZE):
        row = bytearray([0])
        for px in range(SIZE):
            coverage = 0
            for sy in range(SCALE):
                for sx in range(SCALE):
                    x = px * SCALE + sx + 0.5
                    y = py * SCALE + sy + 0.5
                    if in_arc(x, y) or in_needle(x, y):
                        coverage += 1
            alpha = round(255 * coverage / (SCALE * SCALE))
            row.extend([color[0], color[1], color[2], alpha])
        rows.append(bytes(row))
    return b"".join(rows)


def chunk(tag, data):
    payload = tag + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload))


def write_png(path, color):
    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    body = zlib.compress(render(color), 9)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", header))
        f.write(chunk(b"IDAT", body))
        f.write(chunk(b"IEND", b""))


for name, color in VARIANTS.items():
    write_png(f"Resources/linux/{name}.png", color)
    print(f"Resources/linux/{name}.png")
PY
