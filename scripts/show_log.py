r"""Prints the newest lines of the mod's log files.

The mod writes server.log and client.log to Script Extender/bg3_regroup/ in the BG3 user-data folder
(Shared/FileWriter.lua). The script reads them from $BG3_DATA_DIR (for example a share of the game PC), else from
%LOCALAPPDATA%/Larian Studios/Baldur's Gate 3.

Usage:
    python scripts/show_log.py          # newest 40 lines of each file
    python scripts/show_log.py -n 200
"""

import argparse
import os
from pathlib import Path

DATA_DIR = Path(os.environ.get("BG3_DATA_DIR")
                or Path(os.environ.get("LOCALAPPDATA", "")) / "Larian Studios" / "Baldur's Gate 3")
LOG_DIR = DATA_DIR / "Script Extender" / "bg3_regroup"


def main() -> None:
    parser = argparse.ArgumentParser(description="Print the newest lines of the mod's log files.")
    parser.add_argument("-n", type=int, default=40, help="lines per file (default 40)")
    args = parser.parse_args()

    for name in ("server.log", "client.log"):
        path = LOG_DIR / name
        print(f"=== {path}")
        if not path.is_file():
            print("(not there: the mod did not write it yet, or the folder is not reachable)")
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for line in lines[-args.n:]:
            print(line)


if __name__ == "__main__":
    main()
