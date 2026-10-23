"""Compare a byte-mirrored recovery case to Python's JSON and URL libraries.

This checks only declared values, retained attachment order and URL joining.
Python's stdlib is not an independent JSON Feed conformance validator.
"""

import json
import shutil
import subprocess
from pathlib import Path
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/jsonfeed11_attachment_recovery.json"
SOURCE_URL = "https://example.test/feeds/current.json"


def run_cli(*extra: str) -> dict:
    result = subprocess.run(
        [shutil.which("moon") or str(Path.home() / ".moon/bin/moon"), "run", "--target", "native", "cmd/main", "--json", *extra, f"samples/{SAMPLE.name}"],
        cwd=ROOT, text=True, capture_output=True, check=True,
    )
    return json.loads(result.stdout)


def main() -> None:
    sample = SAMPLE.read_text("utf-8")
    lines = (ROOT / "attachments_test.mbt").read_text("utf-8").splitlines()
    start = lines.index('test "JSON Feed 1.1 retains ordered attachments with missing MIME and resolves URLs" {')
    mirrored = next(line.lstrip()[2:] for line in lines[start + 1:] if line.lstrip().startswith("#|")) + "\n"
    assert mirrored == sample
    source = json.loads(sample)
    raw = source["items"][0]["attachments"]
    retained = [(i, a) for i, a in enumerate(raw) if isinstance(a.get("url"), str) and a["url"].strip()]
    model = run_cli()
    assert [a["url"] for a in model["entries"][0]["attachments"]] == [a["url"] for _, a in retained]
    assert [a["media_type"] for a in model["entries"][0]["attachments"]] == [a.get("mime_type") if isinstance(a.get("mime_type"), str) and a["mime_type"].strip() else None for _, a in retained]
    for actual, (_, declared) in zip(model["entries"][0]["attachments"], retained):
        assert actual["title"] == declared.get("title")
        assert actual["size_in_bytes"] == declared.get("size_in_bytes")
        assert actual["duration_in_seconds"] == declared.get("duration_in_seconds")
    assert [d["kind"] for d in model["diagnostics"]] == [
        {"type": "InvalidAttachment", "message": f"json feed item 0 attachment {i}: mime_type"}
        for i, a in retained if not isinstance(a.get("mime_type"), str) or not a["mime_type"].strip()
    ] + [{"type": "InvalidAttachment", "message": "json feed item 0 attachment 4: url"}]
    assert all(d["line"] == d["column"] == 1 for d in model["diagnostics"])
    # Library parse_with_source tests use the same sample. Here the stdlib
    # computes expected URLs independently of the library's resolver.
    assert [urljoin(SOURCE_URL, a["url"]) for _, a in retained] == [
        "https://example.test/audio/one.mp3", "https://example.test/audio/two.mp3",
        "https://example.test/audio/three.mp3", "https://example.test/feeds/current.json?download=4",
    ]
    print("PASS JSON Feed 1.1 attachment recovery vs stdlib JSON and URL joins")


if __name__ == "__main__":
    main()
