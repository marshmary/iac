<#
.SYNOPSIS
  PowerShell companion of tests/run-all.sh — the no-cloud test pyramid (docs/testing.md).

.DESCRIPTION
  Runs T0 (init + golden manifest + token sweep, plus the pin-consistency
  gate) for every tier x provider, then T1 (fmt-check, task --list) and T2
  (init -backend=false + validate) for EVERY engine installed on PATH —
  tofu and terraform are probed independently, mirroring the bash runner's
  dual-engine loop.

  Still bash-runner territory (tests/run-all.sh / tests/run-in-docker.sh):
  T1 tflint and the terragrunt hcl checks, T2 on terragrunt units (they go
  through `terragrunt`), and all of T3-T6. This companion keeps the
  structural gate available in a pure-Windows shell.
#>
[CmdletBinding()]
param(
  [string[]]$Tiers = @('01', '02', '03', '04')
)

$ErrorActionPreference = 'Continue'
# bash callers pass "01,04" as one arg -> split every element
$Tiers = @($Tiers | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() })
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Scratch = Join-Path $RepoRoot 'tests/scratch'
$Manifests = Join-Path $RepoRoot 'tests/manifests'
$script:Pass = 0; $script:Fail = 0; $script:Skip = 0

function Result([string]$status, [string]$label, [string]$detail) {
  switch ($status) {
    'PASS' { $script:Pass++; Write-Host "PASS  $label $detail" }
    'FAIL' { $script:Fail++; Write-Host "FAIL  $label $detail" -ForegroundColor Red }
    'SKIP' { $script:Skip++; Write-Host "SKIP  $label $detail" -ForegroundColor DarkGray }
  }
}

# every installed engine gets its own T1/T2 pass, like the bash runner
$engines = @()
foreach ($cand in 'tofu', 'terraform') {
  if (Get-Command $cand -ErrorAction SilentlyContinue) { $engines += $cand }
}
$haveTask = [bool](Get-Command task -ErrorAction SilentlyContinue)

# T0-level pin consistency: version files vs runner ARGs vs docs
& (Join-Path $RepoRoot 'tests/check-pins.ps1') *> $null
if ($LASTEXITCODE -eq 0) { Result PASS 'T0/pins' 'version files = runner ARGs = engine-duality docs' }
else { Result FAIL 'T0/pins' 'pin drift (run tests/check-pins.ps1 for details)' }

foreach ($tier in $Tiers) {
  $provs = if ($tier -eq '04') { @('all') } else { @('aws', 'azure', 'gcp') }
  foreach ($prov in $provs) {
    $label = "$tier-$prov"
    $dest = Join-Path $Scratch $label
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }

    # tier 04 keeps all platforms — pass empty Provider (init assigns 'all')
    $provArg = if ($prov -eq 'all') { '' } else { $prov }
    & (Join-Path $RepoRoot 'scripts/init-project.ps1') -Tier $tier -Provider $provArg -Name demo-app -Dest $dest -NoGit *> $null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dest)) {
      Result FAIL "T0/$label" 'init-project failed'
      continue
    }
    Result PASS "T0/$label" 'init + token sweep (enforced by init script)'

    $manifest = Join-Path $Manifests "$label.txt"
    if (Test-Path $manifest) {
      # normalize to the bash runner's "./forward/slash" manifest format
      $actual = Get-ChildItem $dest -File -Recurse | ForEach-Object { ('./' + $_.FullName.Substring($dest.Length + 1)) -replace '\\', '/' } | Sort-Object
      $expected = Get-Content $manifest
      # -CaseSensitive: file names are case-sensitive in the bash manifests
      $diff = Compare-Object $expected $actual -CaseSensitive
      if ($diff) { Result FAIL "T0/$label" 'golden manifest drift (regen: tests/gen-manifests.sh)' }
      else { Result PASS "T0/$label" 'golden manifest match' }
    } else {
      Result SKIP "T0/$label" 'no golden manifest'
    }

    if ($haveTask) {
      Push-Location $dest
      task --list *> $null
      $taskExit = $LASTEXITCODE
      Pop-Location
      if ($taskExit -eq 0) { Result PASS "T1/$label/taskfile" 'task --list parses' }
      else { Result FAIL "T1/$label/taskfile" 'task --list failed' }
    } else {
      Result SKIP "T1/$label/taskfile" 'task not installed'
    }

    # self-contained roots per tier (mirror of run-all.sh); tier 04 has none:
    # its modules live in the external registry, hcl checks cover the units
    $roots = @()
    if ($tier -eq '01') { $roots = @('.') }
    elseif ($tier -eq '02') { $roots = @(Get-ChildItem (Join-Path $dest 'envs') -Directory | ForEach-Object { 'envs/' + $_.Name }) }
    elseif ($tier -eq '03') { $roots = @('modules/baseline') }

    if ($engines.Count -eq 0) {
      Result SKIP "T1,T2/$label" 'no engine installed'
      continue
    }
    if ($roots.Count -eq 0) {
      Result SKIP "T1,T2/$label" 'no local roots (terragrunt units are bash-runner territory)'
      continue
    }

    foreach ($engine in $engines) {
      $ok = $true
      foreach ($r in $roots) {
        & $engine -chdir="$(Join-Path $dest $r)" fmt -check -recursive *> $null
        if ($LASTEXITCODE -ne 0) { $ok = $false }
      }
      if ($ok) { Result PASS "T1/$label/$engine" 'fmt -check -recursive' }
      else { Result FAIL "T1/$label/$engine" 'fmt -check -recursive' }

      $ok = $true
      foreach ($r in $roots) {
        & $engine -chdir="$(Join-Path $dest $r)" init -backend=false *> $null
        if ($LASTEXITCODE -ne 0) { $ok = $false; break }
        & $engine -chdir="$(Join-Path $dest $r)" validate *> $null
        if ($LASTEXITCODE -ne 0) { $ok = $false; break }
      }
      if ($ok) { Result PASS "T2/$label/$engine" 'init -backend=false + validate' }
      else { Result FAIL "T2/$label/$engine" 'init/validate failed' }
    }
  }
}

Write-Host "=== summary: $script:Pass pass, $script:Fail fail, $script:Skip skip ==="
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }
