"""Check a fixed Atom rel fixture with an independent XML tree walk and CLI."""

import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_link_relation_syntax.xml"
TEST = ROOT / "atom_link_relation_syntax_test.mbt"
ATOM = "{http://www.w3.org/2005/Atom}"


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index('test "Atom link rel accepts simple names and absolute IRIs only" {')
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
    assert (len(feed_links), len(entry_links), len(source_links)) == (10, 1, 1)

    def valid_rel(link: ET.Element) -> bool:
        value = link.get("rel", "alternate")
        if not value:
            return False
        parts = urlsplit(value)
        if parts.scheme:
            return parts.scheme not in ("http", "https") or bool(parts.netloc)
        return bool(re.fullmatch(r"[A-Za-z][A-Za-z0-9._~-]*", value))

    # This deliberately checks only the fixture's names and IRIs; it is not a
    # general RFC 3987 validator or a replacement for the MoonBit tests.
    assert [valid_rel(link) for link in feed_links] == [
        True, True, True, True, False, False, False, False, False, False
    ]
    assert valid_rel(entry_links[0]) and not valid_rel(source_links[0])

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    result = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    actual = json.loads(result.stdout)
    assert actual["link"] == "home"
    assert [link["rel"] for link in actual["links"]] == [
        link.get("rel", "alternate") for link in feed_links
    ]
    assert [link["rel"] for link in actual["entries"][0]["links"]] == [
        link.get("rel", "alternate") for link in entry_links
    ]
    assert [link["rel"] for link in actual["entries"][0]["atom_source"]["links"]] == [
        link.get("rel", "alternate") for link in source_links
    ]
    assert [(d["kind"]["type"], d["kind"]["message"], d["line"]) for d in actual["diagnostics"]] == [
        ("InvalidAtomLink", "invalid rel", 3)
    ] * 6 + [("InvalidAtomLink", "invalid rel", 4)]
    print("PASS Atom rel fixture mirror, declared links and located diagnostics")


if __name__ == "__main__":
    main()
