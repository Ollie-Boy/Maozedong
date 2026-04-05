#!/usr/bin/env python3
"""
Build a 1024×1024 iOS app icon from the calligraphy GIF (沁园春·雪), cropping the bottom-left
red seal with the 「毛」 character.

The source GIF is palette-based with index 255 = transparent. Using Image.convert("RGB") loses
the red seal; we decode via the palette instead.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image


def gif_frame_as_rgb(path: Path, frame: int = -1) -> Image.Image:
    im = Image.open(path)
    n = getattr(im, "n_frames", 1)
    im.seek(frame if frame >= 0 else n - 1)
    if im.mode != "P":
        return im.convert("RGB")
    pal = im.getpalette()
    if pal is None:
        return im.convert("RGB")
    w, h = im.size
    px = im.tobytes()
    out = bytearray(w * h * 3)
    j = 0
    for p in px:
        o = p * 3
        out[j] = pal[o]
        out[j + 1] = pal[o + 1]
        out[j + 2] = pal[o + 2]
        j += 3
    return Image.frombytes("RGB", (w, h), bytes(out))


def crop_center_square(region: Image.Image) -> Image.Image:
    rw, rh = region.size
    side = min(rw, rh)
    left = (rw - side) // 2
    top = (rh - side) // 2
    return region.crop((left, top, left + side, top + side))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("input_gif", nargs="?", default="", help="Source GIF path")
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("MaozedongReader/Assets.xcassets/AppIcon.appiconset/AppIcon.png"),
    )
    p.add_argument(
        "--box",
        type=float,
        nargs=4,
        metavar=("X0", "Y0", "X1", "Y1"),
        default=(0.045, 0.908, 0.198, 0.993),
        help="Crop box as fractions of full image (left, top, right, bottom)",
    )
    p.add_argument("--size", type=int, default=1024)
    p.add_argument(
        "--url",
        default="",
        help="Download GIF to a temp file first (urllib)",
    )
    args = p.parse_args()

    if args.url:
        from urllib.request import urlretrieve

        tmp = Path("/tmp/ma_icon_source.gif")
        urlretrieve(args.url, tmp)
        src = tmp
    elif args.input_gif:
        src = Path(args.input_gif)
    else:
        print("Provide input_gif or --url", file=sys.stderr)
        return 1

    if not src.is_file():
        print(f"Missing file: {src}", file=sys.stderr)
        return 1

    rgb = gif_frame_as_rgb(src)
    w, h = rgb.size
    x0, y0, x1, y1 = args.box
    box = (int(w * x0), int(h * y0), int(w * x1), int(h * y1))
    region = rgb.crop(box)
    square = crop_center_square(region)
    out = square.resize((args.size, args.size), Image.Resampling.LANCZOS)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.output, format="PNG")
    print(f"Wrote {args.output} ({args.size}×{args.size}) from box {box}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
