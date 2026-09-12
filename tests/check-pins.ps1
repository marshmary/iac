# check-pins.ps1 — T0-level pin-consistency gate (docs/testing.md).
#
# PowerShell mirror of tests/check-pins.sh: engine pins must move atomically
# across the per-tier version files, the runner Dockerfile ARGs, and
# docs/engine-duality.md. PS 5.1-compatible (no ??, no ternary).
#
#   tests/check-pins.ps1             # repo gate (wired into run-all.ps1)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Tiers = '01-solo', '02-small-team', '03-team-terragrunt', '04-large-terragrunt'
$script:Fails = 0

function Fail([string]$msg) {
  # stderr: Get-TierPin/Get-DockerfileArg stdout is captured by the caller,
  # so diagnostics must not mix into the captured value.
  [Console]::Error.WriteLine("FAIL: " + $msg)
  $script:Fails++
}

function Read-Trimmed([string]$path) {
  return ([System.IO.File]::ReadAllText($path)).Trim()
}

# Get-TierPin <version-file>: the pinned version; fails when the tiers that
# ship the file disagree with each other.
function Get-TierPin([string]$versionFile) {
  $want = ''
  foreach ($t in $Tiers) {
    $f = Join-Path $RepoRoot ("templates/" + $t + "/" + $versionFile)
    if (-not (Test-Path $f)) { continue }
    $v = Read-Trimmed $f
    if ($want -eq '') {
      $want = $v
    } elseif ($v -ne $want) {
      Fail ("{0} disagrees across tiers: '{1}' vs '{2}' ({3})" -f $versionFile, $want, $v, $t)
      return ''
    }
  }
  if ($want -eq '') { Fail ("no tier ships " + $versionFile) }
  return $want
}

# Get-DockerfileArg <ARG>: the runner image's pinned default.
function Get-DockerfileArg([string]$argName) {
  $dockerfile = Join-Path $RepoRoot 'tests/docker/Dockerfile.runner'
  foreach ($line in Get-Content $dockerfile) {
    if ($line -match ('^ARG ' + $argName + '=(.*)$')) { return $Matches[1].Trim() }
  }
  Fail ("ARG " + $argName + " missing in tests/docker/Dockerfile.runner")
  return ''
}

function Check-Eq([string]$label, [string]$a, [string]$b) {
  if ($a -ne $b) {
    Fail ("{0}: '{1}' != '{2}' (pins must move atomically)" -f $label, $a, $b)
  }
}

$tf = Get-TierPin '.terraform-version'
$tofu = Get-TierPin '.opentofu-version'
$tg = Get-TierPin '.terragrunt-version'   # tiers 03/04 only

Check-Eq ".terraform-version vs Dockerfile TF_VERSION" $tf (Get-DockerfileArg 'TF_VERSION')
Check-Eq ".opentofu-version  vs Dockerfile TOFU_VERSION" $tofu (Get-DockerfileArg 'TOFU_VERSION')
Check-Eq ".terragrunt-version vs Dockerfile TG_VERSION" $tg (Get-DockerfileArg 'TG_VERSION')

# The engine-duality doc quotes the pins in prose - keep it honest too.
$duality = Join-Path $RepoRoot 'docs/engine-duality.md'
foreach ($pair in @('Terraform', $tf), @('OpenTofu', $tofu)) {
  $needle = '`' + $pair[1] + '`'
  if (-not (Get-Content $duality | Select-String -SimpleMatch $needle -Quiet)) {
    Fail ("docs/engine-duality.md does not quote the pinned " + $pair[0] + " version " + $needle)
  }
}

if ($script:Fails -gt 0) {
  Write-Output "pin drift detected - bump every location in the same commit (see docs/testing.md)."
  exit 1
}
Write-Output ("pins consistent: terraform={0} tofu={1} terragrunt={2}" -f $tf, $tofu, $tg)
exit 0
