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

# T0-level bootstrap parity (docs/testing.md "Bootstrap gate"): the one-liner
# entry (scripts/bootstrap.ps1) must produce trees identical to direct init,
# and a corrupted tarball must be rejected on sha256 mismatch. Offline via
# -Source; the remote path is release-checklist territory.
function Test-TreeEqual([string]$left, [string]$right) {
  $lf = Get-ChildItem $left -File -Recurse | ForEach-Object {
    ($_.FullName.Substring($left.Length + 1) -replace '\\', '/') + ' ' + (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
  }
  $rf = Get-ChildItem $right -File -Recurse | ForEach-Object {
    ($_.FullName.Substring($right.Length + 1) -replace '\\', '/') + ' ' + (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
  }
  return (@(Compare-Object -ReferenceObject @($lf) -DifferenceObject @($rf)).Count -eq 0)
}
# prefer Windows' own bsdtar: a GNU tar from MSYS/Git Bash on PATH treats
# 'C:' as a remote-host prefix and fails on Windows paths
$tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path -LiteralPath $tarExe -PathType Leaf)) {
  $cmd = Get-Command tar -ErrorAction SilentlyContinue
  if ($cmd) { $tarExe = $cmd.Source } else { $tarExe = '' }
}
$bootstrap = Join-Path $RepoRoot 'scripts/bootstrap.ps1'
$initScript = Join-Path $RepoRoot 'scripts/init-project.ps1'
if ($tarExe) {
  $bt = Join-Path $Scratch 'bootstrap'
  if (Test-Path $bt) { Remove-Item -Recurse -Force $bt }
  New-Item -ItemType Directory -Path $bt -Force | Out-Null
  $tgz = Join-Path $bt 'catalog.tar.gz'
  # tarball from the working tree (not git archive HEAD): uncommitted work
  # must not false-fail parity
  & $tarExe -czf $tgz --exclude=.git --exclude=tests/scratch --exclude=playground/projects -C $RepoRoot .
  if ($LASTEXITCODE -ne 0) {
    Result FAIL 'T0/bootstrap' 'tarball build failed'
  } else {
    $goodHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $tgz).Hash
    # try/catch around every bootstrap call: a failing bootstrap surfaces its
    # trap's Write-Error as a TERMINATING error in this runner (PS 5.1 quirk,
    # *> $null does not swallow it); the exit codes below still carry the verdict
    try {
      & $bootstrap -Source $tgz -Sha256 $goodHash -Tier 01 -Provider aws -Name parity-check -Dest (Join-Path $bt 'tarball-A') -NoGit *> $null
    } catch { }
    $exitTar = $LASTEXITCODE
    try {
      & $bootstrap -Source $RepoRoot -Tier 02 -Provider azure -Name parity-check -Dest (Join-Path $bt 'dir-B') -NoGit *> $null
    } catch { }
    $exitDir = $LASTEXITCODE
    & $initScript -Tier 01 -Provider aws -Name parity-check -Dest (Join-Path $bt 'ref-A') -NoGit *> $null
    $exitRefA = $LASTEXITCODE
    & $initScript -Tier 02 -Provider azure -Name parity-check -Dest (Join-Path $bt 'ref-B') -NoGit *> $null
    $exitRefB = $LASTEXITCODE
    $equalA = Test-TreeEqual (Join-Path $bt 'tarball-A') (Join-Path $bt 'ref-A')
    $equalB = Test-TreeEqual (Join-Path $bt 'dir-B') (Join-Path $bt 'ref-B')
    if ($exitTar -eq 0 -and $exitDir -eq 0 -and $exitRefA -eq 0 -and $exitRefB -eq 0 -and $equalA -and $equalB) {
      Result PASS 'T0/bootstrap' 'tarball+dir parity = direct init'
    } else {
      Result FAIL 'T0/bootstrap' 'bootstrap output differs from direct init'
    }

    $bad = Join-Path $bt 'bad.tar.gz'
    Copy-Item -LiteralPath $tgz -Destination $bad -Force
    [System.IO.File]::AppendAllText($bad, 'x')
    try {
      & $bootstrap -Source $bad -Sha256 $goodHash -Tier 01 -Name parity-check -Dest (Join-Path $bt 'tampered') -NoGit *> $null
    } catch { }
    if ($LASTEXITCODE -eq 0) { Result FAIL 'T0/bootstrap' 'sha mismatch not rejected' }
    else { Result PASS 'T0/bootstrap' 'sha mismatch rejected' }
    Remove-Item -Recurse -Force $bt -ErrorAction SilentlyContinue
  }
} else {
  Result SKIP 'T0/bootstrap' 'tar not installed'
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
