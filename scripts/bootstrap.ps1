<#
.SYNOPSIS
  One-liner installer: fetch a pinned catalog release, verify its sha256,
  delegate to scripts/init-project.ps1. Contains NO template logic; the T0
  parity gate in tests/run-all.ps1 fails the moment it forks the contract
  (docs/testing.md "Bootstrap gate", docs/adr/0001).

.EXAMPLE
  Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.ps1) } -Tier 01 -Provider aws -Name my-app -Dest ..\my-app"

.EXAMPLE
  scripts\bootstrap.ps1 -Ref v0.1.0 -Tier 01 -Provider aws -Name my-app -Dest ..\my-app

.NOTES
  Bootstrap parameters (-Ref/-Sha256/-Source/-Keep) are consumed here; every
  other argument is forwarded to init-project.ps1 via ValueFromRemainingArguments.
  Omit the forwarded arguments entirely and the init script prompts one by
  one (console stdin survives Invoke-Expression, unlike the piped bash case).
#>
[CmdletBinding()]
param(
  [string]$Ref,
  [string]$Sha256,
  [string]$Source,
  [switch]$Keep,
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$InitArgs
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # 5.1 otherwise renders a progress bar per chunk
# terminating errors must produce a non-zero exit code for callers (& / CI);
# -ErrorAction Continue is load-bearing: with the script-level Stop preference
# Write-Error would throw before `exit 1` runs, leaving callers' $LASTEXITCODE
# untouched (and -File callers only get a process-level failure)
trap { Write-Error $_ -ErrorAction Continue; exit 1 }
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 # TLS 1.2

$RepoSlug = 'marshmary/iac'
$ReleaseBase = "https://github.com/$RepoSlug/releases"
$ArchiveBase = "https://github.com/$RepoSlug/archive"
$TarballName = 'catalog.tar.gz'

function Get-LatestReleaseTag {
  # follow /releases/latest's 302 without the GitHub API (rate limits);
  # AllowAutoRedirect=false returns the 3xx response itself, 4xx/5xx throw
  $req = [System.Net.HttpWebRequest]::Create("$ReleaseBase/latest")
  $req.AllowAutoRedirect = $false
  $req.Method = 'HEAD'
  $resp = $null
  try { $resp = $req.GetResponse() }
  catch [System.Net.WebException] {
    $code = 0
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      $_.Exception.Response.Close()
    }
    throw ("could not resolve the latest release (HTTP $code) - none published yet? " +
           "Fix: add -Ref main to the one-liner, or clone the catalog: " +
           "git clone https://github.com/$RepoSlug.git")
  }
  try {
    $status = [int]$resp.StatusCode
    if ($status -lt 300 -or $status -ge 400) { throw "unexpected response from $ReleaseBase/latest (HTTP $status)" }
    $loc = $resp.Headers['Location']
  } finally { $resp.Close() }
  if (-not $loc) { throw "no redirect location from $ReleaseBase/latest" }
  $idx = $loc.LastIndexOf('/tag/')
  if ($idx -lt 0) { throw "unexpected /releases/latest redirect: $loc" }
  return $loc.Substring($idx + 5)
}

