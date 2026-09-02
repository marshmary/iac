<#
.SYNOPSIS
  PowerShell mirror of tests/run-all.sh — the no-cloud test pyramid (docs/testing.md).

.DESCRIPTION
  Runs T0 (init + golden manifest + token sweep) for every tier x provider.
  If tofu or terraform is on PATH, also runs T1/T2 (fmt-check, init
  -backend=false, validate) for the plain tiers (01, 02). Terragrunt tiers
  03/04 and T3-T6 are covered by the bash runner; this mirror keeps the
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

$engine = $null
foreach ($cand in 'tofu', 'terraform') {
  if (Get-Command $cand -ErrorAction SilentlyContinue) { $engine = $cand; break }
}

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
      $diff = Compare-Object $expected $actual
      if ($diff) { Result FAIL "T0/$label" 'golden manifest drift (regen: tests/gen-manifests.sh)' }
      else { Result PASS "T0/$label" 'golden manifest match' }
    } else {
      Result SKIP "T0/$label" 'no golden manifest'
    }

    if ($engine -and ($tier -eq '01' -or $tier -eq '02')) {
      $roots = if ($tier -eq '01') { @('.') } else { (Get-ChildItem (Join-Path $dest 'envs') -Directory | ForEach-Object { 'envs/' + $_.Name }) }
      $ok = $true
      foreach ($r in $roots) {
        $wd = Join-Path $dest $r
        & $engine -chdir="$wd" init -backend=false *> $null
        if ($LASTEXITCODE -ne 0) { $ok = $false; break }
        & $engine -chdir="$wd" validate *> $null
        if ($LASTEXITCODE -ne 0) { $ok = $false; break }
      }
      if ($ok) { Result PASS "T2/$label/$engine" 'init -backend=false + validate' }
      else { Result FAIL "T2/$label/$engine" 'validate failed' }
    } elseif (-not $engine) {
      Result SKIP "T2/$label" 'no engine installed'
    } else {
      Result SKIP "T2/$label" 'terragrunt tiers: use tests/run-all.sh'
    }
  }
}

Write-Host "=== summary: $script:Pass pass, $script:Fail fail, $script:Skip skip ==="
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }
