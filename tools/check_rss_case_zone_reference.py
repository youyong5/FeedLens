"""Compare RSS mail-date case and Z-zone handling with Python's email parser."""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from datetime import timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/rss2_case_and_zone.xml"


def main() -> None:
    lines = (ROOT / "rss_date_case_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "RSS RFC 822 date tokens ignore case and Z has a known UTC offset" {')
    mirrored: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert "\n".join(mirrored) + "\n" == SAMPLE.read_text("utf-8")

    root = ET.fromstring(SAMPLE.read_bytes())
    channel = root.find("channel")
    assert channel is not None
    items = channel.findall("item")
    raw = [
        channel.findtext("pubDate"),
        channel.findtext("lastBuildDate"),
        *(item.findtext("pubDate") for item in items),
    ]
    assert all(raw)
    reference = [parsedate_to_datetime(value) for value in raw]
    assert [value.astimezone(timezone.utc).isoformat() for value in reference[:4]] == [
        "2026-10-24T12:00:00+00:00",
        "2026-10-24T12:15:00+00:00",
        "2026-10-24T12:00:00+00:00",
        "2026-10-24T16:30:00+00:00",
    ]
    # RFC 1123 notes that non-Z military zones have ambiguous sign; Python's
    # mail parser likewise returns no usable offset for A. Never call
    # astimezone on a naive result, which would guess the machine's timezone.
    assert reference[-1].tzinfo is None
    assert parsedate_to_datetime("Sat, 24 Oct 2026 12:00:00 J").tzinfo is None

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    cli = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    actual = json.loads(cli.stdout)
    assert [actual["published_at"], actual["updated_at"], *(
        entry["published_at"] for entry in actual["entries"]
    )] == raw
    assert [(d["kind"], d["line"]) for d in actual["diagnostics"]] == [
        ({"type": "UnnormalizedRssDate", "field": "item pubDate"}, 5),
    ]
    print("PASS RSS date case/Z sample mirror and independent Python mail-date UTC intersection")


if __name__ == "__main__":
    main()
