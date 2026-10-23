"""Offline independent XML/JSON fixture check against the Native CLI.

Python ElementTree and json parse the checked-in inputs independently. This
checks only the declared common fields and direct-child selection; it makes no
claim of full RSS/JSON Feed conformance or of an independent parser oracle for
FeedLens diagnostics.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "samples"


def cli(filename: str) -> dict:
    result = subprocess.run(
        [shutil.which("moon") or str(Path.home() / ".moon/bin/moon"),
         "run", "--target", "native", "cmd/main", "--json", f"samples/{filename}"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    return json.loads(result.stdout)


def main() -> None:
    rss = ET.parse(SAMPLES / "rss2_optional_channel.xml").getroot()
    channel = rss.find("channel")
    assert channel is not None
    form = channel.find("textInput")
    cloud = channel.find("cloud")
    assert form is not None and cloud is not None
    model = cli("rss2_optional_channel.xml")
    assert model["docs_url"] == channel.findtext("docs")
    assert model["rating"] == channel.findtext("rating")
    assert model["cloud"] == {
        "domain": cloud.attrib["domain"],
        "port": int(cloud.attrib["port"]),
        "path": cloud.attrib["path"],
        "register_procedure": cloud.attrib["registerProcedure"],
        "protocol": cloud.attrib["protocol"],
    }
    assert model["text_input"] == {
        name: form.findtext(name) for name in ("title", "description", "name", "link")
    }
    assert model["diagnostics"] == []
    print("PASS RSS optional direct channel metadata vs ElementTree")

    payload = json.loads((SAMPLES / "jsonfeed10_legacy_ids.json").read_text("utf-8"))
    assert payload["version"] == "https://jsonfeed.org/version/1"
    expected = [
        json.dumps(item["id"], ensure_ascii=False, separators=(",", ":"))
        for item in payload["items"]
    ]
    model = cli("jsonfeed10_legacy_ids.json")
    assert [entry["identifier"] for entry in model["entries"]] == expected
    assert model["diagnostics"] == []
    print("PASS JSON Feed 1.0 coerced IDs vs Python JSON values")

    # The MoonBit tests embed the exact same fixture texts for all targets.
    tests = (ROOT / "rss_optional_channel_test.mbt").read_text("utf-8")
    lines = tests.splitlines()
    start = lines.index('test "RSS optional channel metadata is direct, ordered, and source aware" {')
    mirror = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirror.append(stripped[2:])
        elif mirror:
            break
    assert "\n".join(mirror) + "\n" == (SAMPLES / "rss2_optional_channel.xml").read_text("utf-8")
    json_tests = (ROOT / "json_feed_test.mbt").read_text("utf-8")
    assert '#|' + (SAMPLES / "jsonfeed10_legacy_ids.json").read_text("utf-8").strip() in json_tests
    print("PASS cross-target fixture mirrors")


if __name__ == "__main__":
    main()
