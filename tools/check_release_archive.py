"""Check a packaged module in a fresh directory with dependency sync enabled."""

from __future__ import annotations

import shutil
import re
import subprocess
import tempfile
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    manifest = (ROOT / "moon.mod").read_text(encoding="utf-8")
    match = re.search(r'^version\s*=\s*"([^"]+)"', manifest, flags=re.MULTILINE)
    if match is None:
        raise RuntimeError("Missing version in moon.mod")
    archive_path = ROOT / "_build/publish" / f"youyong5-feedlens-{match[1]}.zip"
    if not archive_path.is_file():
        raise RuntimeError(f"Missing packaged version: {archive_path}")
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    with tempfile.TemporaryDirectory(prefix="feedlens-archive-check-") as tmp:
        with ZipFile(archive_path) as archive:
            archive.extractall(tmp)
        subprocess.run([moon, "check"], cwd=tmp, check=True, timeout=180)
    print(f"PASS extracted release archive: {archive_path.name}")


if __name__ == "__main__":
    main()
