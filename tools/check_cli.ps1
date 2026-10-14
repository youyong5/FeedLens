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
Write-Output "PASS help exit=$($help.ExitCode)"
Write-Output "PASS fatal parse/read/argument errors exit=$($parseError.ExitCode)/$($readError.ExitCode)/$($argumentError.ExitCode)"
