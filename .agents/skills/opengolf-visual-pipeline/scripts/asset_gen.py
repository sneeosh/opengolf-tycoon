#!/usr/bin/env python3
"""Generate 2D image or video assets with Gemini or xAI.

This OpenGolf-specific adaptation intentionally omits Godogen's 3D pipeline.
Every successful result includes the estimated API cost in cents.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import sys
from pathlib import Path


GEMINI_MODEL = "gemini-3.1-flash-image-preview"
GEMINI_COSTS = {"512": 5, "1K": 7, "2K": 10, "4K": 15}
GROK_IMAGE_MODEL = "grok-imagine-image"
GROK_IMAGE_COST = 2
GROK_VIDEO_MODEL = "grok-imagine-video"
GROK_VIDEO_COST_PER_SECOND = 5


def emit(ok: bool, *, path: Path | None = None, cost_cents: int = 0, error: str | None = None) -> None:
    result: dict[str, object] = {"ok": ok, "cost_cents": cost_cents}
    if path is not None:
        result["path"] = str(path)
    if error:
        result["error"] = error
    print(json.dumps(result))


def image_mime(path: Path) -> str:
    return {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }.get(path.suffix.lower(), "image/png")


def image_data_uri(path: Path) -> str:
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{image_mime(path)};base64,{encoded}"


def save_as_png(data: bytes, output: Path) -> None:
    from PIL import Image

    image = Image.open(io.BytesIO(data))
    image.save(output, format="PNG")


def generate_gemini(args: argparse.Namespace, output: Path) -> None:
    from google import genai
    from google.genai import types

    contents: list[object] = []
    if args.image:
        reference = Path(args.image)
        if not reference.is_file():
            raise FileNotFoundError(f"Reference image not found: {reference}")
        contents.append(
            types.Part.from_bytes(data=reference.read_bytes(), mime_type=image_mime(reference))
        )
    contents.append(args.prompt)

    client = genai.Client(
        http_options=types.HttpOptions(timeout=args.timeout_seconds * 1000)
    )
    response = client.models.generate_content(
        model=GEMINI_MODEL,
        contents=contents,
        config=types.GenerateContentConfig(
            response_modalities=["IMAGE"],
            image_config=types.ImageConfig(
                image_size=args.size,
                aspect_ratio=args.aspect_ratio,
            ),
        ),
    )
    for part in response.parts or []:
        if part.inline_data is not None:
            save_as_png(part.inline_data.data, output)
            return
    raise RuntimeError("Gemini returned no image")


def generate_grok_image(args: argparse.Namespace, output: Path) -> None:
    import xai_sdk

    reference_uri = None
    if args.image:
        reference = Path(args.image)
        if not reference.is_file():
            raise FileNotFoundError(f"Reference image not found: {reference}")
        reference_uri = image_data_uri(reference)

    client = xai_sdk.Client()
    response = client.image.sample(
        prompt=args.prompt,
        model=GROK_IMAGE_MODEL,
        image_url=reference_uri,
        aspect_ratio=args.aspect_ratio,
        resolution=args.size.lower(),
    )
    save_as_png(response.image, output)


def command_image(args: argparse.Namespace) -> None:
    if args.model == "gemini" and args.size not in GEMINI_COSTS:
        emit(False, error=f"Gemini size must be one of: {', '.join(GEMINI_COSTS)}")
        raise SystemExit(2)
    if args.model == "grok" and args.size not in ("1K", "2K"):
        emit(False, error="Grok size must be 1K or 2K")
        raise SystemExit(2)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    cost = GEMINI_COSTS[args.size] if args.model == "gemini" else GROK_IMAGE_COST
    try:
        if args.model == "gemini":
            generate_gemini(args, output)
        else:
            generate_grok_image(args, output)
    except Exception as exc:
        emit(False, error=str(exc))
        raise SystemExit(1) from exc
    emit(True, path=output, cost_cents=cost)


def command_video(args: argparse.Namespace) -> None:
    import requests
    import xai_sdk

    reference = Path(args.image)
    if not reference.is_file():
        emit(False, error=f"Reference image not found: {reference}")
        raise SystemExit(2)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    cost = args.duration * GROK_VIDEO_COST_PER_SECOND
    try:
        client = xai_sdk.Client()
        response = client.video.generate(
            prompt=args.prompt,
            model=GROK_VIDEO_MODEL,
            image_url=image_data_uri(reference),
            duration=args.duration,
            aspect_ratio="1:1",
            resolution=args.resolution,
        )
        download = requests.get(response.url, timeout=120)
        download.raise_for_status()
        output.write_bytes(download.content)
    except Exception as exc:
        emit(False, error=str(exc))
        raise SystemExit(1) from exc
    emit(True, path=output, cost_cents=cost)


def main() -> None:
    parser = argparse.ArgumentParser(description="OpenGolf 2D asset generator")
    subparsers = parser.add_subparsers(dest="command", required=True)

    image_parser = subparsers.add_parser("image")
    image_parser.add_argument("--prompt", required=True)
    image_parser.add_argument("--model", choices=("gemini", "grok"), default="gemini")
    image_parser.add_argument("--size", choices=("512", "1K", "2K", "4K"), default="1K")
    image_parser.add_argument("--aspect-ratio", default="1:1")
    image_parser.add_argument("--image", help="Optional image-to-image reference")
    image_parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=180,
        help="Gemini request timeout in seconds (default: 180)",
    )
    image_parser.add_argument("-o", "--output", required=True)
    image_parser.set_defaults(func=command_image)

    video_parser = subparsers.add_parser("video")
    video_parser.add_argument("--prompt", required=True)
    video_parser.add_argument("--image", required=True)
    video_parser.add_argument("--duration", type=int, choices=range(1, 16), required=True)
    video_parser.add_argument("--resolution", choices=("480p", "720p"), default="720p")
    video_parser.add_argument("-o", "--output", required=True)
    video_parser.set_defaults(func=command_video)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
