"""Compare JSON Feed numeric byte counts with Python's exact decimal model."""

from __future__ import annotations

import json
import shutil
import subprocess
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "samples/jsonfeed11_numeric_attachment_sizes.json"
TEST = ROOT / "json_attachment_size_test.mbt"
MAX_EXACT = 9007199254740991


def main() -> None:
    lines = TEST.read_text("utf-8").splitlines()
    start = lines.index(
        'test "JSON Feed attachment sizes accept exact integer-valued JSON numbers" {'
    )
    mirrored = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            mirrored.append(stripped[2:])
        elif mirrored:
            break
    assert SAMPLE.read_text("utf-8") == "\n".join(mirrored) + "\n"

    original = json.loads(SAMPLE.read_text("utf-8"), parse_int=Decimal, parse_float=Decimal)
    declared = original["items"][0]["attachments"]
    expected = [
        int(number) if number >= 0 and number == number.to_integral_value()
        and number <= MAX_EXACT else None
        for number in (attachment["size_in_bytes"] for attachment in declared)
    ]
    assert expected == [1000, 42, 42, MAX_EXACT, 0, None, None, None, None]

    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    proc = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", str(SAMPLE)],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    result = json.loads(proc.stdout)
    assert [attachment["size_in_bytes"] for attachment in result["entries"][0]["attachments"]] == expected
    assert [problem["kind"]["message"] for problem in result["diagnostics"]] == [
        f"json feed item 0 attachment {index}: size_in_bytes" for index in range(5, 9)
    ]
    print("PASS JSON Feed numeric byte counts versus exact Decimal and CLI")


if __name__ == "__main__":
    main()
