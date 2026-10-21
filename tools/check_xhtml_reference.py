"""Offline Atom XHTML intersection check against pinned feedparser 6.0.11.

Run with UV_CACHE_DIR inside this checkout when the default cache is restricted:
  uv run --offline --with feedparser==6.0.11 python tools/check_xhtml_reference.py
The MoonBit library and its tests never import feedparser.
"""

from __future__ import annotations

import html.parser
import json
import subprocess
from pathlib import Path

import feedparser

from check_compatibility import embedded_sample


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples" / "atom1_xhtml.xml"


class TextOnly(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def display_text(markup: str) -> str:
    parser = TextOnly()
    parser.feed(markup)
    return "".join(parser.parts)


def main() -> None:
    assert feedparser.__version__ == "6.0.11", feedparser.__version__
    assert embedded_sample("atom_xhtml_acceptance_sample", "xhtml_test.mbt") == SAMPLE.read_text("utf-8")
    reference = feedparser.parse(SAMPLE.read_bytes())
    process = subprocess.run(
        ["moon", "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    actual = json.loads(process.stdout)
    expected = {
        "feed_id": reference.feed.id,
        "feed_title_text": display_text(reference.feed.title),
        "feed_title_type": reference.feed.title_detail.type,
        "entry_id": reference.entries[0].id,
        "entry_title_text": display_text(reference.entries[0].title),
        "entry_title_type": reference.entries[0].title_detail.type,
        "entry_body_text": display_text(reference.entries[0].content[0].value),
        "entry_body_type": reference.entries[0].content[0].type,
    }
    observed = {
        "feed_id": actual["identifier"],
        "feed_title_text": actual["title"],
        "feed_title_type": "application/xhtml+xml" if actual["title_kind"] == "xhtml" else None,
        "entry_id": actual["entries"][0]["identifier"],
        "entry_title_text": actual["entries"][0]["title"],
        "entry_title_type": "application/xhtml+xml" if actual["entries"][0]["title_kind"] == "xhtml" else None,
        "entry_body_text": actual["entries"][0]["content"],
        "entry_body_type": "application/xhtml+xml" if actual["entries"][0]["content_kind"] == "xhtml" else None,
    }
    print(f"feedparser {feedparser.__version__}; mirrored Atom XHTML sample: PASS")
    for key, value in expected.items():
        assert observed[key] == value, (key, value, observed[key])
        print(f"PASS {key}: {value}")
    assert "<h:em" in actual["title_xhtml"]["markup"]
    assert "<h:p" in actual["entries"][0]["content_xhtml"]["markup"]
    print("PASS FeedLens namespaced XHTML fragments retained (not compared to sanitized HTML)")
    unsafe_probe = (
        '<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id>'
        '<title type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml">'
        '<span onclick="alert(1)">unsafe</span></div></title>'
        '<updated>2026-10-21T00:00:00Z</updated>'
        '<author><name>N</name></author></feed>'
    )
    sanitized = feedparser.parse(unsafe_probe).feed.title
    assert sanitized == "<span>unsafe</span>", sanitized
    print("PASS sanitizer difference: feedparser drops onclick; FeedLens retains declared XML attributes")


if __name__ == "__main__":
    main()
