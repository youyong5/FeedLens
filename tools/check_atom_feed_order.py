"""Offline Atom feed ordering check using an independent XML tree walk."""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "atom1_feed_order.xml"
ATOM = "{http://www.w3.org/2005/Atom}"


def main() -> None:
    fixture = (ROOT / "samples" / NAME).read_text("utf-8")
    lines = (ROOT / "atom_feed_order_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "Atom feed metadata following an entry is diagnosed without losing values" {')
    mirrored: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert fixture == "\n".join(mirrored) + "\n"

    root = ET.fromstring(fixture)
    children = list(root)
    first_entry = next(i for i, element in enumerate(children) if element.tag == ATOM + "entry")
    assert [element.tag for element in children[first_entry + 1 :] if element.tag != ATOM + "entry"] == [
        ATOM + "subtitle", ATOM + "link", "{urn:example:extension}after",
    ]
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    proc = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", f"samples/{NAME}"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    result = json.loads(proc.stdout)
    assert result["description"] == root.find(ATOM + "subtitle").text
    assert result["link"] == root.find(ATOM + "link").attrib["href"]
    assert [entry["identifier"] for entry in result["entries"]] == [
        entry.find(ATOM + "id").text for entry in root.findall(ATOM + "entry")
    ]
    assert [d for d in result["diagnostics"] if d["kind"]["type"] == "InvalidAtomOrder"] == [
        {"kind": {"type": "InvalidAtomOrder", "field": "subtitle"}, "line": 4, "column": 1},
        {"kind": {"type": "InvalidAtomOrder", "field": "link"}, "line": 4, "column": 35},
        {"kind": {"type": "InvalidAtomOrder", "field": "x:after"}, "line": 6, "column": 1},
    ]
    print("PASS Atom child-order XML comparison and preserved CLI values")


if __name__ == "__main__":
    main()
