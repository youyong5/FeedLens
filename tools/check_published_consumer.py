"""Install a released FeedLens version into a fresh module and exercise its API.

Unlike check_external_consumer.py, this program has no moon.work and does not
link to the checkout. Run it only after the requested version is on Mooncakes.
"""

from __future__ import annotations

import argparse
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="published version, for example 0.2.0")
    args = parser.parse_args()
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    with tempfile.TemporaryDirectory(prefix="feedlens-published-consumer-") as temp:
        consumer = Path(temp)
        (consumer / "moon.mod").write_text(
            'name = "verification/published-consumer"\n', encoding="utf-8"
        )
        (consumer / "moon.pkg").write_text(
            'import { "youyong5/feedlens" }\npkgtype(kind: "executable")\n',
            encoding="utf-8",
        )
        (consumer / "main.mbt").write_bytes(
            (ROOT / "tools/external_consumer_main.mbt").read_bytes()
        )
        subprocess.run(
            [moon, "-C", str(consumer), "add", f"youyong5/feedlens@{args.version}"],
            check=True,
            timeout=180,
        )
        manifest = (consumer / "moon.mod").read_text(encoding="utf-8")
        assert f'"youyong5/feedlens@{args.version}"' in manifest, manifest
        for target in ("wasm", "js", "native"):
            subprocess.run(
                [moon, "-C", str(consumer), "check", "--target", target],
                check=True,
                timeout=180,
            )
        result = subprocess.run(
            [moon, "-C", str(consumer), "run", "--target", "native", "."],
            check=True,
            capture_output=True,
            text=True,
            timeout=180,
        )
        lines = result.stdout.strip().splitlines()
        assert lines == EXPECTED, f"Unexpected published consumer output: {lines!r}"
    print(f"PASS Mooncakes {args.version}: fresh install, three targets, Native API")


if __name__ == "__main__":
    main()
