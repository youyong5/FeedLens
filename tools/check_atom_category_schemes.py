"""Compare Atom's absolute category schemes with an independent XML walk."""

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urljoin, urlsplit


ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/atom1_category_schemes.xml"
ATOM = "{http://www.w3.org/2005/Atom}"
XML_BASE = "{http://www.w3.org/XML/1998/namespace}base"
TEST = (ROOT / "atom_category_scheme_test.mbt").read_text("utf-8")

mirrored = [line.strip()[2:] for line in TEST.splitlines() if line.strip().startswith("#|")]
assert "\n".join(mirrored[:5]) + "\n" == SAMPLE.read_text("utf-8")

root = ET.parse(SAMPLE).getroot()
entry = root.find(ATOM + "entry")
assert entry is not None
source = entry.find(ATOM + "source")
assert source is not None
feed_categories = root.findall(ATOM + "category")
entry_categories = entry.findall(ATOM + "category")
source_categories = source.findall(ATOM + "category")
assert len(feed_categories) == 2 and len(entry_categories) == len(source_categories) == 1

feed_base = urljoin("https://example.test/main.atom", root.attrib[XML_BASE])
entry_base = urljoin(feed_base, entry.attrib[XML_BASE])
source_base = urljoin(entry_base, source.attrib[XML_BASE])
for base, categories in [
    (feed_base, feed_categories),
    (entry_base, entry_categories),
    (source_base, source_categories),
]:
    for category in categories:
        scheme = category.attrib["scheme"]
        assert urlsplit(scheme).scheme
        assert urljoin(base, scheme) == scheme

moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
result = subprocess.run(
    [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
    cwd=ROOT,
    capture_output=True,
    text=True,
    check=True,
)
actual = json.loads(result.stdout)
assert actual["diagnostics"] == []
assert [category["scheme"] for category in actual["categories"]] == [
    category.attrib["scheme"] for category in feed_categories
]
assert [category["scheme"] for category in actual["entries"][0]["categories"]] == [
    category.attrib["scheme"] for category in entry_categories
]
assert [category["scheme"] for category in actual["entries"][0]["atom_source"]["categories"]] == [
    category.attrib["scheme"] for category in source_categories
]
print("PASS Atom category scheme sample mirror, absolute IRIs and CLI projection")
