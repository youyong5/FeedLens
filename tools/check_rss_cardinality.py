"""Check RSS singleton scopes with ElementTree and Native CLI JSON."""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/rss2_cardinality.xml"
TEST = ROOT / "rss_cardinality_test.mbt"


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(
        'test "RSS core singleton diagnostics keep usable values and reset for each item" {'
    )
    mirror = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirror.append(stripped[2:])
        elif mirror:
            break
    assert SAMPLE.read_text("utf-8") == "\n".join(mirror) + "\n"

    root = ET.parse(SAMPLE).getroot()
    channel = root.find("channel")
    assert channel is not None
    items = channel.findall("item")
    assert len(items) == 2
    expected_duplicates = [
        ("channel title duplicate", channel, "title"),
        ("channel link duplicate", channel, "link"),
        ("item guid duplicate", items[0], "guid"),
        ("item title duplicate", items[0], "title"),
        ("item author duplicate", items[0], "author"),
    ]
    assert all(len(parent.findall(field)) == 2 for _, parent, field in expected_duplicates)
    assert len(channel.findall("category")) == 2
    assert len(items[0].findall("category")) == 2
    assert len(items[0].findall("enclosure")) == 2
    assert items[1].findall("title")[0].text == "Next"
    assert len(channel.findall("{urn:other}title")) == 1
    assert len(channel.findall("{urn:other}item")) == 1

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    proc = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    result = json.loads(proc.stdout)
    assert result["title"] == channel.findall("title")[-1].text
    assert result["link"] == channel.findall("link")[-1].text
    assert result["entries"][0]["identifier"] == items[0].findall("guid")[-1].text
    assert result["entries"][0]["title"] == items[0].findall("title")[-1].text
    assert len(result["entries"][0]["authors"]) == 2
    assert len(result["entries"][0]["attachments"]) == 2
    assert len(result["entries"]) == len(items)
    assert [d["kind"] for d in result["diagnostics"]] == [
        {"type": "InvalidRssField", "field": label} for label, _, _ in expected_duplicates
    ]
    assert [d["line"] for d in result["diagnostics"]] == [2, 2, 3, 3, 3]
    print("PASS RSS direct-child cardinality, extension isolation and CLI recovery")


if __name__ == "__main__":
    main()
