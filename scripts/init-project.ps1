<#
.SYNOPSIS
  Instantiate a new IaC project from a tier template.

.EXAMPLE
  scripts/init-project.ps1 -Tier 01 -Provider aws -Name my-app -Dest ..\my-app
  scripts/init-project.ps1 -Tier 04 -Name org-infra -Dest ..\org-infra -NoGit

.DESCRIPTION
  Contract (see AGENTS.md at the repo root):
    1. copies templates/<tier>/ to -Dest
    2. merges the chosen cloud's providers/ layer (tier-specific rules)
    3. copies shared docs (conventions, engine-duality, migrations) into -Dest\docs
    4. substitutes __TOKEN__ placeholders (defaults in docs/placeholders.md)
    5. fails if any __TOKEN__ survives
    6. git init (unless -NoGit) and prints next steps
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('01', '02', '03', '04')][string]$Tier,
  [ValidateSet('aws', 'azure', 'gcp', 'all', '')][string]$Provider = '',
  [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9]([a-z0-9-]*[a-z0-9])?$')][string]$Name,
  [Parameter(Mandatory = $true)][string]$Dest,
  [ValidateSet('tofu', 'terraform')][string]$Engine = 'tofu',
  [string]$Region = '',
  [switch]$NoGit,
  [switch]$AllowTokens
)

$ErrorActionPreference = 'Stop'
# terminating errors must produce a non-zero exit code for callers (& / CI)
trap { Write-Error $_; exit 1 }
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$TierMap = @{ '01' = '01-solo'; '02' = '02-small-team'; '03' = '03-team-terragrunt'; '04' = '04-large-terragrunt' }
$Src = Join-Path $RepoRoot ("templates/" + $TierMap[$Tier])
if (-not (Test-Path $Src)) { throw "template for tier $Tier not found: $Src" }

if ($Tier -ne '04') {
  if ([string]::IsNullOrEmpty($Provider)) { throw "-Provider (aws/azure/gcp) is required for tier $Tier" }
} else {
  $Provider = 'all'
}

$Dest = [System.IO.Path]::GetFullPath($Dest)
if ((Test-Path $Dest) -and ((Get-ChildItem $Dest -Force | Measure-Object).Count -gt 0)) {
  throw "destination exists and is not empty: $Dest"
}

New-Item -ItemType Directory -Path $Dest -Force | Out-Null
Copy-Item -Path (Join-Path $Src '*') -Destination $Dest -Recurse -Force

# --- tier-specific provider merge ---------------------------------------------------
function Merge-ProviderTests([string]$cloud) { # providers/<cloud>/tests/ -> <dest>/tests/
  $provTests = Join-Path $Dest "providers/$cloud/tests"
  if (Test-Path $provTests) {
    New-Item -ItemType Directory -Path (Join-Path $Dest 'tests') -Force | Out-Null
    Copy-Item -Path (Join-Path $provTests '*') -Destination (Join-Path $Dest 'tests') -Force
  }
}
switch ($Tier) {
  '01' {
    $provFiles = Get-ChildItem (Join-Path $Dest "providers/$Provider") -Filter *.tf -File
    if (-not $provFiles) { throw "no provider .tf files for $Provider" }
    foreach ($f in $provFiles) { Move-Item $f.FullName (Join-Path $Dest $f.Name) }
    Merge-ProviderTests $Provider
    Remove-Item -Recurse -Force (Join-Path $Dest 'providers')
  }
  '02' {
    $provFiles = Get-ChildItem (Join-Path $Dest "providers/$Provider") -Filter *.tf -File
    if (-not $provFiles) { throw "no provider .tf files for $Provider" }
    foreach ($envdir in Get-ChildItem (Join-Path $Dest 'envs') -Directory) {
      foreach ($f in $provFiles) {
        $content = [System.IO.File]::ReadAllText($f.FullName) -replace '__ENV__', $envdir.Name
        [System.IO.File]::WriteAllText((Join-Path $envdir.FullName $f.Name), $content)
      }
    }
    Merge-ProviderTests $Provider
    Remove-Item -Recurse -Force (Join-Path $Dest 'providers')
  }
  '03' {
    $injectPath = Join-Path $Dest "providers/$Provider/root-provider.hcl"
    if (-not (Test-Path $injectPath)) { throw "missing root-provider.hcl for $Provider" }
    $rootPath = Join-Path $Dest 'root.hcl'
    $lines = [System.Collections.Generic.List[string]](Get-Content $rootPath)
    $begin = -1; $end = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^#\s*>>>\s*CLOUD PROVIDER') { $begin = $i }
      if ($lines[$i] -match '^#\s*<<<\s*END CLOUD PROVIDER') { $end = $i; break }
    }
    if ($begin -lt 0 -or $end -lt $begin) { throw "injection markers not found in root.hcl" }
    $injected = [System.Collections.Generic.List[string]](Get-Content $injectPath)
    $out = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -le $begin; $i++) { $out.Add($lines[$i]) }
    foreach ($l in $injected) { $out.Add($l) }
    for ($i = $end; $i -lt $lines.Count; $i++) { $out.Add($lines[$i]) }
    [System.IO.File]::WriteAllText($rootPath, ($out -join "`n") + "`n")
    Remove-Item -Recurse -Force (Join-Path $Dest 'providers')
  }
  '04' { <# all platforms retained #> }
}

