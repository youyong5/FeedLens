"""Compare the declared intersection samples with Python feedparser.

This is development-only tooling. It is not invoked by MoonBit and never makes
network requests: every input is a checked-in file under samples/.

Run with an isolated dependency, for example:
  uv run --with feedparser==6.0.11 python tools/check_compatibility.py
"""

from __future__ import annotations

import json
from pathlib import Path

import feedparser


ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "samples"


def embedded_sample(function: str, test_file: str = "compatibility_test.mbt") -> str:
    """Read the deterministic `#|` mirror used by cross-target MoonBit tests."""
    lines = (ROOT / test_file).read_text("utf-8").splitlines()
    marker = f"fn {function}() -> String {{"
    start = lines.index(marker) + 1
    mirrored: list[str] = []
    for line in lines[start:]:
        if line == "  )":
            break
        if line == "  (":
            continue
        stripped = line.lstrip()
        if not stripped.startswith("#|"):
            raise RuntimeError(f"unexpected mirror line in {function}: {line!r}")
        mirrored.append(stripped.removeprefix("#|"))
    return "\n".join(mirrored) + "\n"


def nullable(value: object) -> str | None:
    if value is None:
        return None
    return str(value)


def field(mapping: object, name: str) -> str | None:
    return nullable(getattr(mapping, "get", lambda _name, default=None: default)(name))


def extract_rss(parsed: object) -> dict[str, object]:
    feed = parsed.feed
    entries = []
    for entry in parsed.entries:
        record = {
            "id": field(entry, "id"),
            "title": field(entry, "title"),
            "link": field(entry, "link"),
            "description": field(entry, "description"),
            "published": field(entry, "published"),
        }
        # RSS has no required identifier. Only compare this field when the
        # reference parser actually exposes one; FeedLens deliberately uses
        # its documented link fallback otherwise.
        if record["id"] is None:
            del record["id"]
        entries.append(record)
    return {
        "feed": {
            "title": field(feed, "title"),
            "link": field(feed, "link"),
            "description": field(feed, "description"),
        },
        "entries": entries,
    }


def extract_atom(parsed: object) -> dict[str, object]:
    feed = parsed.feed
    return {
        "feed": {
            "id": field(feed, "id"),
            "title": field(feed, "title"),
            "link": field(feed, "link"),
            "subtitle": field(feed, "subtitle"),
            "updated": field(feed, "updated"),
        },
        "entries": [
            {
                "id": field(entry, "id"),
                "title": field(entry, "title"),
                "link": field(entry, "link"),
                "summary": field(entry, "summary"),
                "published": field(entry, "published"),
                "updated": field(entry, "updated"),
            }
            for entry in parsed.entries
        ],
    }


def main() -> None:
    expected = json.loads((SAMPLES / "reference_intersection.json").read_text("utf-8"))
    extractors = {
        "rss2_compat.xml": extract_rss,
        "atom1_compat.xml": extract_atom,
    }
    print(f"feedparser {feedparser.__version__}")
    failures = 0
    mirrors = {
        "rss2_compat.xml": "rss2_compatibility_sample",
        "atom1_compat.xml": "atom1_compatibility_sample",
    }
    for filename, function in mirrors.items():
        if embedded_sample(function) == (SAMPLES / filename).read_text("utf-8"):
            print(f"PASS mirror {filename}")
        else:
            failures += 1
            print(f"FAIL mirror {filename}")
    real_mirrors = {
        "real_wptavern_rss.xml": "real_rss_sample",
        "real_wptavern_atom.xml": "real_atom_sample",
        "real_wptavern_json.json": "real_json_sample",
    }
    for filename, function in real_mirrors.items():
        if embedded_sample(function, "real_samples_test.mbt") == (
            SAMPLES / filename
        ).read_text("utf-8"):
            print(f"PASS mirror {filename}")
        else:
            failures += 1
            print(f"FAIL mirror {filename}")
    for filename, extractor in extractors.items():
        parsed = feedparser.parse((SAMPLES / filename).read_bytes())
        actual = extractor(parsed)
        if actual == expected[filename]:
            print(f"PASS {filename}")
        else:
            failures += 1
            print(f"FAIL {filename}")
            print("expected:", json.dumps(expected[filename], indent=2, sort_keys=True))
            print("actual:", json.dumps(actual, indent=2, sort_keys=True))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
