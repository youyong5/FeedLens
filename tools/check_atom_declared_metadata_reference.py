"""Check declared Atom strings against the source XML and a reader intersection.

The fixture is byte-mirrored in the public API test. ElementTree retains
literal text and attribute values. feedparser 6.0.11 is only compared where it
preserves the same representation; its author inheritance differs here.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_declared_empty_metadata.xml"
ATOM = "{http://www.w3.org/2005/Atom}"


def main() -> None:
    assert feedparser.__version__ == "6.0.11"
    lines = (ROOT / "atom_declared_metadata_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "Atom explicit empty and whitespace metadata survives without false inheritance" {')
    mirror = []
    for line in lines[start + 1:]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirror.append(stripped[2:])
        elif mirror:
            break
    assert "\n".join(mirror) + "\n" == SAMPLE.read_text("utf-8")

    root = ET.parse(SAMPLE).getroot()
    entries = root.findall(ATOM + "entry")
    feed_name = root.find(f"{ATOM}author/{ATOM}name")
    own_name = entries[0].find(f"{ATOM}author/{ATOM}name")
    source_name = entries[1].find(f"{ATOM}source/{ATOM}author/{ATOM}name")
    assert feed_name is not None and own_name is not None and source_name is not None
    feed_category = root.find(ATOM + "category")
    own_category = entries[0].find(ATOM + "category")
    source_category = entries[1].find(f"{ATOM}source/{ATOM}category")
    assert feed_category is not None and own_category is not None and source_category is not None
    assert feed_name.text is None and own_name.text == "  " and source_name.text == "Origin"
    assert feed_category.attrib == {"term": "", "label": "  ", "scheme": ""}
    assert own_category.attrib == {"term": "  ", "label": "", "scheme": "topics"}
    assert source_category.attrib == {"term": "", "label": ""}

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    result = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    actual = json.loads(result.stdout)
    assert len(actual["entries"]) == 3
    assert actual["diagnostics"] == [
        {"kind": {"type": "InvalidCategory", "message": "atom category scheme must be an absolute IRI"}, "line": 2, "column": 25},
        {"kind": {"type": "InvalidCategory", "message": "atom category scheme must be an absolute IRI"}, "line": 3, "column": 118},
    ]
    assert actual["authors"][0]["name"] == ""
    assert actual["categories"][0]["term"] == feed_category.attrib["term"]
    assert actual["categories"][0]["label"] == feed_category.attrib["label"]
    assert actual["categories"][0]["scheme"] == feed_category.attrib["scheme"]
    own, source, inherited = actual["entries"]
    assert own["authors"][0]["name"] == own_name.text
    assert own["categories"][0]["term"] == own_category.attrib["term"]
    assert own["categories"][0]["label"] == own_category.attrib["label"]
    assert source["authors"][0]["name"] == source_name.text
    assert source["atom_source"]["categories"][0]["term"] == source_category.attrib["term"]
    assert inherited["authors"][0]["name"] == ""
    links = entries[0].findall(ATOM + "link")
    assert actual["links"][0]["title"] == root.find(ATOM + "link").attrib["title"]
    assert [link["title"] for link in own["links"]] == [link.attrib["title"] for link in links]
    assert own["attachments"][0]["title"] == links[1].attrib["title"]

    reference = feedparser.parse(SAMPLE.read_bytes())
    assert not reference.bozo
    assert reference.feed.id == actual["identifier"]
    assert [item.id for item in reference.entries] == [item["identifier"] for item in actual["entries"]]
    assert reference.feed.author == actual["authors"][0]["name"]
    assert reference.feed.tags[0]["term"] == actual["categories"][0]["term"]
    assert reference.entries[0].tags[0]["term"] == own["categories"][0]["term"]
    assert [link["title"] for link in reference.entries[0].links] == [link["title"] for link in own["links"]]
    print("PASS Atom declared metadata mirror, ElementTree values and feedparser 6.0.11 intersection")


if __name__ == "__main__":
    main()
