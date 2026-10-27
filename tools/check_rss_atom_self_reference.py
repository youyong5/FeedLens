"""Compare RSS channel Atom self links with ElementTree and Native CLI."""

from __future__ import annotations

import json
import os
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/rss2_atom_self.xml"
ATOM_LINK = "{http://www.w3.org/2005/Atom}link"
SOURCE = "https://example.test/public/current.xml"


def main() -> None:
    lines = (ROOT / "rss_atom_self_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "RSS channel Atom self link is distinct from its website link" {')
    mirrored = []
    for line in lines[start + 1:]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert SAMPLE.read_text("utf-8") == "\n".join(mirrored) + "\n"

    channel = ET.parse(SAMPLE).getroot().find("channel")
    assert channel is not None
    self_links = [node for node in channel.findall(ATOM_LINK) if node.get("rel") in (
        "self", "http://www.iana.org/assignments/relation/self"
    )]
    assert len(self_links) == 2
    assert channel.findtext("link") == "https://example.test/"
    assert urljoin(SOURCE, self_links[0].get("href", "")) == "https://example.test/feeds/stories.xml"

    moon = os.environ.get("FEEDLENS_MOON", "moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "--frozen", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    feed = json.loads(output.stdout)
    assert feed["format"] == "rss2" and feed["link"] == channel.findtext("link")
    assert [
        (link["rel"], link["href"], link["type"])
        for link in feed["links"]
    ] == [(node.get("rel"), node.get("href"), node.get("type")) for node in self_links]
    assert feed["entries"][0]["links"] == [] and feed["diagnostics"] == []
    print("PASS RSS Atom self sample mirror, direct namespace selection, and CLI links")


if __name__ == "__main__":
    main()
