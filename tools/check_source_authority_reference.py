"""Compare the mirrored Atom IRI fixture to Python's URL joining.

The MoonBit regression checks the library API. This independent check reads
the source XML, computes effective bases, and checks expected absolute IRIs.
No network fetch or assertion of full RFC 3987 validation is involved.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urljoin

import feedparser

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_iri_host.xml"
ATOM = "{http://www.w3.org/2005/Atom}"
XML_BASE = "{http://www.w3.org/XML/1998/namespace}base"


def main() -> None:
    lines = (ROOT / "uri_source_boundary_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "source-aware Atom IRI resolves Unicode host and scoped base" {')
    projection: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            projection.append(stripped[2:])
        elif projection:
            break
    assert "\n".join(projection) + "\n" == SAMPLE.read_text("utf-8")

    root = ET.fromstring(SAMPLE.read_bytes())
    entry = root.find(ATOM + "entry")
    assert entry is not None
    links = entry.findall(ATOM + "link")
    assert len(links) == 2
    base = urljoin("https://origin.test/feeds/main.atom", root.attrib[XML_BASE])
    scoped = urljoin(base, entry.attrib[XML_BASE])
    assert urljoin(scoped, links[0].attrib["href"]) == "https://例子.test/刊物/文章/一?版=全#段"
    assert urljoin(scoped, links[1].attrib["href"]) == "https://例子.test/刊物/章节/音频/一.mp3"
    assert urljoin("https://user:pass@[2001:db8::1]:8080/feeds/main.atom", "post") == "https://user:pass@[2001:db8::1]:8080/feeds/post"
    reference = feedparser.parse(SAMPLE.read_bytes())
    assert not reference.bozo
    assert reference.feed.id == "urn:feed:iri"
    assert reference.entries[0].id == "urn:entry:iri"
    print(f"PASS source IRI fixture mirror, Python URL joining, feedparser {feedparser.__version__} IDs")


if __name__ == "__main__":
    main()
