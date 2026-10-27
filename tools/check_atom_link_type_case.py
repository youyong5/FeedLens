"""Compare Atom alternate MIME identity against a saved XML document."""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_alternate_mime_case.xml"
TEST = ROOT / "atom_link_type_case_test.mbt"
ATOM = "{http://www.w3.org/2005/Atom}"


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(
        'test "Atom alternate MIME names compare case-insensitively without folding parameter values" {'
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
    feed_links = root.findall(ATOM + "link")
    entry_links = entry.findall(ATOM + "link")
    assert len(feed_links) == 4 and len(entry_links) == 2

    def identity(link: ET.Element) -> tuple[str | None, str | None, str | None]:
        declared = link.get("type")
        if declared is None:
            return None, None, link.get("hreflang")
        essence, separator, parameters = declared.partition(";")
        return essence.strip().lower(), parameters if separator else None, (
            link.get("hreflang") or ""
        ).lower()

    assert identity(feed_links[0]) == identity(feed_links[1])
    assert identity(feed_links[2]) != identity(feed_links[3])
    assert identity(entry_links[0]) == identity(entry_links[1])

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    cli = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    actual = json.loads(cli.stdout)
    assert actual["link"] == feed_links[0].get("href")
    assert actual["entries"][0]["link"] == entry_links[0].get("href")
    assert [link["type"] for link in actual["links"]] == [
        link.get("type") for link in feed_links
    ]
    assert [link["type"] for link in actual["entries"][0]["links"]] == [
        link.get("type") for link in entry_links
    ]
    assert [(d["kind"]["type"], d["kind"]["field"], d["line"]) for d in actual["diagnostics"]] == [
        ("DuplicateAtomField", "feed alternate link", 3),
        ("DuplicateAtomField", "entry alternate link", 8),
    ]
    print("PASS Atom alternate MIME identity and declared type preservation")


if __name__ == "__main__":
    main()
