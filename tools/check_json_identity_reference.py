"""Independently compare JSON Feed item identity order and duplicate diagnostics."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/jsonfeed11_duplicate_ids.json"


def main() -> None:
    lines = (ROOT / "json_identity_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "JSON Feed diagnoses repeated effective IDs and preserves every item" {')
    mirror = next(
        line.lstrip()[2:] for line in lines[start + 1:]
        if line.lstrip().startswith("#|")
    ) + "\n"
    assert mirror == SAMPLE.read_text("utf-8")

    source = json.loads(SAMPLE.read_text("utf-8"))
    assert source["version"] == "https://jsonfeed.org/version/1.1"
    identifiers: list[str] = []
    repeated: list[int] = []
    for index, item in enumerate(source["items"]):
        raw = item["id"]
        assert isinstance(raw, (str, int)) and not isinstance(raw, bool)
        identifier = str(raw)
        if identifier in identifiers:
            repeated.append(index)
        identifiers.append(identifier)
    assert identifiers == ["post", "Post", " post ", "post", "12", "12"]
    assert repeated == [3, 5]

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    cli = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    actual = json.loads(cli.stdout)
    assert [entry["identifier"] for entry in actual["entries"]] == identifiers
    assert [entry["content"] for entry in actual["entries"]] == [
        item.get("content_html", item.get("content_text")) for item in source["items"]
    ]
    assert [(d["kind"], d["line"], d["column"]) for d in actual["diagnostics"]] == [
        ({"type": "InvalidJsonFeedItem", "index": index, "field": "duplicate id"}, 1, 1)
        for index in repeated
    ]
    print("PASS JSON Feed ID sample mirror, Python JSON identity and CLI diagnostics")


if __name__ == "__main__":
    main()
