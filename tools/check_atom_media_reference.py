"""Offline Atom content MIME intersection with independent standard readers."""

from __future__ import annotations

import base64
import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from email.message import Message
from pathlib import Path

import feedparser

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_mime_parameters.xml"
ATOM = "{http://www.w3.org/2005/Atom}"


def main() -> None:
    lines = (ROOT / "atom_media_type_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "Atom MIME parameters classify bodies without losing original type" {')
    mirrored: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert "\n".join(mirrored) + "\n" == SAMPLE.read_text("utf-8")

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    cli = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", "samples/atom1_mime_parameters.xml"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    output = json.loads(cli.stdout)
    assert output["diagnostics"] == []
    entries = output["entries"]
    root = ET.fromstring(SAMPLE.read_bytes())
    declared = root.findall(ATOM + "entry")
    reference = feedparser.parse(SAMPLE.read_bytes())
    assert not reference.bozo
    assert [e["identifier"] for e in entries] == [e.id for e in reference.entries]
    assert [e["atom_body"]["kind"] for e in entries] == [
        "inline_text", "inline_xml", "inline_binary", "external"
    ]
    for actual, source in zip(entries, declared, strict=True):
        content = source.find(ATOM + "content")
        assert content is not None
        declared_type = content.attrib["type"]
        assert actual["content_media_type"] == actual["atom_body"]["media_type"] == declared_type
        header = Message()
        header["Content-Type"] = declared_type
        assert header.get_content_type() == declared_type.split(";", 1)[0].lower()
        assert header.get_params() is not None
    assert entries[0]["content"] == reference.entries[0].content[0].value == "A & B"
    assert entries[0]["atom_body"]["media_type"].endswith('note="a;b\\"c"')
    assert entries[1]["atom_body"]["markup"].endswith(">ok</n0:root>")
    assert declared[1].find(ATOM + "content")[0].text == "ok"
    assert base64.b64decode(entries[2]["atom_body"]["base64"], validate=True) == b"\x01\x02\x03\xff"
    assert entries[3]["atom_body"]["src"] == reference.entries[3].content[0].src
    print(f"PASS Atom MIME sample mirror and independent XML/email/feedparser {feedparser.__version__} intersection")


if __name__ == "__main__":
    main()
