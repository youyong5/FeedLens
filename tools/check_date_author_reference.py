"""Offline date/author boundaries against feedparser and Python's stdlib.

The standalone MoonBit tests assert Atom-only T/Z case rules. Python's
generic ISO parser does not implement Atom's extra restriction.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import feedparser

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "samples"


def mirrored(name: str) -> str:
    lines = (ROOT / "date_author_boundary_test.mbt").read_text("utf-8").splitlines()
    start = lines.index(f'test "{name}" {{')
    result: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            result.append(stripped[2:])
        elif result:
            break
    return "\n".join(result) + "\n"


def cli(filename: str) -> dict:
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    proc = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", f"samples/{filename}"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(proc.stdout)


def utc_second(raw: str) -> datetime:
    # RFC 3339 permits lowercase t/z. Normalize spelling solely for the
    # independent stdlib clock comparison, not for FeedLens input.
    return datetime.fromisoformat(raw.replace("t", "T").replace("z", "Z")).astimezone(timezone.utc)


def main() -> None:
    atom_name = "atom1_date_case.xml"
    json_name = "jsonfeed11_empty_author_date.json"
    assert (SAMPLES / atom_name).read_text("utf-8") == mirrored(
        "Atom dates require uppercase T and Z while JSON Feed accepts RFC 3339 case"
    )
    assert (SAMPLES / json_name).read_text("utf-8") == mirrored(
        "JSON Feed keeps explicitly empty plain-text author names and lowercase RFC 3339"
    )
    atom = cli(atom_name)
    reference = feedparser.parse((SAMPLES / atom_name).read_bytes())
    assert not reference.bozo
    assert atom["identifier"] == reference.feed.id
    assert atom["entries"][0]["identifier"] == reference.entries[0].id
    assert utc_second(atom["entries"][0]["published_at"]) == utc_second(reference.entries[0].published)
    assert atom["diagnostics"] == []

    source = json.loads((SAMPLES / json_name).read_text("utf-8"))
    result = cli(json_name)
    assert [author["name"] for author in result["authors"]] == [
        value.get("name") for value in source["authors"]
    ]
    assert [value["name"] for value in result["entries"][0]["authors"]] == [" "]
    assert result["entries"][1]["authors"] == result["authors"]
    assert result["entries"][2]["authors"][0]["name"] == source["items"][2]["author"]["name"]
    assert utc_second(result["entries"][0]["published_at"]) == utc_second(
        result["entries"][1]["updated_at"]
    )
    assert result["diagnostics"] == []
    print(f"PASS mirrored Atom/JSON samples; feedparser {feedparser.__version__} and Python datetime/JSON intersection")


if __name__ == "__main__":
    main()
