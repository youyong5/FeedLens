"""Check one complete, author-valid real Atom archive against independent readers.

The archive is a full feed saved by rowanmanning/sample-feeds, pinned by the
CI checkout and SHA-256 below. It is not asserted to be a byte-for-byte copy
of the publisher's response: the archive rewrites its self link.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
ATOM = "{http://www.w3.org/2005/Atom}"
SHA256 = "46341f86af184fd68f2815795cf412299a831e13e7ba87f7e3f5b8f843724230"
MOON = os.environ.get("FEEDLENS_MOON", "moon")


def main(path: Path) -> None:
    assert feedparser.__version__ == "6.0.11"
    data = path.read_bytes()
    assert hashlib.sha256(data).hexdigest() == SHA256, "archived Atom bytes changed"
    root = ET.fromstring(data)
    assert root.tag == ATOM + "feed"
    entries = root.findall(ATOM + "entry")
    assert len(entries) == 20 and root.find(ATOM + "author") is None
    assert all(entry.find(f"{ATOM}author/{ATOM}name") is not None for entry in entries)

    run = subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(path.resolve())],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    actual = json.loads(run.stdout)
    reference = feedparser.parse(data)
    assert not reference.bozo and reference.version == "atom10"
    assert actual["format"] == "atom1" and actual["diagnostics"] == []
    assert actual["authors"] == [] and len(actual["entries"]) == len(reference.entries) == 20
    assert (actual["identifier"], actual["title"], actual["updated_at"]) == (
        root.find(ATOM + "id").text,
        root.find(ATOM + "title").text,
        root.find(ATOM + "updated").text,
    )
    for result, declared, compared in zip(actual["entries"], entries, reference.entries, strict=True):
        author = declared.find(f"{ATOM}author/{ATOM}name")
        content = declared.find(ATOM + "content")
        assert author is not None and content is not None
        assert (
            result["identifier"], result["title"], result["updated_at"],
            result["content"], result["authors"][0]["name"],
        ) == (
            declared.find(ATOM + "id").text,
            declared.find(ATOM + "title").text,
            declared.find(ATOM + "updated").text,
            content.text,
            author.text,
        )
        assert content.get("type") == result["content_kind"] == "html"
        assert (
            result["identifier"], result["title"].strip(), result["link"],
            result["updated_at"], result["authors"][0]["name"],
        ) == (
            compared.id, compared.title, compared.link, compared.updated, compared.author,
        )
    print("PASS complete author-valid archived Atom: 20 entries, exact HTML, zero diagnostics")
    print("PASS feedparser 6.0.11 identity, display titles, links, dates and authors")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: check_full_valid_atom.py PATH_TO_PINNED_ATOM_FEED")
    main(Path(sys.argv[1]))
