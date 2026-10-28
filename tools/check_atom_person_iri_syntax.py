"""Independently check explicit and malformed Atom Person URI declarations."""

import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urljoin


ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / "atom_person_iri_syntax_test.mbt"
SAMPLE = ROOT / "samples/atom1_person_iri_syntax.xml"
ATOM = "{http://www.w3.org/2005/Atom}"
XML_BASE = "{http://www.w3.org/XML/1998/namespace}base"
DOCUMENT = "https://example.test/feeds/main.atom"


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(
        'test "Atom person URI distinguishes empty, legal relative and malformed references" {'
    )
    mirrored = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert "\n".join(mirrored) + "\n" == SAMPLE.read_text("utf-8")

    root = ET.parse(SAMPLE).getroot()
    entry = root.find(ATOM + "entry")
    assert entry is not None
    feed_author = root.find(ATOM + "author")
    contributor = entry.find(ATOM + "contributor")
    source = entry.find(ATOM + "source")
    assert feed_author is not None and contributor is not None and source is not None
    source_author = source.find(ATOM + "author")
    assert source_author is not None
    declarations = [
        feed_author.find(ATOM + "uri"),
        contributor.find(ATOM + "uri"),
        source_author.find(ATOM + "uri"),
    ]
    assert all(node is not None for node in declarations)
    values = [node.text or "" for node in declarations]
    assert values == ["", "bad%2G", "?p=一"]
    assert re.search(r"%(?![0-9A-Fa-f]{2})", values[1])
    assert urljoin(urljoin(DOCUMENT, feed_author.attrib[XML_BASE]), values[0]) == "https://example.test/feeds/authors/"
    assert urljoin(urljoin(DOCUMENT, source.attrib[XML_BASE]), values[2]) == "https://example.test/origins/?p=一"

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    parsed = json.loads(output.stdout)
    assert parsed["authors"][0]["uri"] == values[0]
    item = parsed["entries"][0]
    assert item["contributors"][0]["uri"] == values[1]
    assert item["atom_source"]["authors"][0]["uri"] == values[2]
    assert [(d["kind"], d["line"]) for d in parsed["diagnostics"]] == [
        ({"type": "InvalidAuthor", "message": "invalid atom person uri"}, 2)
    ]
    print("PASS Atom person URI declarations, lexical boundary and CLI diagnostics")


if __name__ == "__main__":
    main()
