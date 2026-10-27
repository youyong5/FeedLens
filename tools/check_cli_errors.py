"""Check native CLI failures as a separate process, including UTF-8 stderr."""

import subprocess


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["moon", "run", "--target", "native", "cmd/main", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )


for arguments, expected in [
    (("--json", "samples/invalid_rss.xml"), "invalid XML at"),
    (("未找到-🚀.xml",), "could not read '未找到-🚀.xml'"),
    ((), "missing input file path"),
]:
    result = run(*arguments)
    assert result.returncode == 2, (arguments, result)
    assert not result.stdout, (arguments, result.stdout)
    diagnostic = result.stderr.splitlines()[-1]
    assert diagnostic.startswith("feedlens: "), (arguments, result.stderr)
    assert expected in diagnostic, (arguments, result.stderr)

print("PASS native CLI errors and UTF-8 stderr")
