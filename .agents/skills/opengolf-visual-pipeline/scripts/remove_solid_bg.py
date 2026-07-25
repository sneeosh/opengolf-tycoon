#!/usr/bin/env python3
"""Remove a nearly solid corner-sampled background and create a QA preview."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("--threshold", type=float, default=18.0)
    parser.add_argument("--softness", type=float, default=28.0)
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGB")
    rgb = np.asarray(source, dtype=np.float32)
    corners = np.concatenate(
        (
            rgb[:3, :3].reshape(-1, 3),
            rgb[:3, -3:].reshape(-1, 3),
            rgb[-3:, :3].reshape(-1, 3),
            rgb[-3:, -3:].reshape(-1, 3),
        )
    )
    background = corners.mean(axis=0)
    distance = np.linalg.norm(rgb - background, axis=2)
    alpha = np.clip((distance - args.threshold) / max(args.softness, 0.001), 0.0, 1.0)
    rgba = np.dstack((rgb, alpha * 255.0)).astype(np.uint8)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    result = Image.fromarray(rgba, mode="RGBA")
    result.save(output)

    preview_path = None
    if args.preview:
        preview_path = output.with_name(f"{output.stem}_qa.png")
        checker = Image.new("RGBA", result.size, (30, 30, 30, 255))
        checker.alpha_composite(result)
        checker.convert("RGB").save(preview_path)

    print(
        json.dumps(
            {
                "ok": True,
                "path": str(output),
                "preview": str(preview_path) if preview_path else None,
                "background_rgb": [round(float(value), 1) for value in background],
            }
        )
    )


if __name__ == "__main__":
    main()
