"""Compare Atom generator/visual IRI declarations against XML and CLI output."""

import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urljoin


ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / "atom_visual_iri_test.mbt"
SAMPLE = ROOT / "samples/atom1_visual_iri.xml"
ATOM = "{http://www.w3.org/2005/Atom}"
XML_BASE = "{http://www.w3.org/XML/1998/namespace}base"
DOCUMENT = "https://example.test/feeds/main.atom"


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(
        'test "Atom generator and visuals preserve empty and malformed IRI declarations" {'
    )
    mirrored = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert "\n".join(mirrored) + "\n" == SAMPLE.read_text("utf-8")

    root = ET.parse(SAMPLE).getroot()
    entry = root.find(ATOM + "entry")
    assert entry is not None
    source = entry.find(ATOM + "source")
    assert source is not None
    generator = root.find(ATOM + "generator")
    source_generator = source.find(ATOM + "generator")
    icon = root.find(ATOM + "icon")
    logo = root.find(ATOM + "logo")
    source_icon = source.find(ATOM + "icon")
    source_logo = source.find(ATOM + "logo")
    assert all(node is not None for node in (
        generator, source_generator, icon, logo, source_icon, source_logo
    ))
    assert generator.attrib["uri"] == "bad[one]"
    assert source_generator.attrib["uri"] == ""
    assert [icon.text or "", logo.text or ""] == ["", "bad%GG"]
    assert [source_icon.text or "", source_logo.text or ""] == ["bad|url", ""]
    assert re.search(r"%(?![0-9A-Fa-f]{2})", logo.text)
    assert urljoin(urljoin(DOCUMENT, root.attrib[XML_BASE]), icon.attrib[XML_BASE]) == "https://example.test/feeds/assets/icons/"
    source_base = urljoin(urljoin(DOCUMENT, root.attrib[XML_BASE]), source.attrib[XML_BASE])
    assert urljoin(source_base, source_generator.attrib["uri"]) == "https://example.test/feeds/origins/"
    assert urljoin(source_base, source_logo.attrib[XML_BASE]) == "https://example.test/feeds/origins/brands/"

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    parsed = json.loads(output.stdout)
    assert parsed["generator_uri"] == generator.attrib["uri"]
    assert [image["url"] for image in parsed["images"]] == ["", "bad%GG"]
    source_data = parsed["entries"][0]["atom_source"]
    assert source_data["generator_uri"] == ""
    assert [image["url"] for image in source_data["images"]] == ["bad|url", ""]
    assert [(d["kind"], d["line"]) for d in parsed["diagnostics"]] == [
        ({"type": "InvalidAtomGeneratorUri", "field": "feed generator uri"}, 2),
        ({"type": "InvalidFeedImage", "message": "atom source icon invalid IRI"}, 3),
        ({"type": "InvalidFeedImage", "message": "atom logo invalid IRI"}, 2),
    ]
    print("PASS Atom generator/visual IRI mirror, XML scopes and CLI diagnostics")


if __name__ == "__main__":
    main()
