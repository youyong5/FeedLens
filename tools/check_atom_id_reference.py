"""Check Atom id spellings against an independent XML tree and URI parser."""

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_id_boundaries.xml"
ATOM = "{http://www.w3.org/2005/Atom}"
TEST = (ROOT / "atom_id_test.mbt").read_text("utf-8")
mirrored = [line.strip()[2:] for line in TEST.splitlines() if line.strip().startswith("#|")]
assert "\n".join(mirrored[:7]) + "\n" == SAMPLE.read_text("utf-8")

root = ET.parse(SAMPLE).getroot()
entries = root.findall(ATOM + "entry")
feed_id = root.findtext(ATOM + "id")
entry_ids = [entry.findtext(ATOM + "id") for entry in entries]
source = entries[0].find(ATOM + "source")
assert source is not None
source_id = source.findtext(ATOM + "id")
assert feed_id == "urn:feed:stable"
assert entry_ids == ["chapters/one", "https://例子.test/作品", " urn:bad:spaces ", ""]
assert source_id == "origins/main"
assert urlsplit(feed_id).scheme == "urn"
assert urlsplit(entry_ids[1]).scheme == "https"
assert not urlsplit(entry_ids[0]).scheme and not urlsplit(source_id).scheme
assert entry_ids[2] != entry_ids[2].strip()

moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
result = subprocess.run(
    [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
    cwd=ROOT,
    capture_output=True,
    text=True,
    check=True,
)
actual = json.loads(result.stdout)
assert actual["identifier"] == feed_id
assert [entry["identifier"] for entry in actual["entries"]] == [value or None for value in entry_ids]
assert actual["entries"][0]["atom_source"]["identifier"] == source_id
assert [(d["kind"]["type"], d["line"], d["column"]) for d in actual["diagnostics"]] == [
    ("InvalidAtomId", 3, 8),
    ("InvalidAtomId", 3, 122),
    ("InvalidAtomId", 5, 8),
    ("MissingEntryField", 6, 8),
]
print("PASS Atom id sample mirror, XML/URI identity and CLI diagnostics")
