"""Check a mirrored JSON Feed page against Python URL resolution and raw CLI."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/jsonfeed11_self_pagination.json"
SOURCE = "https://example.test/feeds/feed.json"


def main() -> None:
    lines = (ROOT / "json_pagination_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "JSON Feed source-aware pagination rejects resolved self links" {')
    mirror = next(
        line.lstrip()[2:] for line in lines[start + 1 :]
        if line.lstrip().startswith("#|")
    ) + "\n"
    assert mirror == SAMPLE.read_text("utf-8")

    declared = json.loads(mirror)
    assert declared["version"] == "https://jsonfeed.org/version/1.1"
    assert declared["next_url"] != declared["feed_url"]
    assert urljoin(SOURCE, declared["next_url"]) == urljoin(SOURCE, declared["feed_url"])

    moon = os.environ.get("FEEDLENS_MOON", "moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "--frozen", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    raw = json.loads(output.stdout)
    assert raw["identifier"] == declared["feed_url"]
    assert raw["next_url"] == declared["next_url"]
    assert raw["diagnostics"] == []
    print("PASS JSON Feed pagination mirror, Python URL equality, and raw CLI values")


if __name__ == "__main__":
    main()
