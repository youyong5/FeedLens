"""Compare attachment MIME fixtures using Python email, XML/JSON and CLI."""

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from email import policy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / "attachment_media_type_test.mbt"
RSS = ROOT / "samples/rss2_attachment_media_types.xml"
JSON = ROOT / "samples/jsonfeed11_attachment_media_types.json"


def mirror(name: str, sample: Path) -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(f'test "{name}" {{')
    mirrored = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert "\n".join(mirrored) + "\n" == sample.read_text("utf-8")


def cli(sample: Path) -> dict:
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(sample)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    return json.loads(output.stdout)


def main() -> None:
    mirror("RSS enclosure keeps malformed MIME declaration with a located warning", RSS)
    mirror("JSON Feed attachment keeps malformed MIME text and valid quoted parameters", JSON)

    rss = ET.parse(RSS).getroot()
    rss_item = rss.find("./channel/item")
    assert rss_item is not None
    rss_types = [node.attrib["type"] for node in rss_item.findall("enclosure")]
    json_item = json.loads(JSON.read_text("utf-8"))["items"][0]
    json_types = [node["mime_type"] for node in json_item["attachments"]]
    assert rss_types == ["audio", 'text/plain; charset="utf-8"', "AUDIO/MPEG"]
    assert json_types == ["audio/", 'text/plain; charset="utf-8"', "AUDIO/MPEG"]

    def defects(media_type: str) -> bool:
        return bool(policy.default.header_factory("Content-Type", media_type).defects)

    assert [defects(media_type) for media_type in rss_types] == [True, False, False]
    assert [defects(media_type) for media_type in json_types] == [True, False, False]
    rss_cli, json_cli = cli(RSS), cli(JSON)
    for expected, result in ((rss_types, rss_cli), (json_types, json_cli)):
        assert [entry["media_type"] for entry in result["entries"][0]["attachments"]] == expected
        assert len(result["diagnostics"]) == 1
        assert result["diagnostics"][0]["kind"]["type"] == "InvalidAttachment"
    assert rss_cli["diagnostics"][0]["kind"]["message"] == "invalid RSS enclosure type"
    assert rss_cli["diagnostics"][0]["line"] == 2
    assert json_cli["diagnostics"][0]["kind"]["message"] == "json feed item 0 attachment 0: invalid mime_type"
    print("PASS RSS/JSON attachment MIME mirrors, independent email parser and CLI recovery")


if __name__ == "__main__":
    main()
