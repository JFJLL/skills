[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$starterRoot = Split-Path -Parent $PSScriptRoot
$policySource = Join-Path $starterRoot "verification-policy.json"
$runnerSource = Join-Path $starterRoot "scripts\verify-change.ps1"
$passCount = 0
$failCount = 0
$failures = [Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Name, [string]$Detail)
    if ($Condition) {
        $script:passCount++
        Write-Host "PASS  $Name"
    }
    else {
        $script:failCount++
        $script:failures.Add($Name + " :: " + $Detail)
        Write-Host "FAIL  $Name :: $Detail"
    }
}

function New-Fixture {
    param([string]$Name)
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("verify-tests-" + $Name + "-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    git -C $dir init -q
    git -C $dir config user.email "test@test.local"
    git -C $dir config user.name "test"
    Copy-Item -LiteralPath $policySource -Destination (Join-Path $dir "verification-policy.json")
    New-Item -ItemType Directory -Path (Join-Path $dir "scripts") -Force | Out-Null
    Copy-Item -LiteralPath $runnerSource -Destination (Join-Path $dir "scripts\verify-change.ps1")
    New-Item -ItemType Directory -Path (Join-Path $dir "src\utils") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "frontend\components") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "src\auth") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "docs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "src\ai") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "src\db") -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir "src\utils\a.ts"), "export const a = 1;`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $dir "frontend\components\Button.tsx"), "export const Button = () => 'b';`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $dir "src\auth\session.ts"), "export const session = 1;`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $dir "docs\auth.md"), "# auth docs`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $dir "src\ai\prompt.ts"), "export const prompt = 1;`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $dir "src\db\migration.sql"), "SELECT 1;`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $dir "package.json"), @"
{
  "name": "verify-tests",
  "private": true,
  "scripts": {
    "test": "node -e \"console.log('unit ok')\"",
    "build": "node -e \"console.log('build ok')\"",
    "test:integration": "node -e \"console.log('integration ok')\"",
    "smoke": "node -e \"console.log('smoke ok')\"",
    "check": "node -e \"console.log('check ok')\"",
    "typecheck": "node -e \"console.log('typecheck ok')\"",
    "lint": "node -e \"console.log('lint ok')\""
  }
}
"@, [Text.UTF8Encoding]::new($false))
    git -C $dir add -A
    git -C $dir commit -q -m "baseline"
    git -C $dir branch -M main
    $remoteDir = $dir + "-remote.git"
    git init --bare -q $remoteDir
    git -C $dir remote add origin $remoteDir
    git -C $dir push -q -u origin main
    return $dir
}

function Get-PlanJson {
    param([string]$Dir, [string[]]$ExtraArgs)
    Push-Location $Dir
    $output = & pwsh -NoProfile -File (Join-Path $Dir "scripts\verify-change.ps1") -PlanOnly @ExtraArgs
    Pop-Location
    return ($output -join "`n") | ConvertFrom-Json
}

# --- T01: plain TS modification -> R1, static+unit ---
$d = New-Fixture "t01"
[IO.File]::WriteAllText((Join-Path $d "src\utils\a.ts"), "export const a = 2;`n", [Text.UTF8Encoding]::new($false))
$plan = Get-PlanJson $d
Assert-True ($plan.risk -eq "R1") "T01 risk R1" ($plan.risk)
Assert-True (($plan.requiredLanes.lane -join ",") -like "*static*" -and ($plan.requiredLanes.lane -join ",") -like "*unit*") "T01 lanes static+unit" (($plan.requiredLanes.lane -join ","))
Remove-Item -LiteralPath $d -Recurse -Force

# --- T02: UI tsx -> R2 + kimi-browser ---
$d = New-Fixture "t02"
[IO.File]::WriteAllText((Join-Path $d "frontend\components\Button.tsx"), "export const Button = () => 'changed';`n", [Text.UTF8Encoding]::new($false))
$plan = Get-PlanJson $d
Assert-True ($plan.risk -eq "R2") "T02 risk R2" ($plan.risk)
Assert-True (($plan.requiredLanes.lane -join ",") -like "*kimi-browser*") "T02 kimi-browser lane" (($plan.requiredLanes.lane -join ","))
Remove-Item -LiteralPath $d -Recurse -Force

# --- T03: auth modification -> R3 + integration + kimi + agent-review ---
$d = New-Fixture "t03"
[IO.File]::WriteAllText((Join-Path $d "src\auth\session.ts"), "export const session = 2;`n", [Text.UTF8Encoding]::new($false))
$plan = Get-PlanJson $d
Assert-True ($plan.risk -eq "R3") "T03 risk R3" ($plan.risk)
$lanes = $plan.requiredLanes.lane -join ","
Assert-True ($lanes -like "*kimi-browser*" -and $lanes -like "*agent-review*" -and $lanes -like "*integration*") "T03 R3 lanes" $lanes
Remove-Item -LiteralPath $d -Recurse -Force

