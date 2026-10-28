"""Compare a fixed Atom content-src fixture with an independent XML tree walk."""

import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urljoin


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_content_src_syntax.xml"
TEST = ROOT / "atom_content_src_syntax_test.mbt"
ATOM = "{http://www.w3.org/2005/Atom}"
DOCUMENT = "https://example.test/feeds/main.atom"


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(
        'test "Atom feed content src validates IRI syntax without losing the declaration" {'
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
    contents = [entry.find(ATOM + "content") for entry in root.findall(ATOM + "entry")]
    assert all(content is not None for content in contents)
    sources = [content.attrib["src"] for content in contents]
    assert sources == ["bad%2G", "../媒体.xml?x=%5B1%5D", ""]
    assert bool(re.search(r"%(?![0-9A-Fa-f]{2})", sources[0]))
    assert not any(re.search(r"%(?![0-9A-Fa-f]{2})", src) for src in sources[1:])
    assert urljoin(DOCUMENT, sources[1]) == "https://example.test/媒体.xml?x=%5B1%5D"
    assert urljoin(DOCUMENT, sources[2]) == DOCUMENT

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    result = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    parsed = json.loads(result.stdout)
    entries = parsed["entries"]
    assert [entry["content_source"] for entry in entries] == sources
    assert entries[0]["atom_body"] is None
    assert entries[1]["atom_body"]["src"] == sources[1]
    assert entries[2]["atom_body"]["src"] == ""
    assert [(d["kind"]["type"], d["kind"]["content"], d["line"]) for d in parsed["diagnostics"]] == [
        ("UnsupportedAtomContent", "invalid external Atom src", 2)
    ]
    print("PASS Atom content src fixture mirror, XML declarations and CLI diagnostics")


if __name__ == "__main__":
    main()
