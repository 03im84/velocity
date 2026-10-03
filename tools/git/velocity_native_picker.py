from __future__ import annotations

import argparse
import sys
import tkinter as tk

from pathlib import Path
from tkinter import filedialog


def select_file(kind: str) -> Path | None:
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)

    if kind == "zip":
        title = "Select Velocity delivery ZIP"
        filetypes = (
            ("Velocity delivery packages", "*.zip"),
            ("All files", "*.*"),
        )
    else:
        title = "Select browser executable"
        filetypes = (
            ("Windows executables", "*.exe"),
            ("All files", "*.*"),
        )

    selected = filedialog.askopenfilename(
        parent=root,
        title=title,
        filetypes=filetypes,
    )
    root.destroy()

    if not selected:
        return None

    return Path(selected)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--kind",
        choices=("zip", "browser"),
        required=True,
    )
    args = parser.parse_args()
    selected = select_file(args.kind)

    if selected is None:
        return 1

    print(str(selected.resolve()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
