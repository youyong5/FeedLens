"""End-to-end comparison of complete publisher responses at one pinned archive commit.

Run after checking out conorbronsdon/mojo-feed at the commit in REAL_WORLD.md:
  uv run --with feedparser==6.0.11 python tools/check_full_archived_feeds.py PATH_TO_test/data
The archived files are read-only inputs and are never modified or reduced.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
MOON = os.environ.get("FEEDLENS_MOON", "moon")
SHA256 = {
    "rss_hn.xml": "70083349c25d7778751f63cccc787cb7a75df85e4fa566faaa5662300d0bfbd2",
    "atom_xkcd.xml": "34ca646019ac7b8974e88dd76a2abe843000a94cdcdeaec08d216b700e8f0886",
    "jsonfeed_recompiled.json": "92057fdcca7b6e04464733f90a0b2e7387fa0afdeefaed4437573d0caa438c85",
}
ATOM = "{http://www.w3.org/2005/Atom}"


def cli(path: Path) -> dict:
    run = subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(path.resolve())],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    return json.loads(run.stdout)


def main(source: Path) -> None:
    assert feedparser.__version__ == "6.0.11"
    complete = {}
    for name, expected in SHA256.items():
        path = source / name
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == expected, f"archived bytes changed: {name}"
        complete[name] = (path, raw)

    rss_path, rss_raw = complete["rss_hn.xml"]
    rss = cli(rss_path)
    rss_ref = feedparser.parse(rss_raw)
    assert rss_ref.version == "rss20" and not rss_ref.bozo
    assert rss["format"] == "rss2" and rss["diagnostics"] == []
    assert len(rss["entries"]) == len(rss_ref.entries) == 20
    assert (rss["title"], rss["link"], rss["generator"]) == (
        rss_ref.feed.title, rss_ref.feed.link, rss_ref.feed.generator,
    )
    assert [
        (entry["identifier"], entry["title"], entry["link"], entry["published_at"])
        for entry in rss["entries"]
    ] == [
        (entry.id, entry.title, entry.link, entry.published)
        for entry in rss_ref.entries
    ]
    rss_tree = ET.fromstring(rss_raw)
    assert len(rss_tree.findall("./channel/item")) == 20
    print("PASS complete Hacker News RSS: 20 items, identity, title, link and date")

    atom_path, atom_raw = complete["atom_xkcd.xml"]
    atom = cli(atom_path)
    atom_ref = feedparser.parse(atom_raw)
    assert atom_ref.version == "atom10" and not atom_ref.bozo
    assert atom["format"] == "atom1" and len(atom["entries"]) == len(atom_ref.entries) == 4
    assert (atom["identifier"], atom["title"], atom["updated_at"]) == (
        atom_ref.feed.id, atom_ref.feed.title, atom_ref.feed.updated,
    )
    assert [
        (entry["identifier"], entry["title"], entry["link"], entry["updated_at"])
        for entry in atom["entries"]
    ] == [
        (entry.id, entry.title, entry.link, entry.updated)
        for entry in atom_ref.entries
    ]
    atom_tree = ET.fromstring(atom_raw)
    assert atom_tree.find(ATOM + "author") is None
    assert all(entry.find(ATOM + "author") is None for entry in atom_tree.findall(ATOM + "entry"))
    assert len(atom["diagnostics"]) == 5
    assert [d["kind"] for d in atom["diagnostics"]] == [
        {"type": "MissingFeedField", "field": "author"},
        *[{"type": "MissingEntryField", "index": i, "field": "author"} for i in range(4)],
    ]
    print("PASS complete xkcd Atom: four entries and source-declared missing authors")

    json_path, json_raw = complete["jsonfeed_recompiled.json"]
    published = json.loads(json_raw)
    parsed = cli(json_path)
    assert parsed["format"] == "jsonfeed1" and parsed["diagnostics"] == []
    assert len(parsed["entries"]) == len(published["items"]) == 6
    assert (parsed["title"], parsed["link"], parsed["identifier"]) == (
        published["title"], published["home_page_url"], published["feed_url"],
    )
    for actual, original in zip(parsed["entries"], published["items"], strict=True):
        assert (
            actual["identifier"], actual["title"], actual["link"],
            actual["published_at"], actual["content_html"], actual["content"],
        ) == (
            original["id"], original["title"], original["url"],
            original["date_published"], original["content_html"], original["content_html"],
        )
        assert actual["authors"][0]["name"] == published["author"]["name"]
        assert dt.datetime.fromisoformat(original["date_published"].replace("Z", "+00:00")).tzinfo
    print("PASS complete Recompiled JSON Feed: six items and unshortened HTML bodies")
    print("PASS three complete archived originals: SHA-256 checked; no editorial projection used")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: check_full_archived_feeds.py PATH_TO_PINNED_ARCHIVE_TEST_DATA")
    main(Path(sys.argv[1]))
