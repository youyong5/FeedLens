"""Offline cross-format check for a known UTC instant with unknown local zone.

Compare saved feed fields with feedparser 6.0.11 for XML, stdlib JSON for
JSON Feed, and stdlib datetime/email for the UTC instant. The MoonBit API
regression asserts the distinct offset_known flag, which those readers do
not expose as a shared model.
"""

from __future__ import annotations

import datetime as dt
import email.utils
import json
import shutil
import subprocess
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "rss": "rss2_unknown_offset.xml",
    "atom": "atom1_unknown_offset.xml",
    "json": "jsonfeed11_unknown_offset.json",
}


def mirror(kind: str) -> str:
    lines = (ROOT / "date_unknown_offset_test.mbt").read_text("utf-8").splitlines()
    start = lines.index(f"fn unknown_offset_{kind}_sample() -> String {{")
    body = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            body.append(stripped[2:])
        elif body:
            break
    return "\n".join(body) + "\n"


def cli(kind: str) -> dict:
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    completed = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(ROOT / "samples" / FILES[kind])],
        cwd=ROOT, text=True, capture_output=True, check=True,
    )
    return json.loads(completed.stdout)


def main() -> None:
    assert feedparser.__version__ == "6.0.11"
    for kind, filename in FILES.items():
        assert mirror(kind) == (ROOT / "samples" / filename).read_text("utf-8")
    rss = cli("rss")
    atom = cli("atom")
    jf = cli("json")
    assert rss["diagnostics"] == atom["diagnostics"] == jf["diagnostics"] == []
    assert [feed["entries"][0]["identifier"] for feed in (rss, atom, jf)] == ["urn:story:one"] * 3
    rss_raw = rss["entries"][0]["published_at"]
    atom_raw = atom["entries"][0]["updated_at"]
    json_raw = jf["entries"][0]["published_at"]
    assert rss_raw.endswith(" -0000")
    assert atom_raw.endswith("-00:00") and json_raw.endswith("-00:00")
    rss_ref = feedparser.parse((ROOT / "samples" / FILES["rss"]).read_bytes())
    atom_ref = feedparser.parse((ROOT / "samples" / FILES["atom"]).read_bytes())
    assert not rss_ref.bozo and not atom_ref.bozo
    assert rss_ref.entries[0].published == rss_raw
    assert atom_ref.entries[0].updated == atom_raw
    source = json.loads((ROOT / "samples" / FILES["json"]).read_text("utf-8"))
    assert source["items"][0]["date_published"] == json_raw
    expected = dt.datetime(2026, 10, 14, 13, 0, tzinfo=dt.timezone.utc)
    mail_date = email.utils.parsedate_to_datetime(rss_raw)
    # Python deliberately returns naive datetime for -0000. The RFC declares
    # its clock reading to be UTC even though the original local zone is unknown.
    assert mail_date.tzinfo is None
    assert mail_date.replace(tzinfo=dt.timezone.utc) == expected
    assert dt.datetime.fromisoformat(atom_raw).astimezone(dt.timezone.utc) == expected
    assert dt.datetime.fromisoformat(json_raw).astimezone(dt.timezone.utc) == expected
    print("PASS three mirrored legal date inputs; feedparser fields and Python UTC intersection")


if __name__ == "__main__":
    main()
