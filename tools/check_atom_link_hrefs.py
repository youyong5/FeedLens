"""Compare a fixed Atom href fixture with an independent XML tree walk."""

import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_link_href_syntax.xml"
TEST = ROOT / "atom_link_href_syntax_test.mbt"
ATOM = "{http://www.w3.org/2005/Atom}"


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(
        'test "Atom feed entry and source diagnose malformed href without a source URL" {'
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
    source = entry.find(ATOM + "source")
    assert source is not None
    feed_links = root.findall(ATOM + "link")
    entry_links = entry.findall(ATOM + "link")
    source_links = source.findall(ATOM + "link")
    assert [x.get("href") for x in feed_links] == ["bad%2G", ""]
    assert [x.get("href") for x in entry_links] == ["post[one]", "audio|bad"]
    assert [x.get("href") for x in source_links] == ["bad#first#second"]

    # The fixture exercises a small, explicit lexical intersection, not a
    # complete IRI checker. Empty href is valid; each other href is malformed.
    def malformed(value: str) -> bool:
        return bool(re.search(r"%(?![0-9A-Fa-f]{2})|[\[\]|]|#.*#", value))

    assert [malformed(x.get("href", "")) for x in feed_links] == [True, False]
    assert all(malformed(x.get("href", "")) for x in entry_links + source_links)

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    result = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    actual = json.loads(result.stdout)
    assert [x["href"] for x in actual["links"]] == [x.get("href") for x in feed_links]
    assert [x["href"] for x in actual["entries"][0]["links"]] == [
        x.get("href") for x in entry_links
    ]
    assert [x["href"] for x in actual["entries"][0]["atom_source"]["links"]] == [
        x.get("href") for x in source_links
    ]
    assert [(d["kind"]["type"], d["kind"]["message"], d["line"]) for d in actual["diagnostics"]] == [
        ("InvalidAtomLink", "invalid href", 1),
        ("InvalidAtomLink", "invalid href", 2),
        ("InvalidAttachment", "invalid Atom enclosure href", 2),
        ("InvalidAtomLink", "invalid href", 2),
    ]
    print("PASS Atom href fixture mirror, raw values and located diagnostics")


if __name__ == "__main__":
    main()
