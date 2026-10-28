"""Independent XML tree check for Atom Person text-only field boundaries."""

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATOM = "{http://www.w3.org/2005/Atom}"
EXT = "{urn:person-extension}"
TEST = ROOT / "atom_person_nested_test.mbt"


def mirror(title: str, sample: str) -> Path:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(f'test "{title}" {{')
    embedded = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            embedded.append(stripped[2:])
        elif embedded:
            break
    path = ROOT / "samples" / sample
    assert "\n".join(embedded) + "\n" == path.read_text("utf-8")
    return path


def direct_field(person: ET.Element, name: str) -> tuple[str, bool]:
    field = person.find(ATOM + name)
    assert field is not None
    return "".join(field.itertext()), len(field) != 0


def main() -> None:
    feed_path = mirror(
        "Atom Person text fields diagnose nested markup without losing other declarations",
        "atom1_person_nested.xml",
    )
    entry_path = mirror(
        "independent Atom Entry diagnoses nested Person URI and keeps source resolution",
        "atom1_entry_person_nested.xml",
    )
    root = ET.parse(feed_path).getroot()
    author = root.find(ATOM + "author")
    contributor = root.find(ATOM + "contributor")
    item = root.find(ATOM + "entry")
    assert author is not None and contributor is not None and item is not None
    entry_author = item.find(ATOM + "author")
    source_author = item.find(f"{ATOM}source/{ATOM}author")
    assert entry_author is not None and source_author is not None
    assert direct_field(author, "name") == ("Feed <em>", False)
    assert author.find(EXT + "badge") is not None  # legal Person extension
    expected = [
        (contributor, "name", "AnestedZ"),
        (contributor, "uri", "people/"),
        (contributor, "email", "user@example.test"),
        (entry_author, "name", "Entry mixed text"),
        (source_author, "email", "source@example.test"),
    ]
    assert all(direct_field(owner, field) == (value, True) for owner, field, value in expected)
    assert source_author.find(EXT + "badge") is not None
    standalone = ET.parse(entry_path).getroot()
    standalone_author = standalone.find(ATOM + "author")
    assert standalone_author is not None
    assert direct_field(standalone_author, "uri") == ("people/", True)

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    output = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(feed_path)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    parsed = json.loads(output.stdout)
    assert [d["kind"] for d in parsed["diagnostics"]] == [
        {"type": "InvalidAuthor", "message": f"nested markup in atom person {field}"}
        for _, field, _ in expected
    ]
    assert [(d["line"], d["column"]) for d in parsed["diagnostics"]] == [
        (3, 21), (3, 64), (3, 103), (4, 126), (5, 62)
    ]
    assert parsed["authors"][0]["name"] == "Feed <em>"
    assert parsed["contributors"][0]["name"] == "AnestedZ"
    assert parsed["entries"][0]["atom_source"]["authors"][0]["email"] == "source@example.test"
    print("PASS Atom Person text-only boundaries, extension children, mirrors and CLI diagnostics")


if __name__ == "__main__":
    main()
