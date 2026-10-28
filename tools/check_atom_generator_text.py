"""Compare declared Atom generator text with an independent XML reader and CLI."""

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATOM = "{http://www.w3.org/2005/Atom}"
TEST = ROOT / "atom_generator_text_test.mbt"


def mirrored(title: str, filename: str) -> Path:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(f'test "{title}" {{')
    embedded = []
    for line in lines[start + 1 :]:
        line = line.lstrip()
        if line.startswith("#|"):
            embedded.append(line[2:])
        elif embedded:
            break
    sample = ROOT / "samples" / filename
    assert "\n".join(embedded) + "\n" == sample.read_text("utf-8")
    return sample


def declared(node: ET.Element) -> tuple[str, str | None, str | None]:
    return (node.text or "", node.get("uri"), node.get("version"))


def main() -> None:
    feed_path = mirrored(
        "Atom feed and source retain declared empty and whitespace generator text",
        "atom1_generator_text.xml",
    )
    entry_path = mirrored(
        "standalone Atom Entry source retains a present empty generator",
        "atom1_entry_generator_text.xml",
    )
    root = ET.parse(feed_path).getroot()
    feed_generator = root.find(ATOM + "generator")
    source_generator = root.find(f"{ATOM}entry/{ATOM}source/{ATOM}generator")
    standalone_generator = ET.parse(entry_path).getroot().find(
        f"{ATOM}source/{ATOM}generator"
    )
    assert all(node is not None for node in (feed_generator, source_generator, standalone_generator))
    assert declared(feed_generator) == ("", "tools/", "")
    assert declared(source_generator) == ("  ", "", "2")
    assert declared(standalone_generator) == ("", None, "3")

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(feed_path)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    parsed = json.loads(output.stdout)
    assert parsed["diagnostics"] == []
    assert (parsed["generator"], parsed["generator_uri"], parsed["generator_version"]) == declared(feed_generator)
    source = parsed["entries"][0]["atom_source"]
    assert (source["generator"], source["generator_uri"], source["generator_version"]) == declared(source_generator)
    print("PASS Atom generator empty/whitespace declarations, Entry mirror and CLI")


if __name__ == "__main__":
    main()
