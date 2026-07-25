#!/usr/bin/env python3
"""Trim and fit a transparent sprite to a fixed bottom-centered canvas."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def parse_size(value: str) -> tuple[int, int]:
    width, height = value.lower().split("x")
    return int(width), int(height)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("--canvas", required=True, type=parse_size, help="Final WxH canvas")
    parser.add_argument("--content", type=parse_size, help="Maximum subject WxH")
    parser.add_argument("--margin-bottom", type=int, default=0)
    parser.add_argument("--resample", choices=("nearest", "lanczos"), default="lanczos")
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    alpha_box = image.getchannel("A").getbbox()
    if alpha_box is None:
        raise SystemExit("Input has no visible pixels")
    image = image.crop(alpha_box)

    canvas_width, canvas_height = args.canvas
    max_width, max_height = args.content or args.canvas
    scale = min(max_width / image.width, max_height / image.height)
    new_size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    resample = Image.Resampling.NEAREST if args.resample == "nearest" else Image.Resampling.LANCZOS
    image = image.resize(new_size, resample)

    x = (canvas_width - image.width) // 2
    y = canvas_height - args.margin_bottom - image.height
    if x < 0 or y < 0:
        raise SystemExit("Prepared sprite does not fit the requested canvas")
    canvas = Image.new("RGBA", args.canvas, (0, 0, 0, 0))
    canvas.alpha_composite(image, (x, y))

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    print(
        json.dumps(
            {
                "ok": True,
                "path": str(output),
                "canvas": list(args.canvas),
                "content": list(new_size),
                "offset": [x, y],
            }
        )
    )


if __name__ == "__main__":
    main()
