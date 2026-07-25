#!/usr/bin/env python3
"""Inventory committed PNG dimensions using only the Python standard library."""

from __future__ import annotations

import argparse
import json
import struct
from collections import Counter
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        if stream.read(8) != PNG_SIGNATURE:
            raise ValueError("not a PNG")
        length = struct.unpack(">I", stream.read(4))[0]
        if stream.read(4) != b"IHDR" or length < 8:
            raise ValueError("missing IHDR")
        return struct.unpack(">II", stream.read(8))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default="assets")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    root = Path(args.root)
    rows = []
    errors = []
    for path in sorted(root.rglob("*.png")):
        try:
            width, height = png_size(path)
            rows.append({"path": str(path), "width": width, "height": height})
        except (OSError, ValueError) as exc:
            errors.append({"path": str(path), "error": str(exc)})

    if args.json:
        print(json.dumps({"assets": rows, "errors": errors}, indent=2))
        return

    sizes = Counter((row["width"], row["height"]) for row in rows)
    print(f"PNG assets: {len(rows)}")
    for (width, height), count in sizes.most_common():
        print(f"  {width}x{height}: {count}")
    for error in errors:
        print(f"ERROR {error['path']}: {error['error']}")


if __name__ == "__main__":
    main()
