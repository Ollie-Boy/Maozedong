#!/usr/bin/env python3
"""Generate a simple 1024×1024 PNG app icon (red field + gold sun + light column). No dependencies."""
from __future__ import annotations

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
    root = Path(__file__).resolve().parents[1]
    out = root / "MaozedongReader" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    w = h = 1024

    def pixel(x: int, y: int) -> tuple[int, int, int, int]:
        # Left column (open book / text band)
        if x < int(w * 0.13):
            return (248, 246, 240, 255)
        cx, cy = int(w * 0.58), int(h * 0.48)
        r = int(min(w, h) * 0.22)
        dx, dy = x - cx, y - cy
        if dx * dx + dy * dy <= r * r:
            return (255, 210, 60, 255)
        # Deep poster red
        return (175, 32, 42, 255)

    write_png_rgba(out, w, h, pixel)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
