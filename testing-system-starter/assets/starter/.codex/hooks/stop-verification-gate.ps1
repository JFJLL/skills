$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$raw = [Console]::In.ReadToEnd()
$inputObject = if ($raw) { $raw | ConvertFrom-Json -Depth 50 } else { $null }
$cwd = if ($inputObject -and $inputObject.cwd) { [string]$inputObject.cwd } else { (Get-Location).Path }
$root = (& git -C $cwd rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $root) { exit 0 }
$root = [IO.Path]::GetFullPath(($root | Select-Object -First 1))

$policyPath = Join-Path $root "verification-policy.json"
$dirtyPath = Join-Path $root ".verification/dirty.json"
$verifierPath = Join-Path $root "scripts/verify-change.ps1"
if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) { exit 0 }
if (-not (Test-Path -LiteralPath $dirtyPath -PathType Leaf)) { exit 0 }

if (-not (Test-Path -LiteralPath $verifierPath -PathType Leaf)) {
    [ordered]@{
        continue = $false
        stopReason = "Verification runner is missing. Restore scripts/verify-change.ps1."
        systemMessage = "The repository verification gate is configured but its runner is missing."
    } | ConvertTo-Json -Compress
    exit 0
}

$checkOutput = @(& pwsh -NoProfile -File $verifierPath -CheckReceipt 2>&1)
$checkExit = $LASTEXITCODE
if ($checkExit -eq 0) {
    if (Test-Path -LiteralPath $dirtyPath) { Remove-Item -LiteralPath $dirtyPath -Force }
    exit 0
}

$detail = ($checkOutput | Select-Object -Last 1)
[ordered]@{
    continue = $false
    stopReason = "Verification receipt is missing or stale. Run `$verify-change, fix failures, and rerun verification."
    systemMessage = "Verification gate: $detail"
} | ConvertTo-Json -Compress
exit 0
