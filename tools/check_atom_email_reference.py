"""Compare Atom Person email recovery with Python's RFC mail address parser."""

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from email.headerregistry import Address
from email.errors import HeaderParseError
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT / "atom_email_test.mbt"
FEED = ROOT / "samples/atom1_email_fields.xml"
ENTRY = ROOT / "samples/atom1_entry_email.xml"
ATOM = "{http://www.w3.org/2005/Atom}"


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


def accepted(value: str) -> bool:
    try:
        Address(addr_spec=value)
        return True
    except (ValueError, HeaderParseError):
        return False


def main() -> None:
    mirror("Atom Person email keeps quoted and domain literal addr-specs and diagnoses defects", FEED)
    mirror("standalone Atom Entry retains invalid email and accepts comments", ENTRY)
    root = ET.parse(FEED).getroot()
    item = root.find(ATOM + "entry")
    assert item is not None
    declared = [
        root.find(f"{ATOM}author/{ATOM}email"),
        root.find(f"{ATOM}contributor/{ATOM}email"),
        item.find(f"{ATOM}author/{ATOM}email"),
        item.find(f"{ATOM}source/{ATOM}author/{ATOM}email"),
    ]
    assert all(node is not None for node in declared)
    emails = [node.text or "" for node in declared]
    assert emails == ['"a@b"@example.test', "bad..dot@example.test", "", "user@[192.0.2.1]"]
    assert [accepted(value) for value in emails] == [True, False, False, True]
    standalone = ET.parse(ENTRY).getroot()
    own = standalone.find(f"{ATOM}author/{ATOM}email")
    contributor = standalone.find(f"{ATOM}contributor/{ATOM}email")
    assert own is not None and contributor is not None
    assert not accepted(own.text)
    assert accepted(contributor.text)

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(FEED)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    parsed = json.loads(output.stdout)
    item = parsed["entries"][0]
    assert [parsed["authors"][0]["email"], parsed["contributors"][0]["email"],
            item["authors"][0]["email"], item["atom_source"]["authors"][0]["email"]] == emails
    assert [(d["kind"], d["line"]) for d in parsed["diagnostics"]] == [
        ({"type": "InvalidAuthor", "message": "invalid atom person email"}, 2),
        ({"type": "InvalidAuthor", "message": "invalid atom person email"}, 2),
    ]
    print("PASS Atom Person email mirrors, Python Address intersection and CLI recovery")


if __name__ == "__main__":
    main()
