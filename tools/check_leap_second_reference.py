"""Offline cross-format leap-second intersection and NIST-date snapshot check.

feedparser 6.0.11 retains the raw XML dates but parses Atom :60 as next-day
00:00:00 and returns no RSS parsed tuple. Compare only identifiers/raw values;
independent Python datetime arithmetic checks positions at :59 against the
NIST announced-date snapshot. The MoonBit library tests check :60 output and
its explicit POSIX ambiguity flag.
"""

from __future__ import annotations

import datetime as dt
import email.utils
import json
import shutil
import subprocess
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "rss": "rss2_leap_second.xml",
    "atom": "atom1_leap_second.xml",
    "json": "jsonfeed11_leap_second.json",
}


def mirror(kind: str) -> str:
    lines = (ROOT / "date_leap_second_test.mbt").read_text("utf-8").splitlines()
    start = lines.index(f"fn leap_{kind}_sample() -> String {{")
    body: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            body.append(stripped[2:])
        elif body:
            break
    return "\n".join(body) + "\n"


def cli(kind: str) -> dict:
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    completed = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(ROOT / "samples" / FILES[kind])],
        cwd=ROOT, text=True, capture_output=True, check=True,
    )
    return json.loads(completed.stdout)


def known_days() -> set[str]:
    source = (ROOT / "samples/LEAP_SECONDS_NIST_2026-10-23.md").read_text("utf-8")
    lines = source.split("```text\n", 1)[1].split("\n```", 1)[0].splitlines()
    assert len(lines) == len(set(lines)) == 27
    return set(lines)


def atom_or_json_utc(raw: str, days: set[str]) -> tuple[str, int]:
    # datetime does not accept :60. Use the preceding representable second
    # solely to identify the UTC minute; construct the :60 display separately.
    assert ":60" in raw
    preceding = dt.datetime.fromisoformat(raw.replace(":60", ":59", 1)).astimezone(dt.timezone.utc)
    assert preceding.strftime("%H:%M:%S") == "23:59:59"
    day = preceding.date().isoformat()
    assert day in days
    return day + "T23:59:60Z", int(preceding.timestamp())


def main() -> None:
    assert feedparser.__version__ == "6.0.11"
    for kind, name in FILES.items():
        assert mirror(kind) == (ROOT / "samples" / name).read_text("utf-8")
    days = known_days()
    rss, atom, jf = (cli(kind) for kind in FILES)
    assert rss["diagnostics"] == atom["diagnostics"] == jf["diagnostics"] == []
    assert [item["entries"][0]["identifier"] for item in (rss, atom, jf)] == ["urn:leap:2016"] * 3
    rss_raw = rss["entries"][0]["published_at"]
    atom_raw = atom["updated_at"]
    json_raw = jf["entries"][0]["published_at"]
    rss_ref = feedparser.parse((ROOT / "samples" / FILES["rss"]).read_bytes())
    atom_ref = feedparser.parse((ROOT / "samples" / FILES["atom"]).read_bytes())
    assert not rss_ref.bozo and not atom_ref.bozo
    assert rss_ref.entries[0].id == atom_ref.entries[0].id == "urn:leap:2016"
    assert rss_ref.entries[0].published == rss_raw
    assert atom_ref.feed.updated == atom_raw
    assert json.loads((ROOT / "samples" / FILES["json"]).read_text("utf-8"))["items"][0]["date_published"] == json_raw
    assert rss_ref.entries[0].published_parsed is None  # documented reader difference
    # Python's mail date parser also cannot create second 60.
    previous = email.utils.parsedate_to_datetime(rss_raw.replace(":60", ":59", 1))
    previous = previous.astimezone(dt.timezone.utc)
    assert previous.date().isoformat() in days
    assert previous.strftime("%H:%M:%S") == "23:59:59"
    rss_position = (previous.date().isoformat() + "T23:59:60Z", int(previous.timestamp()))
    assert rss_position == atom_or_json_utc(atom_raw, days) == atom_or_json_utc(json_raw, days)
    assert rss_position == ("2016-12-31T23:59:60Z", 1483228799)
    print("PASS 27 NIST snapshot dates; RSS/Atom/JSON raw values, UTC positions, and reader intersection")


if __name__ == "__main__":
    main()
