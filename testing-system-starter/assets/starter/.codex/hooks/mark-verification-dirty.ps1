$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$raw = [Console]::In.ReadToEnd()
$inputObject = if ($raw) { $raw | ConvertFrom-Json -Depth 50 } else { $null }
$cwd = if ($inputObject -and $inputObject.cwd) { [string]$inputObject.cwd } else { (Get-Location).Path }
$root = (& git -C $cwd rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $root) { exit 0 }
$root = [IO.Path]::GetFullPath(($root | Select-Object -First 1))
if (-not (Test-Path -LiteralPath (Join-Path $root "verification-policy.json") -PathType Leaf)) { exit 0 }

$directory = Join-Path $root ".verification"
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$state = [ordered]@{
    dirty = $true
    markedAt = (Get-Date).ToString("o")
    sessionId = if ($inputObject) { $inputObject.session_id } else { $null }
    turnId = if ($inputObject) { $inputObject.turn_id } else { $null }
    tool = if ($inputObject) { $inputObject.tool_name } else { $null }
}
[IO.File]::WriteAllText(
    (Join-Path $directory "dirty.json"),
    ($state | ConvertTo-Json -Depth 10),
    [Text.UTF8Encoding]::new($false)
)
exit 0