# --- T04: deleted auth file -> R3 (deletion routed) ---
$d = New-Fixture "t04"
Remove-Item -LiteralPath (Join-Path $d "src\auth\session.ts") -Force
$plan = Get-PlanJson $d
Assert-True ($plan.risk -eq "R3") "T04 deleted auth risk R3" ($plan.risk)
Assert-True (($plan.files | Where-Object { $_.status -eq "deleted" -and $_.path -like "*session.ts" }).Count -ge 1) "T04 deletion detected" ($plan.files | ConvertTo-Json -Compress)
Remove-Item -LiteralPath $d -Recurse -Force

# --- T05: committed change + clean tree still detected ---
$d = New-Fixture "t05"
[IO.File]::WriteAllText((Join-Path $d "src\auth\session.ts"), "export const session = 3;`n", [Text.UTF8Encoding]::new($false))
git -C $d add -A
git -C $d commit -q -m "auth change"
$plan = Get-PlanJson $d
Assert-True ($plan.risk -eq "R3") "T05 committed auth risk R3" ($plan.risk)
Assert-True ($plan.changedFilesCount -ge 1) "T05 committed diff detected" ($plan.changedFilesCount)
Remove-Item -LiteralPath $d -Recurse -Force

# --- T07: docs/auth.md -> R0 (no false R3) ---
$d = New-Fixture "t07"
[IO.File]::WriteAllText((Join-Path $d "docs\auth.md"), "# changed docs`n", [Text.UTF8Encoding]::new($false))
$plan = Get-PlanJson $d
Assert-True ($plan.risk -eq "R0") "T07 docs risk R0" ($plan.risk)
Remove-Item -LiteralPath $d -Recurse -Force

# --- T08: ThemeProvider-like component -> UI not ai-eval ---
$d = New-Fixture "t08"
New-Item -ItemType Directory -Path (Join-Path $d "frontend\components") -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $d "frontend\components\ThemeProvider.tsx"), "export const ThemeProvider = () => 't';`n", [Text.UTF8Encoding]::new($false))
$plan = Get-PlanJson $d
$lanes = $plan.requiredLanes.lane -join ","
Assert-True ($lanes -notlike "*ai-eval*") "T08 ThemeProvider no ai-eval" $lanes
Assert-True ($lanes -like "*kimi-browser*") "T08 ThemeProvider is UI" $lanes
Remove-Item -LiteralPath $d -Recurse -Force

# --- T09: RiskFloor only escalates ---
$d = New-Fixture "t09"
[IO.File]::WriteAllText((Join-Path $d "src\utils\a.ts"), "export const a = 3;`n", [Text.UTF8Encoding]::new($false))
$plan = Get-PlanJson $d -ExtraArgs @("-RiskFloor", "R2")
Assert-True ($plan.risk -eq "R2") "T09 floor raises R1->R2" $plan.risk
[IO.File]::WriteAllText((Join-Path $d "src\auth\session.ts"), "export const session = 4;`n", [Text.UTF8Encoding]::new($false))
$plan = Get-PlanJson $d -ExtraArgs @("-RiskFloor", "R1")
Assert-True ($plan.risk -eq "R3") "T09 floor cannot lower R3" $plan.risk
Remove-Item -LiteralPath $d -Recurse -Force

# --- T15: no business diff -> receipt refused ---
$d = New-Fixture "t15"
[IO.File]::WriteAllText((Join-Path $d "src\utils\a.ts"), "export const a = 5;`n", [Text.UTF8Encoding]::new($false))
git -C $d add -A
git -C $d commit -q -m "all committed"
git -C $d push -q origin main
Push-Location $d
$output = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") 2>&1
$exit = $LASTEXITCODE
Pop-Location
Assert-True ($exit -eq 3) "T15 empty change set refuses receipt (exit 3)" ($exit)
Assert-True (-not (Test-Path -LiteralPath (Join-Path $d ".verification\receipt.json"))) "T15 no receipt written" ""
Remove-Item -LiteralPath $d -Recurse -Force

# --- T10/T11: evidence artifact deletion/modification makes receipt stale ---
$d = New-Fixture "t10"
[IO.File]::WriteAllText((Join-Path $d "frontend\components\Button.tsx"), "export const Button = () => 'ev';`n", [Text.UTF8Encoding]::new($false))
$plan = Get-PlanJson $d
$hash = $plan.changeSetHash
$evidenceDir = Join-Path $d ".verification"
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
$artifactDir = Join-Path $d "artifacts\verification"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
$artifact = Join-Path $artifactDir "kimi-browser-qa.md"
$qaContent = "# Kimi Browser QA`n`n- changeSetHash: $hash`n- Overall: pass`n" + ("x" * 400)
[IO.File]::WriteAllText($artifact, $qaContent, [Text.UTF8Encoding]::new($false))
$evidence = @{
    schemaVersion = 2
    changeSetHash = $hash
    lanes = @{
        "kimi-browser" = @{ status = "pass"; artifact = "artifacts/verification/kimi-browser-qa.md" }
    }
} | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText((Join-Path $evidenceDir "evidence.json"), $evidence, [Text.UTF8Encoding]::new($false))
Push-Location $d
$run = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") 2>&1
$runExit = $LASTEXITCODE
Pop-Location
Assert-True ($runExit -eq 0) "T10 base verification passes" ($runExit)
Push-Location $d
$check1 = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") -CheckReceipt 2>&1
Pop-Location
Assert-True ($LASTEXITCODE -eq 0) "T10 receipt current after pass" ($LASTEXITCODE)
Remove-Item -LiteralPath $artifact -Force
Push-Location $d
$check2 = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") -CheckReceipt 2>&1
Pop-Location
Assert-True ($LASTEXITCODE -eq 2) "T10 deleted artifact -> stale" ($LASTEXITCODE)
[IO.File]::WriteAllText($artifact, $qaContent, [Text.UTF8Encoding]::new($false))
Push-Location $d
$check3 = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") -CheckReceipt 2>&1
Pop-Location
Assert-True ($LASTEXITCODE -eq 0) "T10 restore artifact -> current" ($LASTEXITCODE)
[IO.File]::WriteAllText($artifact, ($qaContent + "tampered"), [Text.UTF8Encoding]::new($false))
Push-Location $d
$check4 = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") -CheckReceipt 2>&1
Pop-Location
Assert-True ($LASTEXITCODE -eq 2) "T11 modified artifact -> stale" ($LASTEXITCODE)
Remove-Item -LiteralPath $d -Recurse -Force

