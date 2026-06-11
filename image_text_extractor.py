#!/usr/bin/env python3
"""
Extract text from one or more images using OCR and save results to a .txt file.

Dependencies:
    pip install pytesseract Pillow
    # Also requires Tesseract OCR installed on the system:
    # Ubuntu/Debian: sudo apt-get install tesseract-ocr
    # macOS:        brew install tesseract
    # Windows:      https://github.com/UB-Mannheim/tesseract/wiki
"""

import sys
import os
from pathlib import Path
from datetime import datetime


def get_image_paths_cli(args: list[str]) -> list[Path]:
    paths = [Path(p) for p in args]
    missing = [p for p in paths if not p.exists()]
    if missing:
        print(f"Error: file(s) not found: {', '.join(str(p) for p in missing)}")
        sys.exit(1)
    return paths


def get_image_paths_gui() -> list[Path]:
    import tkinter as tk
    from tkinter import filedialog

    root = tk.Tk()
    root.withdraw()
    file_types = [
        ("Image files", "*.png *.jpg *.jpeg *.bmp *.tiff *.tif *.gif *.webp"),
        ("All files", "*.*"),
    ]
    selected = filedialog.askopenfilenames(title="Select image(s)", filetypes=file_types)
    root.destroy()
    if not selected:
        print("No images selected. Exiting.")
        sys.exit(0)
    return [Path(p) for p in selected]


def extract_text(image_path: Path) -> str:
    from PIL import Image
    import pytesseract

    with Image.open(image_path) as img:
        return pytesseract.image_to_string(img)


def build_output_path(image_paths: list[Path]) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if len(image_paths) == 1:
        base = image_paths[0].stem
        return image_paths[0].parent / f"{base}_extracted_{timestamp}.txt"
    return image_paths[0].parent / f"extracted_text_{timestamp}.txt"


def main() -> None:
    image_paths = get_image_paths_cli(sys.argv[1:]) if len(sys.argv) > 1 else get_image_paths_gui()

    output_path = build_output_path(image_paths)
    errors: list[str] = []

    with open(output_path, "w", encoding="utf-8") as out:
        for idx, path in enumerate(image_paths, start=1):
            print(f"[{idx}/{len(image_paths)}] Processing: {path.name}")
            out.write(f"{'=' * 60}\n")
            out.write(f"File: {path.name}\n")
            out.write(f"{'=' * 60}\n")
            try:
                text = extract_text(path)
                out.write(text.strip() if text.strip() else "(no text detected)")
            except Exception as exc:
                msg = f"Error processing {path.name}: {exc}"
                print(f"  WARNING: {msg}")
                errors.append(msg)
                out.write(f"(extraction failed: {exc})")
            out.write("\n\n")

    print(f"\nDone. Output saved to: {output_path}")
    if errors:
        print(f"{len(errors)} file(s) had errors (see output file for details).")


if __name__ == "__main__":
    main()
