"""Offline, independent intersection check for the three WP Tavern projections.

The files are editorially reduced from captured live responses, not complete
verbatim feeds. feedparser 6.0.11 supplies an independent XML reference; the
JSON Feed side is checked with Python's JSON parser and datetime library.
Run: uv run --with feedparser==6.0.11 python tools/check_real_cross_format.py
"""

from __future__ import annotations

import datetime as dt
import email.utils
import json
import os
import subprocess
from html.parser import HTMLParser
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "samples"
NAMES = ("rss", "atom", "json")
FILES = {
    "rss": "real_wptavern_rss.xml",
    "atom": "real_wptavern_atom.xml",
    "json": "real_wptavern_json.json",
}
MOON = os.environ.get("FEEDLENS_MOON", "moon")


def mirrored_input(filename: str, test_name: str) -> str:
    lines = (ROOT / filename).read_text("utf-8").splitlines()
    marker = f'test "{test_name}" {{'
    start = lines.index(marker) + 1
    while lines[start].strip() != "let input =":
        start += 1
    mirror: list[str] = []
    for line in lines[start + 1 :]:
        if not line.lstrip().startswith("#|"):
            break
        mirror.append(line.lstrip().removeprefix("#|"))
    return "\n".join(mirror) + "\n"


class TextOnly(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def visible_text(markup: str) -> str:
    parser = TextOnly()
    parser.feed(markup)
    return "".join(parser.parts)


def cli_values(name: str) -> dict:
    process = subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(SAMPLES / FILES[name])],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(process.stdout)


def instant(raw: str, name: str) -> dt.datetime:
    if name == "rss":
        value = email.utils.parsedate_to_datetime(raw)
    else:
        value = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    assert value.tzinfo is not None
    return value.astimezone(dt.timezone.utc)


def reference_entries(name: str) -> list[tuple[str, dt.datetime, str, int]]:
    if name == "json":
        items = json.loads((SAMPLES / FILES[name]).read_text("utf-8"))["items"]
        return [
            (e["url"], instant(e["date_published"], name), e["attachments"][0]["url"], e["attachments"][0]["size_in_bytes"])
            for e in items
        ]
    parsed = feedparser.parse((SAMPLES / FILES[name]).read_bytes())
    assert not parsed.bozo, f"{name}: feedparser XML warning: {parsed.bozo_exception}"
    return [
        (e.link, dt.datetime(*e.published_parsed[:6], tzinfo=dt.timezone.utc), e.enclosures[0].href, int(e.enclosures[0].length))
        for e in parsed.entries
    ]


def main() -> None:
    mirrors = {
        "atom1_entry_document.xml": ("atom_document_test.mbt", "stand-alone Atom Entry Document keeps fields, XHTML, and source scopes"),
        "rss2_standard_fields.xml": ("standard_fields_test.mbt", "RSS copyright generator comments and item source keep their roles"),
        "atom1_standard_fields.xml": ("standard_fields_test.mbt", "Atom rights text constructs and generator preserve usable output"),
        "jsonfeed11_standard_fields.json": ("standard_fields_test.mbt", "JSON Feed retains both bodies, avatar-only authors, and pagination status"),
    }
    for sample, (filename, test_name) in mirrors.items():
        assert mirrored_input(filename, test_name) == (SAMPLES / sample).read_text("utf-8"), sample
    print(f"PASS {len(mirrors)} new sample/test mirrors")
    references = {name: reference_entries(name) for name in NAMES}
    assert all(len(rows) == 2 for rows in references.values())
    assert references["rss"] == references["atom"] == references["json"]
    for name in NAMES:
        document = cli_values(name)
        assert document["diagnostics"] == [], (name, document["diagnostics"])
        entries = document["entries"]
        actual = [
            (e["link"], instant(e["published_at"], name), e["attachments"][0]["url"], e["attachments"][0]["size_in_bytes"])
            for e in entries
        ]
        assert actual == references[name], (name, actual, references[name])
        print(f"PASS {name}: {len(actual)} ordered entries, UTC dates, permalinks, audio URL and size")
    standalone = feedparser.parse((SAMPLES / "atom1_entry_document.xml").read_bytes())
    assert not standalone.bozo and standalone.version == "atom10" and len(standalone.entries) == 1
    entry = standalone.entries[0]
    assert entry.id == "urn:feedlens:standalone:1"
    assert visible_text(entry.title) == "One entry"
    assert visible_text(entry.content[0].value) == "Body & context."
    assert entry.link == "posts/one"
    assert entry.enclosures[0].href == "posts/audio/one.mp3"
    assert entry.enclosures[0].type == "audio/mpeg"
    print("PASS independent Atom Entry Document reference: ID, XHTML text, xml:base links and enclosure")
    print(f"feedparser {feedparser.__version__}; checked-in projections only; no live fetch")


if __name__ == "__main__":
    main()
