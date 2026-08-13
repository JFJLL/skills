[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot
$captureScript = Join-Path $skillRoot "scripts\capture_product_pages.ps1"
$exampleManifest = Join-Path $skillRoot "references\capture-manifest.example.json"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "summarize-product-usage-capture-test"
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

function Invoke-CaptureProcess {
    param([string[]]$Arguments)
    & pwsh -NoProfile -File $captureScript @Arguments 2>&1
    return $LASTEXITCODE
}

Write-Output "1/3 Validate the checked-in example manifest"
$output = & pwsh -NoProfile -File $captureScript -Manifest $exampleManifest -ValidateOnly 2>&1
if ($LASTEXITCODE -ne 0 -or ($output -join "`n") -notmatch "VALID:") {
    throw "Expected example manifest validation to pass. Output: $($output -join "`n")"
}

Write-Output "2/3 Dry-run without locating or starting a browser"
$dryRunOutput = & pwsh -NoProfile -File $captureScript -Manifest $exampleManifest -DryRun -OutputRoot (Join-Path $testRoot "captures") 2>&1
if ($LASTEXITCODE -ne 0 -or ($dryRunOutput -join "`n") -notmatch "browser was not started") {
    throw "Expected dry-run to pass without a browser. Output: $($dryRunOutput -join "`n")"
}

Write-Output "3/3 Reject an unsafe/incomplete manifest"
$invalidManifest = Join-Path $testRoot "invalid-manifest.json"
[IO.File]::WriteAllText(
    $invalidManifest,
    '{"schema_version":1,"source_revision":"","base_url":"not-a-url","roles":[]}',
    [Text.UTF8Encoding]::new($false)
)
$invalidOutput = & pwsh -NoProfile -File $captureScript -Manifest $invalidManifest -ValidateOnly 2>&1
if ($LASTEXITCODE -eq 0 -or ($invalidOutput -join "`n") -notmatch "Manifest validation failed") {
    throw "Expected invalid manifest validation to fail. Output: $($invalidOutput -join "`n")"
}

$unsafeWindowsPath = Get-Content -LiteralPath $exampleManifest -Raw | ConvertFrom-Json
$unsafeWindowsPath.roles[0].pages[0].file = "C:outside.png"
$unsafePathFile = Join-Path $testRoot "unsafe-windows-path.json"
[IO.File]::WriteAllText(
    $unsafePathFile,
    ($unsafeWindowsPath | ConvertTo-Json -Depth 20),
    [Text.UTF8Encoding]::new($false)
)
$unsafeOutput = & pwsh -NoProfile -File $captureScript -Manifest $unsafePathFile -ValidateOnly 2>&1
if ($LASTEXITCODE -eq 0 -or ($unsafeOutput -join "`n") -notmatch "safe relative path") {
    throw "Expected Windows drive-relative screenshot path validation to fail. Output: $($unsafeOutput -join "`n")"
}

$duplicateWindowsPath = Get-Content -LiteralPath $exampleManifest -Raw | ConvertFrom-Json
$copy = $duplicateWindowsPath.roles[0].pages[0] | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$copy.name = "duplicate-case"
$duplicateWindowsPath.roles[0].pages[0].file = "Shot.png"
$copy.file = "shot.PNG"
$duplicateWindowsPath.roles[0].pages = @($duplicateWindowsPath.roles[0].pages[0], $copy)
$duplicatePathFile = Join-Path $testRoot "duplicate-windows-path.json"
[IO.File]::WriteAllText(
    $duplicatePathFile,
    ($duplicateWindowsPath | ConvertTo-Json -Depth 20),
    [Text.UTF8Encoding]::new($false)
)
$duplicateOutput = & pwsh -NoProfile -File $captureScript -Manifest $duplicatePathFile -ValidateOnly 2>&1
if ($LASTEXITCODE -eq 0 -or ($duplicateOutput -join "`n") -notmatch "duplicated on Windows") {
    throw "Expected Windows-equivalent duplicate screenshot paths to fail. Output: $($duplicateOutput -join "`n")"
}

Write-Output "PASS: capture manifest validation and browser-free dry-run behave correctly"
