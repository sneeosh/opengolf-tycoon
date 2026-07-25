#!/usr/bin/env python3
"""Report OpenGolf visual-pipeline prerequisites without exposing secret values."""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
from pathlib import Path


def executable(name: str, fallbacks: list[str] | None = None) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    for candidate in fallbacks or []:
        if Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return candidate
    return None


def module_available(name: str) -> bool:
    try:
        return importlib.util.find_spec(name) is not None
    except (ImportError, ModuleNotFoundError, ValueError):
        return False


def main() -> None:
    report = {
        "api_keys": {
            name: bool(os.environ.get(name))
            for name in ("GOOGLE_API_KEY", "XAI_API_KEY", "TRIPO3D_API_KEY")
        },
        "python": {
            module: module_available(module)
            for module in ("PIL", "numpy", "requests", "google.genai", "xai_sdk", "rembg")
        },
        "executables": {
            "godot": executable(
                "godot",
                [
                    "/Applications/Godot.app/Contents/MacOS/Godot",
                    "/Applications/Godot_mono.app/Contents/MacOS/Godot",
                ],
            ),
            "ffmpeg": executable("ffmpeg"),
            "magick": executable("magick"),
        },
    }
    required = [
        report["api_keys"]["GOOGLE_API_KEY"] or report["api_keys"]["XAI_API_KEY"],
        report["python"]["PIL"],
        report["python"]["requests"],
    ]
    report["ready_for_image_generation"] = all(required)
    report["ready_for_godot_validation"] = bool(report["executables"]["godot"])
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
