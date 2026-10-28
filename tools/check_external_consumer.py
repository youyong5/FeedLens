"""Compile a separate MoonBit module against this checkout's public package.

The temporary workspace links to the current source tree. This deliberately
does not claim to test an as-yet-unpublished Mooncakes version.
"""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = [
    "json=External consumer",
    "json_url=https://example.test/feeds/posts/one",
    "json_bytes=1000",
    "json_diagnostics=0",
    "rss=One",
    "rss_audio=audio.mp3",
    "rss_diagnostics=0",
    "atom_title=Plan A",
    "atom_xhtml=true",
    "atom_author=Editor",
    "atom_url=https://example.test/news/posts/one",
    "atom_diagnostics=0",
]


def main() -> None:
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    with tempfile.TemporaryDirectory(prefix="feedlens-external-consumer-") as temporary:
        workspace = Path(temporary)
        (workspace / "feedlens").symlink_to(ROOT, target_is_directory=True)
        consumer = workspace / "consumer"
        consumer.mkdir()
        (workspace / "moon.work").write_text(
            'members = ["feedlens", "consumer"]\n', encoding="utf-8"
        )
        (consumer / "moon.mod").write_text(
            'name = "verification/consumer"\nimport { "youyong5/feedlens@0.1.0" }\n',
            encoding="utf-8",
        )
        (consumer / "moon.pkg").write_text(
            'import { "youyong5/feedlens" }\npkgtype(kind: "executable")\n',
            encoding="utf-8",
        )
        (consumer / "main.mbt").write_bytes(
            (ROOT / "tools/external_consumer_main.mbt").read_bytes()
        )
        for target in ("wasm", "js", "native"):
            subprocess.run(
                [moon, "-C", str(consumer), "check", "--target", target],
                check=True,
                stdout=subprocess.DEVNULL,
            )
        result = subprocess.run(
            [moon, "-C", str(consumer), "run", "--target", "native", "."],
            check=True,
            capture_output=True,
            text=True,
        )
        lines = result.stdout.strip().splitlines()
        assert lines == EXPECTED, f"Unexpected external consumer output: {lines!r}"
    print("PASS external MoonBit module: Wasm/JS/Native check and Native API output")


if __name__ == "__main__":
    main()
