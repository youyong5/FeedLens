"""Compare JSON Feed author version semantics using Python JSON and the CLI."""

import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEST = (ROOT / "json_author_version_test.mbt").read_text("utf-8")
MOON = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")

for version, filename, expected_feed, expected_items in [
    (
        "1",
        "jsonfeed10_author_versions.json",
        "Legacy editor",
        ["Legacy editor", "Legacy writer"],
    ),
    (
        "1.1",
        "jsonfeed11_author_versions.json",
        "Current editor",
        ["Current editor", "Current writer", None, "Legacy writer"],
    ),
]:
    sample = ROOT / "samples" / filename
    source_text = sample.read_text("utf-8")
    assert f"#|{source_text.strip()}" in TEST
    source = json.loads(source_text)
    assert source["version"] == f"https://jsonfeed.org/version/{version}"
    plural = version == "1.1"

    def declared_author(obj):
        if plural and "authors" in obj:
            return [author["name"] for author in obj["authors"]]
        if "author" in obj:
            return [obj["author"]["name"]]
        return None

    feed_authors = declared_author(source)
    item_authors = [
        declared_author(item) if declared_author(item) is not None else feed_authors
        for item in source["items"]
    ]
    assert feed_authors == [expected_feed]
    assert [authors[0] if authors else None for authors in item_authors] == expected_items

    result = subprocess.run(
        [MOON, "run", "--target", "native", "cmd/main", "--json", str(sample)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    actual = json.loads(result.stdout)
    assert actual["diagnostics"] == []
    assert [author["name"] for author in actual["authors"]] == feed_authors
    assert [[author["name"] for author in entry["authors"]] for entry in actual["entries"]] == item_authors

print("PASS JSON Feed 1.0/1.1 author sample mirrors and independent JSON comparison")
