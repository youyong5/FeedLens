"""Offline Atom/JSON legal-input intersection against independent readers.

feedparser 6.0.11 sanitizes XHTML and does not apply feed-level rights to
entries on this fixture. Compare its display-text intersection only; use
ElementTree to check the declared rights inheritance and stdlib json to check
opaque strings. No live feed is fetched by this script.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path

import feedparser

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "samples"
ATOM = "http://www.w3.org/2005/Atom"


class PlainText(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def display_text(markup: str) -> str:
    parser = PlainText()
    parser.feed(markup)
    return "".join(parser.parts)


def cli(filename: str) -> dict:
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    result = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", f"samples/{filename}"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def mirror(test_file: str, test_name: str) -> str:
    lines = (ROOT / test_file).read_text("utf-8").splitlines()
    start = lines.index(f'test "{test_name}" {{')
    result: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            result.append(stripped[2:])
        elif result:
            break
    return "\n".join(result) + "\n"


def main() -> None:
    atom_name = "atom1_legal_empty_and_rights.xml"
    json_name = "jsonfeed11_opaque_strings.json"
    assert mirror("atom_legal_text_test.mbt", "legal empty Atom text constructs and feed rights inheritance") == (SAMPLES / atom_name).read_text("utf-8")
    assert mirror("json_feed_test.mbt", "JSON Feed 1.1 retains nonblank opaque IDs and empty text but discards blank IDs") == (SAMPLES / json_name).read_text("utf-8")
    print("PASS both cross-target test/sample mirrors")

    atom = cli(atom_name)
    reference = feedparser.parse((SAMPLES / atom_name).read_bytes())
    assert not reference.bozo
    assert atom["identifier"] == reference.feed.id
    # feedparser strips blank whitespace from text constructs; FeedLens retains it.
    assert atom["title"].strip() == reference.feed.title == ""
    assert [entry["identifier"] for entry in atom["entries"]] == [entry.id for entry in reference.entries]
    assert [entry["title"] for entry in atom["entries"]] == [entry.title for entry in reference.entries]
    assert atom["entries"][0]["description"] == reference.entries[0].summary == ""
    assert atom["entries"][1]["rights"] == reference.entries[1].rights == ""
    assert atom["entries"][2]["atom_source"]["title"] == reference.entries[2].source.title == ""
    assert display_text(reference.feed.rights) == atom["rights"] == "License shared"
    tree = ET.parse(SAMPLES / atom_name).getroot()
    assert tree.find(f"{{{ATOM}}}rights") is not None
    entries = tree.findall(f"{{{ATOM}}}entry")
    assert entries[0].find(f"{{{ATOM}}}rights") is None
    assert entries[1].find(f"{{{ATOM}}}rights") is not None
    assert atom["entries"][0]["rights"] == atom["entries"][2]["rights"] == atom["rights"]
    assert atom["entries"][0]["rights_xhtml"] == atom["rights_xhtml"]
    assert atom["entries"][1]["rights"] == ""
    assert reference.entries[0].get("rights") is None  # documented feedparser difference
    assert atom["diagnostics"] == []
    print(f"PASS Atom empty-text intersection with feedparser {feedparser.__version__}; rights inheritance vs ElementTree")

    source = json.loads((SAMPLES / json_name).read_text("utf-8"))
    jf = cli(json_name)
    valid = [(i, item) for i, item in enumerate(source["items"]) if item["id"].strip()]
    assert [entry["identifier"] for entry in jf["entries"]] == [item["id"] for _, item in valid]
    assert [entry["content"] for entry in jf["entries"]] == [item.get("content_html", item.get("content_text")) for _, item in valid]
    assert [[tag["term"] for tag in entry["categories"]] for entry in jf["entries"]] == [item["tags"] for _, item in valid]
    assert [d["kind"] for d in jf["diagnostics"]] == [
        {"type": "InvalidJsonFeedItem", "index": i, "field": "id"}
        for i, item in enumerate(source["items"]) if not item["id"].strip()
    ]
    print("PASS JSON Feed nonblank IDs/content/tags and blank-ID discard vs stdlib JSON")


if __name__ == "__main__":
    main()
