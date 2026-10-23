"""Compare a legal Atom XHTML wrapper with ElementTree and feedparser.

ElementTree is the reference for the declared XML attributes. feedparser
6.0.11 is only compared for the title and body display-text intersection;
it may sanitize or reserialize the XHTML.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_xhtml_container.xml"
ATOM = "{http://www.w3.org/2005/Atom}"
XHTML = "{http://www.w3.org/1999/xhtml}"


class Text(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def plain(value: str) -> str:
    parser = Text()
    parser.feed(value)
    return "".join(parser.parts)


def compare_attributes(actual: dict, declared: ET.Element) -> None:
    expected = []
    for name, value in declared.attrib.items():
        if name.startswith("{"):
            namespace, local = name[1:].split("}", 1)
        else:
            namespace, local = None, name
        expected.append({"namespace_uri": namespace, "local_name": local, "value": value})
    assert actual["container_attributes"] == expected


def main() -> None:
    assert feedparser.__version__ == "6.0.11"
    tree = ET.parse(SAMPLE).getroot()
    title_div = tree.find(f"{ATOM}title/{XHTML}div")
    body_div = tree.find(f"{ATOM}entry/{ATOM}content/{XHTML}div")
    assert title_div is not None and body_div is not None
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    result = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    parsed = json.loads(result.stdout)
    reference = feedparser.parse(SAMPLE.read_bytes())
    assert not reference.bozo
    assert parsed["diagnostics"] == [] and len(parsed["entries"]) == 1
    entry = parsed["entries"][0]
    compare_attributes(parsed["title_xhtml"], title_div)
    compare_attributes(entry["content_xhtml"], body_div)
    assert "<h:div" not in parsed["title_xhtml"]["markup"]
    assert "<h:div" not in entry["content_xhtml"]["markup"]
    assert parsed["title"] == plain(reference.feed.title) == "Plan ahead"
    assert entry["content"] == plain(reference.entries[0].content[0].value) == "Bonjour monde."
    assert entry["content_xhtml"]["language"] == "fr"
    assert entry["content_xhtml"]["base_references"] == ["https://example.test/news/", "assets/"]
    print("PASS XHTML container attributes vs ElementTree; display text vs feedparser 6.0.11")


if __name__ == "__main__":
    main()
