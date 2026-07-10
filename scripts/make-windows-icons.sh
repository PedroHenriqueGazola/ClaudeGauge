#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p Resources/windows

python3 - <<'PY'
import math
import struct

SIZES = (16, 32)
SCALE = 4

VARIANTS = {
    "claudegauge": (0xDC, 0xDC, 0xDC),
    "claudegauge-warn": (0xFF, 0xB3, 0x40),
    "claudegauge-critical": (0xFF, 0x45, 0x3A),
}


def render(size, color):
    canvas = size * SCALE
    center = canvas / 2
    outer = canvas * 0.42
    inner = canvas * 0.26
    needle_width = canvas * 0.07
    start = math.radians(135)
    sweep = math.radians(270)

    def in_arc(x, y):
        dx, dy = x - center, y - center
        distance = math.hypot(dx, dy)
        if not inner <= distance <= outer:
            return False
        angle = math.atan2(dy, dx) % (2 * math.pi)
        offset = (angle - start) % (2 * math.pi)
        return offset <= sweep

    def in_needle(x, y):
        angle = start + sweep * 0.78
        tip = (center + math.cos(angle) * outer, center + math.sin(angle) * outer)
        dx, dy = tip[0] - center, tip[1] - center
        length = math.hypot(dx, dy)
        t = max(0, min(1, ((x - center) * dx + (y - center) * dy) / (length * length)))
        px, py = center + t * dx, center + t * dy
        return math.hypot(x - px, y - py) <= needle_width

    rows = []
    for py in range(size):
        row = []
        for px in range(size):
            coverage = 0
            for sy in range(SCALE):
                for sx in range(SCALE):
                    x = px * SCALE + sx + 0.5
                    y = py * SCALE + sy + 0.5
                    if in_arc(x, y) or in_needle(x, y):
                        coverage += 1
            alpha = round(255 * coverage / (SCALE * SCALE))
            row.append((color[0], color[1], color[2], alpha))
        rows.append(row)
    return rows


def dib(size, rows):
    header = struct.pack("<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    pixels = bytearray()
    for row in reversed(rows):
        for r, g, b, a in row:
            pixels += struct.pack("<BBBB", b, g, r, a)
    mask_stride = ((size + 31) // 32) * 4
    mask = b"\x00" * (mask_stride * size)
    return header + bytes(pixels) + mask


def write_ico(path, color):
    images = [dib(size, render(size, color)) for size in SIZES]
    entries = bytearray()
    offset = 6 + 16 * len(SIZES)
    for size, image in zip(SIZES, images):
        entries += struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(image), offset)
        offset += len(image)
    with open(path, "wb") as f:
        f.write(struct.pack("<HHH", 0, 1, len(SIZES)))
        f.write(bytes(entries))
        for image in images:
            f.write(image)


for name, color in VARIANTS.items():
    write_ico(f"Resources/windows/{name}.ico", color)
    print(f"Resources/windows/{name}.ico")
PY
