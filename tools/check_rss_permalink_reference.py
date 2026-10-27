"""Check RSS permalink projection against an independent XML reader and CLI."""

from __future__ import annotations

import json
import os
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urljoin, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/rss2_permalink_guid.xml"
SOURCE_URL = "https://example.test/feeds/main.xml"


def main() -> None:
    lines = (ROOT / "rss_permalink_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "RSS permalink guid fills only a missing item link" {')
    mirrored = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert SAMPLE.read_text("utf-8") == "\n".join(mirrored) + "\n"

    items = ET.parse(SAMPLE).getroot().findall("channel/item")
    identifiers = [item.findtext("guid") for item in items]
    assert identifiers == [
        "https://example.test/posts/one#part",
        "https://example.test/posts/two",
        "https://example.test/posts/three",
        "story-four",
        "https://example.test/posts/five",
    ]
    expected_links = []
    for item in items:
        link = item.findtext("link")
        guid = item.find("guid")
        if link is None and guid is not None and guid.get("isPermaLink", "true") == "true":
            raw = guid.text or ""
            url = urlsplit(raw)
            if url.scheme.lower() in ("http", "https") and url.netloc:
                link = raw
        expected_links.append(link)
    assert expected_links == [identifiers[0], identifiers[1], None, None, "articles/five"]

    moon = os.environ.get("FEEDLENS_MOON", "moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "--frozen", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    actual = json.loads(output.stdout)
    assert actual["diagnostics"] == []
    assert [entry["identifier"] for entry in actual["entries"]] == identifiers
    assert [entry["link"] for entry in actual["entries"]] == expected_links
    assert urljoin(SOURCE_URL, expected_links[-1]) == "https://example.test/feeds/articles/five"
    print("PASS RSS permalink fixture mirror, ElementTree roles, and CLI links")


if __name__ == "__main__":
    main()
