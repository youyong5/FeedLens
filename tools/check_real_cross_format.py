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
from urllib.parse import urljoin

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
        "rss2_metadata.xml": ("rss_metadata_test.mbt", "RSS guid role, source credit, and channel contacts"),
        "atom1_source_metadata.xml": ("atom_source_test.mbt", "aggregated Atom entry retains source identity and XHTML title"),
        "atom1_person_uris.xml": ("atom_person_uri_test.mbt", "Atom person URI scopes and inheritance across feed, entry and source"),
        "rss2_anonymous_items.xml": ("rss_item_required_test.mbt", "RSS title-only and description-only items are valid without identifiers"),
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
    rss_metadata = feedparser.parse((SAMPLES / "rss2_metadata.xml").read_bytes())
    assert not rss_metadata.bozo and len(rss_metadata.entries) == 2
    rss_cli = json.loads(subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(SAMPLES / "rss2_metadata.xml")],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout)
    assert rss_cli["diagnostics"] == []
    assert rss_cli["managing_editor"] == "editor@example.test"
    assert rss_cli["webmaster"] == "ops@example.test"
    for reference, actual in zip(rss_metadata.entries, rss_cli["entries"], strict=True):
        assert actual["identifier"] == reference.id
        assert actual["guid_is_permalink"] == reference.guidislink
    assert rss_cli["entries"][0]["source_title"] == rss_metadata.entries[0].source.title
    assert rss_cli["entries"][0]["source_url"] == rss_metadata.entries[0].source.href
    print("PASS independent RSS guid permalink role and source credit; channel contacts checked against fixture")
    anonymous_ref = feedparser.parse((SAMPLES / "rss2_anonymous_items.xml").read_bytes())
    assert not anonymous_ref.bozo and len(anonymous_ref.entries) == 3
    anonymous_cli = json.loads(subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(SAMPLES / "rss2_anonymous_items.xml")],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout)
    assert anonymous_cli["diagnostics"] == []
    for reference, actual in zip(anonymous_ref.entries, anonymous_cli["entries"], strict=True):
        assert actual["identifier"] is None
        assert actual["title"] == reference.get("title")
        assert actual["description"] == reference.get("summary")
    print("PASS independent RSS legal anonymous item intersection: title, description, and order")
    atom_source_reference = feedparser.parse((SAMPLES / "atom1_source_metadata.xml").read_bytes())
    assert not atom_source_reference.bozo and len(atom_source_reference.entries) == 1
    atom_source_cli = json.loads(subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(SAMPLES / "atom1_source_metadata.xml")],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout)
    assert atom_source_cli["diagnostics"] == []
    source = atom_source_cli["entries"][0]["atom_source"]
    reference = atom_source_reference.entries[0].source
    assert source["identifier"] == reference.id
    # feedparser 6.0.11 overwrites source.title with icon text in this fixture;
    # title_detail.value still retains the actual XHTML title.
    assert source["title"] == visible_text(reference.title_detail.value)
    assert source["title_kind"] == "xhtml" and reference.title_detail.type == "application/xhtml+xml"
    assert source["title_xhtml"]["language"] == reference.title_detail.language == "fr"
    assert source["updated_at"] == reference.updated
    assert source["authors"][0]["name"] == reference.authors[0].name
    assert source["contributors"][0]["name"] == reference.contributors[0].name
    assert source["categories"][0]["term"] == reference.tags[0].term
    assert source["categories"][0]["scheme"] == reference.tags[0].scheme
    assert source["rights"] == reference.rights
    assert source["rights_kind"] == "html" and reference.rights_detail.type == "text/html"
    assert source["subtitle"] == reference.subtitle
    assert source["subtitle_kind"] == "html" and reference.subtitle_detail.type == "text/html"
    assert source["generator"] == reference.generator_detail.name
    assert source["generator_version"] == reference.generator_detail.version
    assert source["generator_uri"] == "tool" and reference.generator_detail.href == "origins/tool"
    assert source["link"] == "home" and reference.link == "origins/home"
    assert [link["rel"] for link in source["links"]] == [link.rel for link in reference.links]
    assert [link["href"] for link in source["links"]] == ["home", "index.atom"]
    assert [link.href for link in reference.links] == ["origins/home", "origins/index.atom"]
    assert atom_source_cli["generator"] == atom_source_reference.feed.generator
    assert source["images"][0]["url"] == "icon.png" and source["images"][1]["url"] == "logo.png"
    print("PASS independent Atom source identity, XHTML title_detail, subtitle, generator, links, updated, people, category and rights; images fixture-only")
    people_ref = feedparser.parse((SAMPLES / "atom1_person_uris.xml").read_bytes())
    assert not people_ref.bozo and len(people_ref.entries) == 3
    people_cli = json.loads(subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(SAMPLES / "atom1_person_uris.xml")],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout)
    assert people_cli["diagnostics"] == []
    base = "https://example.test/feeds/"
    assert urljoin(base + "staff/", people_cli["authors"][0]["uri"]) == people_ref.feed.authors[0].href
    assert urljoin(base, people_cli["contributors"][0]["uri"]) == people_ref.feed.contributors[0].href
    first = people_cli["entries"][0]
    first_ref = people_ref.entries[0]
    assert urljoin(base + "people/", first["authors"][0]["uri"]) == first_ref.authors[0].href
    assert urljoin(base + "posts/", first["contributors"][0]["uri"]) == first_ref.contributors[0].href
    assert urljoin(base + "origin/", first["atom_source"]["authors"][0]["uri"]) == first_ref.source.authors[0].href
    assert urljoin(base + "origin/staff/", first["atom_source"]["contributors"][0]["uri"]) == first_ref.source.contributors[0].href
    second = people_cli["entries"][1]
    assert urljoin(base + "origin/people/", second["atom_source"]["authors"][0]["uri"]) == people_ref.entries[1].source.authors[0].href
    print("PASS independent Atom person URI intersection: feed, entry and source scopes; inherited entry authors library-only")
    print(f"feedparser {feedparser.__version__}; checked-in projections only; no live fetch")


if __name__ == "__main__":
    main()
