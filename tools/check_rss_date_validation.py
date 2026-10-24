"""Compare RSS date diagnostics with XML and Python's mail-date calendar parser."""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime
from email.utils import parsedate_to_datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "rss2_invalid_dates.xml"


def normalized_by_reference(raw: str) -> bool:
    if not raw:
        return False
    try:
        value = parsedate_to_datetime(raw)
    except (TypeError, ValueError):
        return False
    # Python's email parser is lenient about a wrong weekday. RSS dates are
    # checked against the actual calendar weekday by the library.
    weekday = raw.split(",", 1)[0] if "," in raw else None
    return weekday is None or weekday == value.strftime("%a")


def main() -> None:
    source = (ROOT / "samples" / NAME).read_text("utf-8")
    lines = (ROOT / "rss_date_validation_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "RSS date diagnostics retain channel and item text and recover the items" {')
    mirrored: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert source == "\n".join(mirrored) + "\n"

    root = ET.fromstring(source)
    channel = root.find("channel")
    assert channel is not None
    items = channel.findall("item")
    raw = [
        channel.findtext("pubDate", default=""),
        channel.findtext("lastBuildDate", default=""),
        *(item.findtext("pubDate", default="") for item in items),
    ]
    assert [normalized_by_reference(value) for value in raw] == [False, False, False, False, True]
    assert parsedate_to_datetime(raw[-1]).date() == datetime(2026, 10, 24).date()
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", f"samples/{NAME}"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    result = json.loads(output.stdout)
    assert [result["published_at"], result["updated_at"], *(
        entry["published_at"] for entry in result["entries"]
    )] == [value or None for value in raw]
    assert [
        (d["kind"]["field"], d["line"], d["column"])
        for d in result["diagnostics"]
    ] == [
        ("channel pubDate", 2, 1), ("channel lastBuildDate", 2, 49),
        ("item pubDate", 3, 49), ("item pubDate", 4, 43),
    ]
    assert all(d["kind"]["type"] == "UnnormalizedRssDate" for d in result["diagnostics"])
    print("PASS mirrored RSS dates and retained CLI values vs Python mail-date calendar parsing")


if __name__ == "__main__":
    main()
