"""Compare Atom link MIME hints with independent XML and Python email parsing."""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from email import policy
from email.parser import HeaderParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_link_media_types.xml"
ATOM = "{http://www.w3.org/2005/Atom}"


def main() -> None:
    lines = (ROOT / "atom_link_media_test.mbt").read_text("utf-8").splitlines()
    start = lines.index(
        'test "Atom link MIME hints accept composite types and diagnose malformed declarations" {'
    )
    mirrored: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert "\n".join(mirrored) + "\n" == SAMPLE.read_text("utf-8")

    root = ET.fromstring(SAMPLE.read_bytes())
    entry = root.find(ATOM + "entry")
    assert entry is not None
    source = entry.find(ATOM + "source")
    assert source is not None
    feed_link = root.find(ATOM + "link")
    assert feed_link is not None
    links = [feed_link, *entry.findall(ATOM + "link"), *source.findall(ATOM + "link")]
    defects = []
    for link in links:
        raw = link.attrib["type"]
        header = HeaderParser(policy=policy.default).parsestr(
            f"Content-Type: {raw}\n"
        )["Content-Type"]
        defects.append(bool(header.defects))
    assert defects == [False, False, False, True, True, True, False, False]

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
        actual["links"][0],
        *actual["entries"][0]["links"],
        *actual["entries"][0]["atom_source"]["links"],
    ]
    assert [link["href"] for link in actual_links] == [
        link.attrib["href"] for link in links
    ]
    assert [link["type"] for link in actual_links] == [
        link.attrib["type"] for link in links
    ]
    assert actual["entries"][0]["link"] == "article"
    assert [attachment["url"] for attachment in actual["entries"][0]["attachments"]] == [
        "bad-audio", "good-audio"
    ]
    assert [(d["type"], d["message"], d["line"]) for d in actual["diagnostics"]] == [
        ("InvalidAtomLink", "invalid type", 6),
        ("InvalidAtomLink", "invalid type", 7),
        ("InvalidAttachment", "invalid Atom enclosure type", 8),
    ]
    print("PASS Atom link MIME sample mirror and independent XML/email syntax intersection")


if __name__ == "__main__":
    main()