# --- shared docs copied into the generated project -----------------------------------
New-Item -ItemType Directory -Path (Join-Path $Dest 'docs') -Force | Out-Null
Copy-Item (Join-Path $RepoRoot 'docs/conventions.md') $Dest\docs\
Copy-Item (Join-Path $RepoRoot 'docs/engine-duality.md') $Dest\docs\
Copy-Item -Recurse (Join-Path $RepoRoot 'docs/migrations') (Join-Path $Dest 'docs\migrations')

# --- token substitution ---------------------------------------------------------------
$azureSa = ($Name -replace '[^a-z0-9]', '')
$azureSa = $azureSa.Substring(0, [Math]::Min(17, $azureSa.Length)) + 'tfstate'

function Get-CloudMap([string]$cloud) {
  $regionByCloud = @{ aws = 'us-east-1'; azure = 'eastus'; gcp = 'us-central1' }
  $r = if ($Region) { $Region } else { $regionByCloud[$cloud] }
  $m = @{ '__REGION__' = $r }
  switch ($cloud) {
    'aws'   { $m['__STATE_BUCKET__'] = "$Name-tfstate"; $m['__AWS_ACCOUNT_ID__'] = '000000000000' }
    'azure' { $m['__STATE_RESOURCE_GROUP__'] = "$Name-tfstate-rg"; $m['__STATE_STORAGE_ACCOUNT__'] = $azureSa; $m['__STATE_CONTAINER__'] = 'tfstate'; $m['__AZURE_SUBSCRIPTION_ID__'] = '00000000-0000-0000-0000-000000000000' }
    'gcp'   { $m['__STATE_BUCKET__'] = "$Name-tfstate"; $m['__GCP_PROJECT__'] = "$Name-project" }
  }
  return $m
}

function Substitute([string]$dir, [hashtable[]]$maps) {
  foreach ($file in Get-ChildItem $dir -File -Recurse) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $updated = $content
    foreach ($map in $maps) {
      foreach ($k in $map.Keys) { $updated = $updated.Replace($k, $map[$k]) }
    }
    if ($updated -ne $content) { [System.IO.File]::WriteAllText($file.FullName, $updated) }
  }
}

$globalMap = @{ '__PROJECT_NAME__' = $Name }
$registryMap = @{
  '__AWS_ACCOUNT_ID__' = '000000000000'
  '__AZURE_SUBSCRIPTION_ID__' = '00000000-0000-0000-0000-000000000000'
  '__GCP_PROJECT__' = "$Name-project"
}
if ($Tier -eq '04') {
  # Registry tokens live outside platforms/ (common/accounts.hcl); per-cloud
  # tokens (incl. the ambiguous __REGION__) apply under platforms/<cloud>/ only.
  Substitute $Dest @($globalMap, $registryMap)
  foreach ($c in 'aws', 'azure', 'gcp') {
    $pdir = Join-Path $Dest "platforms/$c"
    if (Test-Path $pdir) { Substitute $pdir @(Get-CloudMap $c) }
  }
} else {
  Substitute $Dest @($globalMap, (Get-CloudMap $Provider))
}

# --- self-test: no surviving tokens ---------------------------------------------------
if (-not $AllowTokens) {
  $leftovers = Get-ChildItem $Dest -File -Recurse | Select-String -Pattern '__[A-Z0-9_]+__'
  if ($leftovers) {
    $leftovers | ForEach-Object { Write-Error ("{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()) }
    throw "unsubstituted tokens remain (see errors above)"
  }
}

# --- engine preference + git -----------------------------------------------------------
[System.IO.File]::WriteAllText((Join-Path $Dest '.env'), "# local preferences (gitignored)`nIAC_ENGINE=$Engine`n")
if (-not $NoGit -and -not (Test-Path (Join-Path $Dest '.git'))) {
  git -C $Dest init -q
}

# --- next steps -----------------------------------------------------------------------
Write-Host ""
Write-Host "Initialized $Name from templates/$Tier (cloud: $Provider, engine: $Engine)"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. cd $Dest"
Write-Host "  2. review defaults you may want to change:"
switch ($Tier) {
  '01' { Write-Host "     - backend.tf (state bucket/keys from bootstrap/$Provider.md)" }
  '02' { Write-Host "     - envs\*\backend.tf (state bucket/keys from bootstrap/$Provider.md)" }
  '03' { Write-Host "     - root.hcl injected backend block (values from bootstrap/$Provider.md)" }
  '04' { Write-Host "     - common\accounts.hcl + common\regions.hcl (real ids) and platforms\*\root.hcl backends" }
}
if ($Tier -eq '04') {
  Write-Host "  3. follow platforms\<cloud>\bootstrap.md for each platform you will use"
} else {
  Write-Host "  3. follow bootstrap/$Provider.md to create the state backend"
}
Write-Host "  4. task engine-check && task check     # offline validation"
$envSuffix = if ($Tier -ne '01') { ' ENV=dev' } else { '' }
$platSuffix = if ($Tier -eq '04') { ' PLATFORM=aws' } else { '' }
Write-Host "  5. task init-backend && task plan$envSuffix$platSuffix && review"
Write-Host "  6. task apply && commit the lockfile"
Write-Host ""
Write-Host "Agent guidance: AGENTS.md in the project root. Growth path: docs\migrations\."
exit 0
