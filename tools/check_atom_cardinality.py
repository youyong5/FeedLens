"""Independently count scoped Atom fields and compare CLI recovery."""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_cardinality.xml"
TEST = ROOT / "atom_cardinality_test.mbt"
ATOM = "{http://www.w3.org/2005/Atom}"


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(
        'test "Atom direct-child cardinality is scoped to feed entry source and person" {'
    )
    mirror: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirror.append(stripped[2:])
        elif mirror:
            break
    assert SAMPLE.read_text("utf-8") == "\n".join(mirror) + "\n"

    root = ET.parse(SAMPLE).getroot()
    entry = root.find(ATOM + "entry")
    assert entry is not None
    source = entry.find(ATOM + "source")
    author = root.find(ATOM + "author")
    assert source is not None and author is not None

    # Count only direct children in the exact Atom namespace. Repeated
    # categories and contributors are valid; extension elements do not count.
    expectations = {
        "feed title": (root, "title"),
        "atom author name": (author, "name"),
        "entry updated": (entry, "updated"),
        "entry content": (entry, "content"),
        "source id": (source, "id"),
    }
    assert all(len(owner.findall(ATOM + field)) == 2 for owner, field in expectations.values())
    assert len(root.findall(ATOM + "category")) == 2
    assert len(source.findall(ATOM + "category")) == 2
    assert len(entry.findall(ATOM + "contributor")) == 2
    assert len(root.findall("{urn:other}title")) == 1
    assert len(entry.findall("{urn:other}content")) == 1

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    proc = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    actual = json.loads(proc.stdout)
    duplicate = [d for d in actual["diagnostics"] if d["kind"]["type"] == "DuplicateAtomField"]
    assert len(actual["diagnostics"]) == len(expectations)
    assert [d["kind"]["field"] for d in duplicate] == list(expectations)
    assert [d["line"] for d in duplicate] == [2, 3, 4, 4, 5]
    assert actual["title"] == root.findall(ATOM + "title")[-1].text
    item = actual["entries"][0]
    assert item["updated_at"] == entry.findall(ATOM + "updated")[-1].text
    assert item["content"] == entry.findall(ATOM + "content")[-1].text
    assert item["atom_source"]["identifier"] == source.findall(ATOM + "id")[-1].text
    assert item["authors"][0]["name"] == source.find(ATOM + "author/" + ATOM + "name").text
    print("PASS Atom scoped cardinality, extension isolation, and recovered values")


if __name__ == "__main__":
    main()
