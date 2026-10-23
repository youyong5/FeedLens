"""One-time, deterministic projection recipe for the vendored public snapshots.

Requires an adjacent mojo-feed-reference checkout at commit be9e1dbc17fa.
The checked-in projections are used offline; this script never fetches URLs.
"""

import json
import hashlib
import re
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT.parent / "mojo-feed-reference" / "test" / "data"
OUT = ROOT / "samples"
SOURCE_HASHES = {
    "rss_hn.xml": "70083349c25d7778751f63cccc787cb7a75df85e4fa566faaa5662300d0bfbd2",
    "jsonfeed_recompiled.json": "92057fdcca7b6e04464733f90a0b2e7387fa0afdeefaed4437573d0caa438c85",
}


def project_rss() -> None:
    root = ET.parse(DATA / "rss_hn.xml").getroot()
    channel = root.find("channel")
    assert channel is not None
    for item in channel.findall("item")[2:]:
        channel.remove(item)
    ET.indent(root)
    (OUT / "real_hn_rss.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        + ET.tostring(root, encoding="unicode")
        + "\n",
        encoding="utf-8",
    )


def project_json() -> None:
    source = json.loads((DATA / "jsonfeed_recompiled.json").read_text("utf-8"))
    source["items"] = source["items"][:2]
    for item in source["items"]:
        # Keep exactly the original opening HTML block, not invented prose.
        match = re.match(r"<div class=\"message-box\">.*?</div>", item["content_html"], re.S)
        assert match is not None
        item["content_html"] = match.group()
    (OUT / "real_recompiled_json.json").write_text(
        json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    for filename, expected in SOURCE_HASHES.items():
        assert hashlib.sha256((DATA / filename).read_bytes()).hexdigest() == expected, filename
    project_rss()
    project_json()
