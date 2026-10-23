"""Compare retained Atom dates and their validation with Python's stdlib.

ElementTree supplies independent XML extraction; datetime supplies calendar and
offset checks. Atom's mandatory uppercase T/Z is checked explicitly because
Python's ISO parser accepts lowercase forms.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "atom1_invalid_dates.xml"
NS = {"a": "http://www.w3.org/2005/Atom"}


def declared_date(element: ET.Element, path: str) -> str | None:
    node = element.find(path, NS)
    return None if node is None else node.text or ""


def valid_atom_date(value: str) -> bool:
    # RFC 3339 grammar here is restricted to the Atom date construct. The
    # selected fixture has no leap seconds, which Python cannot represent.
    if re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)", value) is None:
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return True


def main() -> None:
    fixture = (ROOT / "samples" / NAME).read_text("utf-8")
    lines = (ROOT / "atom_date_validation_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "Atom feed, entry and source dates retain raw text and report malformed values" {')
    mirrored: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert fixture == "\n".join(mirrored) + "\n"

    root = ET.fromstring(fixture)
    entries = root.findall("a:entry", NS)
    values = [
        ("feed updated", declared_date(root, "a:updated")),
        ("entry updated", declared_date(entries[0], "a:updated")),
        ("entry published", declared_date(entries[0], "a:published")),
        ("source updated", declared_date(entries[0], "a:source/a:updated")),
        ("entry updated", declared_date(entries[1], "a:updated")),
        ("entry published", declared_date(entries[1], "a:published")),
    ]
    assert [valid_atom_date(raw) for _, raw in values] == [False, False, False, False, True, False]
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    proc = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", f"samples/{NAME}"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    result = json.loads(proc.stdout)
    actual = [
        result["updated_at"], result["entries"][0]["updated_at"],
        result["entries"][0]["published_at"],
        result["entries"][0]["atom_source"]["updated_at"],
        result["entries"][1]["updated_at"], result["entries"][1]["published_at"],
    ]
    assert actual == [raw or None for _, raw in values]
    invalid = [d for d in result["diagnostics"] if d["kind"]["type"] == "InvalidAtomDate"]
    assert [(d["kind"]["field"], d["line"], d["column"]) for d in invalid] == [
        ("feed updated", 2, 46), ("entry updated", 3, 47),
        ("entry published", 3, 86), ("source updated", 3, 165),
        ("entry published", 4, 91),
    ]
    print("PASS mirrored Atom dates, retained CLI values and Python calendar/offset comparison")


if __name__ == "__main__":
    main()
