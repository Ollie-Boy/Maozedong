#!/usr/bin/env python3
"""Generate a simple 50s–70s style hand-drawn look app icon (no external deps)."""
from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path


def write_png_rgba(path: Path, width: int, height: int, pixel_fn) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            r, g, b, a = pixel_fn(x, y)
            raw.extend((r, g, b, a))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    compressed = zlib.compress(bytes(raw), 9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    path.write_bytes(png)


def main() -> None:
    rng = random.Random(42)
    root = Path(__file__).resolve().parents[1]
    out = root / "MaozedongReader" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    w = h = 1024

    # Warm paper / poster board
    def paper(x: int, y: int) -> tuple[int, int, int]:
        t = 0.15 * math.sin(x * 0.02) + 0.12 * math.sin(y * 0.017)
        r = int(255 * (0.94 + t * 0.04))
        g = int(248 * (0.90 + t * 0.03))
        b = int(220 * (0.82 + t * 0.04))
        return (min(255, r), min(255, g), min(255, b))

    cx, cy = w * 0.5, h * 0.42
    rx, ry = w * 0.22, h * 0.30

    def in_ellipse(px: float, py: float) -> bool:
        dx = (px - cx) / rx
        dy = (py - cy) / ry
        return dx * dx + dy * dy <= 1.0

    def noise_edge(d: float) -> float:
        return d + rng.uniform(-2.8, 2.8)

    def pixel(x: int, y: int) -> tuple[int, int, int, int]:
        pr, pg, pb = paper(x, y)
        fx, fy = float(x), float(y)

        # Wavy red "brush" halo (poster paint)
        wave = 6 * math.sin(fx * 0.08 + fy * 0.05)
        if in_ellipse(fx + wave, fy + wave * 0.4):
            # Silhouette fill — dark brown-black ink
            return (28, 22, 18, 255)

        dist = math.hypot(fx - cx, fy - cy)
        if 0.88 * min(rx, ry) < dist < 1.12 * max(rx, ry) + noise_edge(0):
            # Rough vermilion ring
            return (200, 36, 42, 255)

        # Small gold star (upper right of portrait)
        sx, sy = cx + rx * 0.55, cy - ry * 0.75
        if math.hypot(fx - sx, fy - sy) < 38:
            return (230, 190, 55, 255)

        return (pr, pg, pb, 255)

    write_png_rgba(out, w, h, pixel)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
