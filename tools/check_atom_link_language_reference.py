"""Compare Atom link hreflang with RFC 3066 ABNF and independent XML parsing."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_link_languages.xml"
ATOM = "{http://www.w3.org/2005/Atom}"
LANGUAGE_TAG = re.compile(r"[A-Za-z]{1,8}(?:-[A-Za-z0-9]{1,8})*")


def main() -> None:
    lines = (ROOT / "atom_link_language_test.mbt").read_text("utf-8").splitlines()
    start = lines.index(
        'test "Atom link language syntax retains raw tags and finds translated alternate duplicates" {'
    )
    mirrored: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert "\n".join(mirrored) + "\n" == SAMPLE.read_text("utf-8")

    feed = ET.fromstring(SAMPLE.read_bytes())
    entry = feed.find(ATOM + "entry")
    assert entry is not None
    source = entry.find(ATOM + "source")
    assert source is not None
    feed_links = feed.findall(ATOM + "link")
    entry_links = entry.findall(ATOM + "link")
    source_links = source.findall(ATOM + "link")
    links = [*feed_links, *entry_links, *source_links]
    assert [link.attrib.get("hreflang") for link in links] == [
        "zh-Hant-TW", "ZH-hant-tw", "i-klingon", "x-private-12345678",
        "", "en--US", "en_US", "fr-CA",
    ]
    assert [
        link.attrib.get("hreflang") for link in links
        if "hreflang" in link.attrib and
        not LANGUAGE_TAG.fullmatch(link.attrib["hreflang"])
    ] == ["", "en--US", "en_US"]
    assert feed_links[0].attrib["hreflang"].casefold() == feed_links[1].attrib["hreflang"].casefold()

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    cli = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    actual = json.loads(cli.stdout)
    actual_links = [
        *actual["links"],
        *actual["entries"][0]["links"],
        *actual["entries"][0]["atom_source"]["links"],
    ]
    assert [link["href"] for link in actual_links] == [link.attrib["href"] for link in links]
    assert [link["hreflang"] for link in actual_links] == [
        link.attrib.get("hreflang") for link in links
    ]
    assert actual["entries"][0]["attachments"][0]["media_type"] == ""
    assert [(d["kind"], d["line"]) for d in actual["diagnostics"]] == [
        ({"type": "DuplicateAtomField", "field": "feed alternate link"}, 3),
        ({"type": "InvalidAtomLink", "message": "invalid hreflang"}, 7),
        ({"type": "InvalidAtomLink", "message": "invalid hreflang"}, 8),
        ({"type": "InvalidAtomLink", "message": "invalid hreflang"}, 9),
        ({"type": "InvalidAttachment", "message": "invalid Atom enclosure type"}, 9),
    ]
    print("PASS Atom link language sample mirror and independent RFC 3066 ABNF/XML intersection")


if __name__ == "__main__":
    main()
