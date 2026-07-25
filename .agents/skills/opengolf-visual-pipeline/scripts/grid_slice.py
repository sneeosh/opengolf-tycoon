#!/usr/bin/env python3
"""Slice a regular image grid into named PNG cells."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("--grid", default="2x2")
    parser.add_argument("--names")
    args = parser.parse_args()

    columns, rows = (int(value) for value in args.grid.lower().split("x"))
    names = [name.strip() for name in args.names.split(",")] if args.names else None
    count = columns * rows
    if names and len(names) != count:
        raise SystemExit(f"--names contains {len(names)} names for {count} cells")

    image = Image.open(args.input).convert("RGBA")
    cell_width = image.width // columns
    cell_height = image.height // rows
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    paths = []
    for index in range(count):
        row, column = divmod(index, columns)
        crop = image.crop(
            (
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            )
        )
        stem = names[index] if names else f"{index + 1:02d}"
        path = output / f"{stem}.png"
        crop.save(path)
        paths.append(str(path))
    print(json.dumps({"ok": True, "cell_size": [cell_width, cell_height], "paths": paths}))


if __name__ == "__main__":
    main()
