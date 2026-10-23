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

$rssSkip = Invoke-FeedLensCli @("--json", "samples/rss2_skip_schedule.xml")
if ($rssSkip.ExitCode -ne 0 -or $rssSkip.StandardError) {
  throw "RSS skip hints JSON CLI scenario failed"
}
$rssSkipModel = $rssSkip.StandardOutput | ConvertFrom-Json
if (($rssSkipModel.skip_hours -join ",") -ne "0,23" -or ($rssSkipModel.skip_days -join ",") -ne "Sunday,Monday" -or $rssSkipModel.diagnostics.Count -ne 0) {
  throw "RSS skip hints JSON lost ordered GMT hours or weekdays"
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
if ($realRss.ExitCode -ne 0 -or $realRss.StandardError -or -not $realRss.StandardOutput.Contains("Entries: 2") -or -not $realRss.StandardOutput.Contains("Language: en-US") -or -not $realRss.StandardOutput.Contains("rss_image: https://wptavern.com/wp-content/uploads/2021/12/cropped-tavern-favicon-32x32.png") -or -not $realRss.StandardOutput.Contains("size (bytes): 37878054")) {
  throw "Real RSS projection CLI scenario failed"
}

$realAtom = Invoke-FeedLensCli @("--json", "samples/real_wptavern_atom.xml")
if ($realAtom.ExitCode -ne 0 -or $realAtom.StandardError) {
  throw "Real Atom projection CLI scenario failed"
}
$realAtomModel = $realAtom.StandardOutput | ConvertFrom-Json
if ($realAtomModel.format -ne "atom1" -or $realAtomModel.language -ne "en-US" -or $realAtomModel.images[0].role -ne "atom_icon" -or $realAtomModel.entries.Count -ne 2 -or $realAtomModel.entries[0].attachments[0].size_in_bytes -ne 37878054 -or $realAtomModel.entries[1].attachments[0].size_in_bytes -ne 39694700) {
  throw "Real Atom projection JSON output was not the expected normalized model"
}

$realJson = Invoke-FeedLensCli @("--json", "samples/real_wptavern_json.json")
if ($realJson.ExitCode -ne 0 -or $realJson.StandardError) {
  throw "Real JSON Feed projection CLI scenario failed"
}
$realJsonModel = $realJson.StandardOutput | ConvertFrom-Json
if ($realJsonModel.format -ne "jsonfeed1" -or $realJsonModel.language -ne "en-US" -or $realJsonModel.images[0].role -ne "json_icon" -or $realJsonModel.entries.Count -ne 2 -or $realJsonModel.entries[0].images[0].role -ne "json_featured" -or $realJsonModel.entries[0].published_at -ne "2026-10-14T14:00:00+01:00" -or $realJsonModel.entries[0].attachments[0].size_in_bytes -ne 37878054) {
  throw "Real JSON Feed projection JSON output was not the expected normalized model"
}

$display = Invoke-FeedLensCli @("--json", "samples/jsonfeed11_display.json")
if ($display.ExitCode -ne 0 -or $display.StandardError) {
  throw "Display-metadata JSON CLI scenario failed"
}
$displayModel = $display.StandardOutput | ConvertFrom-Json
if ($displayModel.images.Count -ne 2 -or $displayModel.images[1].role -ne "json_favicon" -or $displayModel.entries[0].link -ne "posts/one" -or $displayModel.entries[0].external_url -ne "https://outside.test/story" -or $displayModel.entries[0].language -ne "fr" -or $displayModel.entries[0].images[0].role -ne "json_featured" -or $displayModel.entries[0].images[1].role -ne "json_banner" -or $displayModel.entries[0].attachments.Count -ne 0) {
  throw "Display-metadata CLI output mixed distinct reader fields"
}

$xhtml = Invoke-FeedLensCli @("--json", "samples/atom1_xhtml.xml")
if ($xhtml.ExitCode -ne 0 -or $xhtml.StandardError) {
  throw "Atom XHTML CLI scenario failed"
}
$xhtmlModel = $xhtml.StandardOutput | ConvertFrom-Json
if ($xhtmlModel.title -ne "Plan A & B" -or $xhtmlModel.title_kind -ne "xhtml" -or -not $xhtmlModel.title_xhtml.markup.Contains("<h:em xmlns:h=") -or $xhtmlModel.entries[0].title -ne "Race review" -or $xhtmlModel.entries[0].content_kind -ne "xhtml" -or -not $xhtmlModel.entries[0].content_xhtml.markup.Contains("<h:strong xmlns:h=")) {
  throw "Atom XHTML CLI JSON lost text, kind, or namespaced markup"
}

$contentForms = Invoke-FeedLensCli @("--json", "samples/atom1_content_forms.xml")
if ($contentForms.ExitCode -ne 0 -or $contentForms.StandardError) {
  throw "Atom content forms CLI scenario failed"
}
$contentModel = $contentForms.StandardOutput | ConvertFrom-Json
if ($contentModel.entries.Count -ne 4 -or $contentModel.entries[0].atom_body.kind -ne "external" -or $contentModel.entries[0].atom_body.src -ne "entry.xml" -or $contentModel.entries[0].atom_body.media_type -ne "application/xml" -or $contentModel.entries[1].atom_body.kind -ne "inline_text" -or $contentModel.entries[1].atom_body.media_type -ne "TEXT/MARKDOWN" -or $contentModel.entries[2].atom_body.kind -ne "inline_xml" -or -not $contentModel.entries[2].atom_body.markup.Contains("<n0:root") -or $contentModel.entries[3].atom_body.kind -ne "inline_binary" -or $contentModel.entries[3].atom_body.base64 -ne "AQID/w==" -or $contentModel.entries[3].atom_body.byte_length -ne 4) {
  throw "Atom content forms CLI JSON lost a content variant"
}
$contentHuman = Invoke-FeedLensCli @("samples/atom1_content_forms.xml")
if ($contentHuman.ExitCode -ne 0 -or $contentHuman.StandardError -or -not $contentHuman.StandardOutput.Contains("Atom content: external (not fetched); src: entry.xml") -or -not $contentHuman.StandardOutput.Contains("Atom content: binary; media type: IMAGE/PNG; bytes: 4")) {
  throw "Atom content forms human summary lost external or binary metadata"
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
Write-Output "PASS RSS skip hints JSON exit=$($rssSkip.ExitCode), ordered values verified"
Write-Output "PASS Atom attachment JSON exit=$($atomAttachments.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS JSON Feed attachment JSON exit=$($jsonAttachments.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS real RSS projection exit=$($realRss.ExitCode)"
Write-Output "PASS real Atom projection JSON exit=$($realAtom.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS real JSON Feed projection JSON exit=$($realJson.ExitCode), ConvertFrom-Json accepted output"
Write-Output "PASS display-metadata JSON exit=$($display.ExitCode), distinct roles and links verified"
Write-Output "PASS Atom XHTML JSON exit=$($xhtml.ExitCode), ConvertFrom-Json accepted text and fragments"
Write-Output "PASS Atom content forms JSON exit=$($contentForms.ExitCode), external/text/XML/Base64 variants verified"
Write-Output "PASS Atom content forms human exit=$($contentHuman.ExitCode), external and binary summaries verified"
Write-Output "PASS help exit=$($help.ExitCode)"
Write-Output "PASS fatal parse/read/argument errors exit=$($parseError.ExitCode)/$($readError.ExitCode)/$($argumentError.ExitCode)"
