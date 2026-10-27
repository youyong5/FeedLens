"""Compare BOM-prefixed RSS/JSON Feed files with Python readers and Native CLI."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOM = b"\xef\xbb\xbf"
RSS = b'<?xml version="1.0" encoding="utf-8"?><rss version="2.0"><channel><title>BOM RSS</title><link>https://example.test/</link><description>News</description><item><title>One</title><link>https://example.test/one</link></item></channel></rss>'
JSON = b'{"version":"https://jsonfeed.org/version/1.1","title":"BOM JSON","items":[{"id":"one","content_text":"Hi"}]}'


def parse_cli(moon: str, path: Path) -> dict:
    output = subprocess.run(
        [moon, "run", "--target", "native", "--frozen", "cmd/main", "--json", str(path)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(output.stdout)


def main() -> None:
    moon = os.environ.get("FEEDLENS_MOON", "moon")
    with tempfile.TemporaryDirectory(prefix="feedlens-bom-") as directory:
        rss_path = Path(directory) / "rss.xml"
        json_path = Path(directory) / "json.json"
        rss_path.write_bytes(BOM + RSS)
        json_path.write_bytes(BOM + JSON)

        rss_reference = ET.fromstring(rss_path.read_bytes())
        json_reference = json.loads(json_path.read_bytes())
        assert rss_reference.findtext("channel/title") == "BOM RSS"
        assert json_reference["title"] == "BOM JSON"

        rss = parse_cli(moon, rss_path)
        jf = parse_cli(moon, json_path)
        assert rss["format"] == "rss2" and rss["title"] == "BOM RSS"
        assert rss["entries"][0]["link"] == rss_reference.findtext("channel/item/link")
        assert jf["format"] == "jsonfeed1" and jf["title"] == json_reference["title"]
        assert jf["entries"][0]["identifier"] == json_reference["items"][0]["id"]
        assert rss["diagnostics"] == jf["diagnostics"] == []
    print("PASS BOM-prefixed RSS/JSON files against ElementTree, Python JSON, and Native CLI")


if __name__ == "__main__":
    main()
