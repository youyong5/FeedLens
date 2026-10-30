"""Fail CI if the installed MoonBit compiler is older than the review minimum."""

from __future__ import annotations

import re
import subprocess


def main() -> None:
    version_info = subprocess.check_output(["moon", "version", "--all"], text=True)
    print(version_info, end="")
    match = re.search(r"(?m)^moonc\s+v?(\d+)\.(\d+)\.(\d+)\b", version_info)
    if match is None:
        raise SystemExit("Could not identify moonc version from moon version --all")
    version = tuple(int(part) for part in match.groups())
    if version < (0, 10, 16):
        raise SystemExit(f"moonc {version} is older than the required 0.10.16")
    print(f"PASS moonc version {'.'.join(map(str, version))} >= 0.10.16")


if __name__ == "__main__":
    main()
