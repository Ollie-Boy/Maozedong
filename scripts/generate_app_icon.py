#!/usr/bin/env python3
"""Resize/crop a portrait JPG to 1024×1024 for iOS AppIcon (center square, slight top bias)."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image


def center_square_top_bias(im: Image.Image, top_bias: float = 0.08) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    excess = max(0, h - side)
    top = int(excess * top_bias)
    return im.crop((left, top, left + side, top + side))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("input", nargs="?", help="JPEG/PNG path")
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("MaozedongReader/Assets.xcassets/AppIcon.appiconset/AppIcon.png"),
    )
    p.add_argument("--size", type=int, default=1024)
    p.add_argument("--top-bias", type=float, default=0.08, help="0=center vertically, lower keeps more top")
    p.add_argument("--url", default="")
    args = p.parse_args()

    if args.url:
        from urllib.request import Request, urlopen

        req = Request(
            args.url,
            headers={"User-Agent": "Mozilla/5.0 (compatible; MaozedongReader-icon-script)"},
        )
        data = urlopen(req, timeout=60).read()
        tmp = Path("/tmp/app_icon_source.jpg")
        tmp.write_bytes(data)
        src = tmp
    elif args.input:
        src = Path(args.input)
    else:
        print("Provide input path or --url", file=sys.stderr)
        return 1

    if not src.is_file():
        print(f"Missing: {src}", file=sys.stderr)
        return 1

    im = Image.open(src)
    sq = center_square_top_bias(im, top_bias=args.top_bias)
    out = sq.resize((args.size, args.size), Image.Resampling.LANCZOS)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.output, format="PNG")
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