# --- T12: policy modified without version bump -> stale ---
$d = New-Fixture "t12"
[IO.File]::WriteAllText((Join-Path $d "src\utils\a.ts"), "export const a = 6;`n", [Text.UTF8Encoding]::new($false))
Push-Location $d
$run = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") 2>&1
$runExit = $LASTEXITCODE
Pop-Location
Assert-True ($runExit -eq 0) "T12 base pass" ($runExit)
$policyPath = Join-Path $d "verification-policy.json"
$content = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8
$content = $content -replace '"defaultRisk": "R1"', '"defaultRisk": "R2"'
[IO.File]::WriteAllText($policyPath, $content, [Text.UTF8Encoding]::new($false))
Push-Location $d
$check = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") -CheckReceipt 2>&1
Pop-Location
Assert-True ($LASTEXITCODE -eq 2) "T12 policy hash change -> stale" ($LASTEXITCODE)
Remove-Item -LiteralPath $d -Recurse -Force

# --- T13: runner modified -> stale ---
$d = New-Fixture "t13"
[IO.File]::WriteAllText((Join-Path $d "src\utils\a.ts"), "export const a = 7;`n", [Text.UTF8Encoding]::new($false))
Push-Location $d
$run = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") 2>&1
Pop-Location
$runnerPath = Join-Path $d "scripts\verify-change.ps1"
[IO.File]::AppendAllText($runnerPath, "`n# tampered`n", [Text.UTF8Encoding]::new($false))
Push-Location $d
$check = & pwsh -NoProfile -File $runnerPath -CheckReceipt 2>&1
Pop-Location
Assert-True ($LASTEXITCODE -eq 2) "T13 runner hash change -> stale" ($LASTEXITCODE)
Remove-Item -LiteralPath $d -Recurse -Force

# --- T16: rename critical file -> old and new both route ---
$d = New-Fixture "t16"
New-Item -ItemType Directory -Path (Join-Path $d "src\security") -Force | Out-Null
git -C $d mv "src/auth/session.ts" "src/security/session.ts"
$plan = Get-PlanJson $d
Assert-True ($plan.risk -eq "R3") "T16 renamed auth file risk R3" $plan.risk
$hasRename = $false
foreach ($f in $plan.files) { if ($f.status -eq "renamed") { $hasRename = $true } }
Assert-True $hasRename "T16 rename detected in plan" ($plan.files | ConvertTo-Json -Compress)
Remove-Item -LiteralPath $d -Recurse -Force

# --- T17: monorepo cwd command runs (frontend package only) ---
$d = New-Fixture "t17"
New-Item -ItemType Directory -Path (Join-Path $d "frontend") -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $d "frontend\package.json"), @"
{
  "name": "frontend",
  "scripts": { "test": "node -e \"console.log('fe ok')\"" }
}
"@, [Text.UTF8Encoding]::new($false))
$policy = Get-Content -LiteralPath (Join-Path $d "verification-policy.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$policy.lanes.unit.commands[0] = @{ id = "unit"; program = "npm.cmd"; args = @("run", "test"); npmScript = "test"; required = $false; cwd = "frontend" }
[IO.File]::WriteAllText((Join-Path $d "verification-policy.json"), ($policy | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $d "src\utils\a.ts"), "export const a = 8;`n", [Text.UTF8Encoding]::new($false))
Push-Location $d
$run = & pwsh -NoProfile -File (Join-Path $d "scripts\verify-change.ps1") 2>&1
$runExit = $LASTEXITCODE
Pop-Location
Assert-True ($runExit -eq 0) "T17 cwd command runs" ($runExit)
Remove-Item -LiteralPath $d -Recurse -Force

Write-Host ""
Write-Host ("Results: " + $passCount + " passed, " + $failCount + " failed")
if ($failCount -gt 0) {
    Write-Host "Failures:"
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}
exit 0
