$ErrorActionPreference = "Stop"
$feedlensRoot = Split-Path -Parent $PSScriptRoot

function Invoke-FeedLensCli {
  param([string[]]$Arguments)

  $feedlensStdout = [System.IO.Path]::GetTempFileName()
  $feedlensStderr = [System.IO.Path]::GetTempFileName()
  try {
    $feedlensPreviousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & moon -C $feedlensRoot run --target native cmd/main @Arguments 1> $feedlensStdout 2> $feedlensStderr
    $feedlensExitCode = $LASTEXITCODE
    $ErrorActionPreference = $feedlensPreviousErrorAction
    [pscustomobject]@{
      ExitCode = $feedlensExitCode
      StandardOutput = Get-Content -LiteralPath $feedlensStdout -Raw
      StandardError = Get-Content -LiteralPath $feedlensStderr -Raw
    }
  } finally {
    Remove-Item -LiteralPath $feedlensStdout, $feedlensStderr -Force
  }
}

$rss = Invoke-FeedLensCli @("samples/rss2_compat.xml")
if ($rss.ExitCode -ne 0 -or -not $rss.StandardOutput.Contains("Format: RSS 2.0") -or $rss.StandardError) {
  throw "RSS CLI scenario failed"
}

$atom = Invoke-FeedLensCli @("samples/atom1_compat.xml")
if ($atom.ExitCode -ne 0 -or -not $atom.StandardOutput.Contains("Format: Atom 1.0") -or $atom.StandardError) {
  throw "Atom CLI scenario failed"
}

$json = Invoke-FeedLensCli @("--json", "samples/jsonfeed11_compat.json")
if ($json.ExitCode -ne 0 -or $json.StandardError) {
  throw "JSON CLI scenario failed"
}
$model = $json.StandardOutput | ConvertFrom-Json
if ($model.format -ne "jsonfeed1" -or $model.entries.Count -ne 2 -or $model.entries[1].identifier -ne "2") {
  throw "JSON CLI output was not the expected normalized model"
}

$rssAttachments = Invoke-FeedLensCli @("samples/rss2_attachments.xml")
if ($rssAttachments.ExitCode -ne 0 -or $rssAttachments.StandardError -or -not $rssAttachments.StandardOutput.Contains("attachments: 2") -or -not $rssAttachments.StandardOutput.Contains("https://example.test/audio/one.mp3")) {
  throw "RSS attachment summary CLI scenario failed"
}

$atomAttachments = Invoke-FeedLensCli @("--json", "samples/atom1_attachments.xml")
if ($atomAttachments.ExitCode -ne 0 -or $atomAttachments.StandardError) {
  throw "Atom attachment JSON CLI scenario failed"
}
$atomModel = $atomAttachments.StandardOutput | ConvertFrom-Json
if ($atomModel.format -ne "atom1" -or $atomModel.entries[0].link -ne "https://example.test/articles/one" -or $atomModel.entries[0].attachments.Count -ne 2 -or $atomModel.entries[0].attachments[0].source -ne "atom1" -or $atomModel.entries[0].attachments[0].size_in_bytes -ne 42 -or $null -ne $atomModel.entries[0].attachments[1].media_type) {
  throw "Atom attachment JSON was not the expected normalized model"
}

$jsonAttachments = Invoke-FeedLensCli @("--json", "samples/jsonfeed11_attachments.json")
if ($jsonAttachments.ExitCode -ne 0 -or $jsonAttachments.StandardError) {
  throw "JSON Feed attachment CLI scenario failed"
}
$jsonAttachmentModel = $jsonAttachments.StandardOutput | ConvertFrom-Json
if ($jsonAttachmentModel.format -ne "jsonfeed1" -or $jsonAttachmentModel.entries[0].attachments.Count -ne 2 -or $jsonAttachmentModel.entries[0].attachments[0].duration_in_seconds -ne 12.5 -or $jsonAttachmentModel.entries[0].attachments[1].url -ne "https://example.test/audio/two.ogg") {
  throw "JSON Feed attachment JSON was not the expected normalized model"
}

$realRss = Invoke-FeedLensCli @("samples/real_wptavern_rss.xml")
if ($realRss.ExitCode -ne 0 -or $realRss.StandardError -or -not $realRss.StandardOutput.Contains("Entries: 2") -or -not $realRss.StandardOutput.Contains("size (bytes): 37878054")) {
  throw "Real RSS projection CLI scenario failed"
}

$realAtom = Invoke-FeedLensCli @("--json", "samples/real_wptavern_atom.xml")
if ($realAtom.ExitCode -ne 0 -or $realAtom.StandardError) {
  throw "Real Atom projection CLI scenario failed"
}
$realAtomModel = $realAtom.StandardOutput | ConvertFrom-Json
if ($realAtomModel.format -ne "atom1" -or $realAtomModel.entries.Count -ne 2 -or $realAtomModel.entries[0].attachments[0].size_in_bytes -ne 37878054 -or $realAtomModel.entries[1].attachments[0].size_in_bytes -ne 39694700) {
  throw "Real Atom projection JSON output was not the expected normalized model"
}

$realJson = Invoke-FeedLensCli @("--json", "samples/real_wptavern_json.json")
if ($realJson.ExitCode -ne 0 -or $realJson.StandardError) {
  throw "Real JSON Feed projection CLI scenario failed"
}
$realJsonModel = $realJson.StandardOutput | ConvertFrom-Json
if ($realJsonModel.format -ne "jsonfeed1" -or $realJsonModel.entries.Count -ne 2 -or $realJsonModel.entries[0].published_at -ne "2026-10-14T14:00:00+01:00" -or $realJsonModel.entries[0].attachments[0].size_in_bytes -ne 37878054) {
  throw "Real JSON Feed projection JSON output was not the expected normalized model"
}

$help = Invoke-FeedLensCli @("--", "--help")
if ($help.ExitCode -ne 0 -or -not $help.StandardOutput.Contains("Usage: feedlens") -or $help.StandardError) {
  throw "Help CLI scenario failed"
}

$parseError = Invoke-FeedLensCli @("--json", "samples/invalid_rss.xml")
if ($parseError.ExitCode -eq 0 -or $parseError.StandardOutput -or -not $parseError.StandardError.Contains("could not parse")) {
  throw "Fatal parse-error CLI scenario failed"
}

$readError = Invoke-FeedLensCli @("missing-feed.xml")
if ($readError.ExitCode -eq 0 -or $readError.StandardOutput -or -not $readError.StandardError.Contains("could not read")) {
  throw "File-read-error CLI scenario failed"
}

$argumentError = Invoke-FeedLensCli @()
if ($argumentError.ExitCode -eq 0 -or $argumentError.StandardOutput -or -not $argumentError.StandardError.Contains("missing input file path")) {
  throw "Argument-error CLI scenario failed"
}

Write-Output "PASS RSS exit=$($rss.ExitCode)"
Write-Output "PASS Atom exit=$($atom.ExitCode)"
Write-Output "PASS JSON exit=$($json.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS RSS attachment summary exit=$($rssAttachments.ExitCode)"
Write-Output "PASS Atom attachment JSON exit=$($atomAttachments.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS JSON Feed attachment JSON exit=$($jsonAttachments.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS real RSS projection exit=$($realRss.ExitCode)"
Write-Output "PASS real Atom projection JSON exit=$($realAtom.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS real JSON Feed projection JSON exit=$($realJson.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS help exit=$($help.ExitCode)"
Write-Output "PASS fatal parse/read/argument errors exit=$($parseError.ExitCode)/$($readError.ExitCode)/$($argumentError.ExitCode)"