function Get-Sha256([string]$Path) {
  (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Test-HashMatch([string]$Got, [string]$Expected) {
  # case-insensitive by design: checksums.txt is lowercase, Get-FileHash is uppercase
  return ($Got -ieq $Expected)
}

function Get-ReleaseChecksum([string]$Tag) {
  # the catalog.tar.gz hash from the release's checksums.txt, or '' if absent
  try {
    $content = (Invoke-WebRequest -UseBasicParsing -Uri "$ReleaseBase/download/$Tag/checksums.txt").Content
  } catch {
    return ''
  }
  $pattern = '^[0-9a-fA-F]{64}\s+\*?' + [regex]::Escape($TarballName) + '$'
  foreach ($line in ($content -split "`r?`n")) {
    if ($line -match $pattern) { return (($line -split '\s+')[0]) }
  }
  return ''
}

function ConvertTo-SplatArgs([string[]]$RawArgs) {
  # Re-tokenize the forwarded arguments into a hashtable for named splatting.
  # A raw ValueFromRemainingArguments array splats POSITIONALLY (the '-Tier'
  # token would bind as a value, not a name), so '-Name value' pairs are
  # rebuilt here generically — no knowledge of the init script's parameters;
  # bare '-Flag' tokens become $true switches, unmatched keys still fail
  # loudly in the child script's own parameter binding.
  $named = @{}
  $i = 0
  while ($i -lt $RawArgs.Count) {
    $tok = $RawArgs[$i]
    if ($tok -like '-*') {
      if (($i + 1) -lt $RawArgs.Count -and -not ($RawArgs[$i + 1] -like '-*')) {
        $named[$tok.Substring(1)] = $RawArgs[$i + 1]
        $i += 2
      } else {
        $named[$tok.Substring(1)] = $true
        $i += 1
      }
    } else {
      $i += 1
    }
  }
  return $named
}

function Get-TarExe {
  # Prefer Windows' own bsdtar: it handles C:\ paths natively. A GNU tar from
  # MSYS/Git Bash on PATH would treat 'C:' as a remote-host prefix and fail.
  $sysTar = Join-Path $env:SystemRoot 'System32\tar.exe'
  if (Test-Path -LiteralPath $sysTar -PathType Leaf) { return $sysTar }
  $cmd = Get-Command tar -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

$TarExe = Get-TarExe
if (-not $TarExe) {
  throw 'tar.exe not found - it ships with Windows 10 1803+ / Server 2019+; or use the clone fallback (README)'
}

$Work = Join-Path ([System.IO.Path]::GetTempPath()) ('iac-bootstrap-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$ExitCode = 1
try {
  $tarball = ''
  $srcDir = ''
  if ($Source) {
    if (Test-Path -LiteralPath $Source -PathType Container) {
      $srcDir = $Source
    } elseif (Test-Path -LiteralPath $Source -PathType Leaf) {
      $tarball = $Source
      if ($Sha256) {
        $got = Get-Sha256 $tarball
        if (-not (Test-HashMatch $got $Sha256)) { throw "sha256 mismatch for $tarball : got $got, expected $Sha256" }
      }
      Write-Host "==> using local tarball $Source (no remote verification requested)"
    } else {
      throw "-Source is neither a directory nor a file: $Source"
    }
  } else {
    if ($Ref) { $fetchRef = $Ref } else { $fetchRef = Get-LatestReleaseTag }
    Write-Host "==> fetching $RepoSlug@$fetchRef"
    $tarball = Join-Path $Work $TarballName
    Invoke-WebRequest -UseBasicParsing -Uri "$ArchiveBase/$fetchRef.tar.gz" -OutFile $tarball
    $expected = ''
    if ($Sha256) {
      $expected = $Sha256
    } elseif (-not $Ref -or ($fetchRef -match '^v[0-9]+\.[0-9]+\.[0-9]+([-._][0-9A-Za-z.-]+)?$')) {
      # default mode or an explicit vX.Y.Z tag: strict - checksums.txt must exist
      $expected = Get-ReleaseChecksum $fetchRef
      if (-not $expected) {
        throw ("release $fetchRef has no checksums.txt - refusing an unverified install. " +
               "Fix: pass -Sha256 explicitly, use -Ref main (unverified, moving target), or clone the catalog.")
      }
    } else {
      Write-Warning "-Ref $fetchRef is a moving target; skipping sha256 verification"
    }
    if ($expected) {
      $got = Get-Sha256 $tarball
      if (-not (Test-HashMatch $got $expected)) { throw "sha256 mismatch for $tarball : got $got, expected $expected" }
      Write-Host "==> fetched $fetchRef (sha256 verified)"
    } else {
      Write-Host "==> fetched $fetchRef (UNVERIFIED)"
    }
  }

  if ($tarball -and -not $srcDir) {
    $extract = Join-Path $Work 'extract'
    New-Item -ItemType Directory -Path $extract -Force | Out-Null
    & $TarExe -xzf $tarball -C $extract
    if ($LASTEXITCODE -ne 0) { throw "tar extraction failed (exit $LASTEXITCODE)" }
    # GitHub release tarballs wrap everything in a single top-level directory
    # (iac-<ref>/); the parity gate's plain `tar -C <repo> .` tarball does not.
    $children = @(Get-ChildItem -LiteralPath $extract -Force)
    $dirs = @($children | Where-Object { $_.PSIsContainer })
    if ($children.Count -eq 1 -and $dirs.Count -eq 1) { $srcDir = $dirs[0].FullName }
    else { $srcDir = $extract }
  }

  $init = Join-Path $srcDir 'scripts/init-project.ps1'
  if (-not (Test-Path -LiteralPath $init)) { throw "fetched catalog has no scripts/init-project.ps1 at: $srcDir" }

  $splat = ConvertTo-SplatArgs $InitArgs
  & $init @splat
  $ExitCode = $LASTEXITCODE
} finally {
  if ($Keep) {
    Write-Host "==> bootstrap payload kept at: $Work (catalog: $srcDir)"
  } else {
    Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
  }
}
exit $ExitCode
