"""Compare JSON Feed item date recovery with Python JSON and calendar parsing."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "jsonfeed11_invalid_dates.json"


def mirror(lines: list[str], name: str) -> str:
    start = lines.index(f'test "{name}" {{')
    result: list[str] = []
    for line in lines[start + 1 :]:
        stripped = line.lstrip()
        if stripped.startswith("#|"):
            result.append(stripped[2:])
        elif result:
            break
    return "\n".join(result) + "\n"


def valid_date(value: str) -> bool:
    # The chosen fixture has no leap seconds; Python cannot represent them.
    if not re.fullmatch(
        r"\d{4}-\d\d-\d\d[Tt]\d\d:\d\d:\d\d(?:\.\d+)?(?:[Zz]|[+-]\d\d:\d\d)",
        value,
    ):
        return False
    try:
        datetime.fromisoformat(value.replace("t", "T").replace("Z", "+00:00").replace("z", "+00:00"))
    except ValueError:
        return False
    return True


def main() -> None:
    fixture = (ROOT / "samples" / NAME).read_text("utf-8")
    lines = (ROOT / "json_date_validation_test.mbt").read_text("utf-8").splitlines()
    assert fixture == mirror(lines, "JSON Feed retains items and raw dates while diagnosing invalid RFC 3339")
    legacy_name = "jsonfeed10_invalid_dates.json"
    legacy = (ROOT / "samples" / legacy_name).read_text("utf-8")
    assert legacy == mirror(lines, "JSON Feed 1.0 also diagnoses malformed item dates without dropping items")

    source = json.loads(fixture)
    assert source["version"] == "https://jsonfeed.org/version/1.1"
    fields = ("date_published", "date_modified")
    expected = [
        (index, field)
        for index, item in enumerate(source["items"])
        for field in fields
        if isinstance(item.get(field), str) and not valid_date(item[field])
    ]
    assert expected == [(0, "date_published"), (1, "date_modified"), (2, "date_published")]
    moon = shutil.which("moon") or str(Path.home() / ".moon/bin/moon")
    proc = subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", f"samples/{NAME}"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    result = json.loads(proc.stdout)
    assert [entry["identifier"] for entry in result["entries"]] == [item["id"] for item in source["items"]]
    assert [
        (entry["published_at"], entry["updated_at"])
        for entry in result["entries"]
    ] == [
        (item.get("date_published"), item.get("date_modified") if isinstance(item.get("date_modified"), str) else None)
        for item in source["items"]
    ]
    assert [
        (d["kind"]["index"], d["kind"]["field"])
        for d in result["diagnostics"] if d["kind"]["type"] == "InvalidJsonFeedDate"
    ] == expected
    assert [d["kind"] for d in result["diagnostics"] if d["kind"]["type"] == "InvalidJsonFeedItem"] == [
        {"type": "InvalidJsonFeedItem", "index": 2, "field": "date_modified"}
    ]
    legacy_source = json.loads(legacy)
    assert legacy_source["version"] == "https://jsonfeed.org/version/1"
    assert not valid_date(legacy_source["items"][0]["date_published"])
    legacy_result = json.loads(subprocess.run(
        [moon, "run", "--target", "native", "cmd/main", "--json", f"samples/{legacy_name}"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout)
    assert [entry["identifier"] for entry in legacy_result["entries"]] == ["one", "two"]
    assert legacy_result["entries"][0]["published_at"] == legacy_source["items"][0]["date_published"]
    assert legacy_result["diagnostics"] == [
        {"kind": {"type": "InvalidJsonFeedDate", "index": 0, "field": "date_published"}, "line": 1, "column": 1}
    ]
    print("PASS mirrored JSON Feed 1.0/1.1 date recovery vs Python JSON and calendar parsing")


if __name__ == "__main__":
    main()
