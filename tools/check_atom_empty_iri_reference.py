"""Independently check Atom's legal empty IRI references and base scoping.

ElementTree checks presence and raw values, urllib computes effective bases,
and feedparser is only used for the common parsing intersection. Its own
relative-base projection can differ from RFC 3986 joining in this sample.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urljoin

import feedparser


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_empty_iri_references.xml"
ATOM = "{http://www.w3.org/2005/Atom}"
XML_BASE = "{http://www.w3.org/XML/1998/namespace}base"
DOCUMENT = "https://example.test/root/feed.atom"


def main() -> None:
    assert feedparser.__version__ == "6.0.11"
    root = ET.parse(SAMPLE).getroot()
    entry = root.find(ATOM + "entry")
    assert entry is not None
    source = entry.find(ATOM + "source")
    content = entry.find(ATOM + "content")
    assert source is not None and content is not None
    feed_links = root.findall(ATOM + "link")
    entry_links = entry.findall(ATOM + "link")
    source_links = source.findall(ATOM + "link")
    assert len(feed_links) == 1 and len(entry_links) == 2 and len(source_links) == 1
    assert [node.attrib["href"] for node in feed_links + entry_links + source_links] == [""] * 4
    assert content.attrib["src"] == ""
    feed_base = urljoin(DOCUMENT, root.attrib[XML_BASE])
    entry_base = urljoin(feed_base, entry.attrib[XML_BASE])
    assert feed_base == "https://example.test/root/pages/index.atom?view=feed"
    assert entry_base == "https://example.test/root/entries/current.atom?edition=1"

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    result = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    parsed = json.loads(result.stdout)
    item = parsed["entries"][0]
    assert parsed["diagnostics"] == []
    assert parsed["link"] == feed_links[0].attrib["href"] == ""
    assert item["link"] == entry_links[0].attrib["href"] == ""
    assert item["links"][1]["href"] == item["attachments"][0]["url"] == ""
    assert item["atom_source"]["link"] == source_links[0].attrib["href"] == ""
    assert item["content_source"] == item["atom_body"]["src"] == ""
    assert item["atom_body"]["kind"] == "external"
    assert urljoin(feed_base, parsed["link"]) == feed_base
    for raw in (item["link"], item["attachments"][0]["url"], item["content_source"]):
        assert urljoin(entry_base, raw) == entry_base

    reference = feedparser.parse(SAMPLE.read_bytes())
    assert not reference.bozo
    assert reference.feed.id == parsed["identifier"]
    assert reference.entries[0].id == item["identifier"]
    assert reference.entries[0].enclosures[0].length == "0"
    # feedparser retains an enclosure; do not treat its relative xml:base
    # normalization as an independent authority for this nested scope.
    print("PASS empty Atom IRI presence and URL joining vs ElementTree/urllib; feedparser 6.0.11 IDs and enclosure")


if __name__ == "__main__":
    main()
