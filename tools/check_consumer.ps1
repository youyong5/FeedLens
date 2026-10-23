$ErrorActionPreference = "Stop"
$feedlensRoot = Split-Path -Parent $PSScriptRoot
$output = & moon -C $feedlensRoot run --target native examples/consumer
if ($LASTEXITCODE -ne 0) {
  throw "Library consumer example exited with $LASTEXITCODE"
}
$text = $output -join "`n"
foreach ($expected in @(
  "feed=Reader sample",
  "language=en-US",
  "icon=https://example.test/icons/feed.png",
  "permalink=https://example.test/posts/one",
  "outside=https://example.test/elsewhere/story",
  "featured=https://example.test/images/preview.png",
  "published=2026-10-19T08:30:00Z",
  "xhtml_title=Plan A",
  "xhtml_markup=Plan <h:em",
  "atom_binary_type=application/octet-stream",
  "atom_binary_bytes=3",
  "rss_docs=https://example.test/rss-spec.html",
  "rss_cloud=notify.example.test:80",
  "rss_search=https://example.test/search"
)) {
  if (-not $text.Contains($expected)) {
    throw "Library consumer output missing: $expected"
  }
}
Write-Output "PASS independent library consumer, exit=0, public API fields verified"
