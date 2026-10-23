"""Offline reference intersections for three independent publisher snapshots.

Run: uv run --with feedparser==6.0.11 python tools/check_diverse_real_reference.py
The originals and transformation recipe are recorded in samples/REAL_WORLD.md.
"""

from __future__ import annotations

import datetime as dt
import email.utils
import json
import os
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
MOON = os.environ.get("FEEDLENS_MOON", "moon")
FILES = {
    "rss": "real_hn_rss.xml",
    "atom": "real_xkcd_atom.xml",
    "json": "real_recompiled_json.json",
}


def mirrored(name: str) -> str:
    lines = (ROOT / "diverse_real_test.mbt").read_text("utf-8").splitlines()
    marker = f"fn diverse_{name}_sample() -> String {{"
    start = lines.index(marker) + 2
    value: list[str] = []
    for line in lines[start:]:
        if not line.startswith("    #|"):
            break
        value.append(line[6:])
    assert value
    return "\n".join(value) + "\n"


def cli(name: str) -> dict:
    result = subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(ROOT / "samples" / FILES[name])],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def main() -> None:
    assert feedparser.__version__ == "6.0.11"
    for name, filename in FILES.items():
        assert mirrored(name) == (ROOT / "samples" / filename).read_text("utf-8")
    print("PASS three byte-identical checked-in / MoonBit mirrors")

    rss_ref = feedparser.parse((ROOT / "samples" / FILES["rss"]).read_bytes())
    rss = cli("rss")
    assert not rss_ref.bozo and rss_ref.version == "rss20"
    assert rss["diagnostics"] == [] and len(rss["entries"]) == len(rss_ref.entries) == 2
    assert (rss["title"], rss["link"], rss["docs_url"], rss["generator"], rss["updated_at"]) == (
        rss_ref.feed.title, rss_ref.feed.link, rss_ref.feed.docs, rss_ref.feed.generator,
        rss_ref.feed.updated,
    )
    for actual, reference in zip(rss["entries"], rss_ref.entries, strict=True):
        assert (actual["identifier"], actual["title"], actual["link"], actual["published_at"]) == (
            reference.id, reference.title, reference.link, reference.published,
        )
        assert dt.datetime(*reference.published_parsed[:6], tzinfo=dt.timezone.utc) == email.utils.parsedate_to_datetime(
            actual["published_at"]
        ).astimezone(dt.timezone.utc)
        assert actual["authors"] == [{
            "source": "dublin_core", "name": reference.author,
            "email": None, "uri": None, "avatar": None,
        }]
    print("PASS Hacker News RSS: metadata, ordered story records and Dublin Core creator names")

    lines = (ROOT / "rss_dublin_creator_test.mbt").read_text("utf-8").splitlines()
    start = lines.index("fn rss_dublin_sample() -> String {") + 2
    mirrored_xml = []
    for line in lines[start:]:
        if not line.startswith("    #|"):
            break
        mirrored_xml.append(line[6:])
    creator_file = ROOT / "samples" / "rss2_dublin_creator.xml"
    assert "\n".join(mirrored_xml) + "\n" == creator_file.read_text("utf-8")
    creator_root = ET.parse(creator_file).getroot()
    ns = {"d": "http://purl.org/dc/elements/1.1/"}
    items = creator_root.findall("./channel/item")
    assert len(items) == 3
    assert [e.text for e in items[0].findall("./d:creator", ns)] == [
        "Jane & Co", "Second credited editor",
    ]
    assert items[0].find("./author").text == "one@example.test"
    creator_cli = json.loads(subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(creator_file)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout)
    assert [(a["source"], a["name"], a["email"]) for a in creator_cli["entries"][0]["authors"]] == [
        ("rss2", None, "one@example.test"),
        ("dublin_core", "Jane & Co", None),
        ("dublin_core", "Second credited editor", None),
    ]
    assert creator_cli["entries"][1]["authors"][0]["name"] == items[1].find("./d:creator", ns).text
    assert [d["kind"]["type"] for d in creator_cli["diagnostics"]] == [
        "InvalidAuthor", "UnsupportedNestedMarkup",
    ]
    print("PASS synthetic namespace/order boundaries against ElementTree direct children; invalid creators diagnosed")

    atom_ref = feedparser.parse((ROOT / "samples" / FILES["atom"]).read_bytes())
    atom = cli("atom")
    assert not atom_ref.bozo and atom_ref.version == "atom10"
    assert len(atom["entries"]) == len(atom_ref.entries) == 4
    assert (atom["identifier"], atom["title"], atom["link"], atom["updated_at"]) == (
        atom_ref.feed.id, atom_ref.feed.title, atom_ref.feed.link, atom_ref.feed.updated,
    )
    for actual, reference in zip(atom["entries"], atom_ref.entries, strict=True):
        assert (actual["identifier"], actual["title"], actual["link"], actual["updated_at"]) == (
            reference.id, reference.title, reference.link, reference.updated,
        )
        assert actual["published_at"] is None and reference.get("published") is None
        assert actual["description_kind"] == "html" and reference.summary_detail.type == "text/html"
    tree = ET.parse(ROOT / "samples" / FILES["atom"])
    ns = {"a": "http://www.w3.org/2005/Atom"}
    assert tree.findall("./a:author", ns) == []
    assert all(not entry.findall("./a:author", ns) for entry in tree.findall("./a:entry", ns))
    assert [e["kind"]["type"] for e in atom["diagnostics"]] == [
        "MissingFeedField", *["MissingEntryField"] * 4,
    ]
    assert all(e["kind"]["field"] == "author" for e in atom["diagnostics"])
    print("PASS xkcd Atom: four ordered records and HTML type; real missing-author diagnostics verified against XML")

    source = json.loads((ROOT / "samples" / FILES["json"]).read_text("utf-8"))
    parsed = cli("json")
    assert parsed["diagnostics"] == [] and len(parsed["entries"]) == len(source["items"]) == 2
    assert (parsed["title"], parsed["link"], parsed["identifier"], parsed["language"]) == (
        source["title"], source["home_page_url"], source["feed_url"], source["language"],
    )
    for actual, item in zip(parsed["entries"], source["items"], strict=True):
        assert (actual["identifier"], actual["title"], actual["link"], actual["published_at"], actual["content"]) == (
            item["id"], item["title"], item["url"], item["date_published"], item["content_html"],
        )
        assert actual["content_kind"] == "html"
        assert actual["authors"][0]["name"] == source["author"]["name"]
        assert dt.datetime.fromisoformat(item["date_published"].replace("Z", "+00:00")).tzinfo is not None
    print("PASS Recompiled JSON Feed: two ordered records, exact HTML, dates and inherited author")


if __name__ == "__main__":
    main()
