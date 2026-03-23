#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ScriptPath = if ([string]::IsNullOrWhiteSpace($PSCommandPath)) { $MyInvocation.MyCommand.Definition } else { $PSCommandPath }
$script:ScriptName = Split-Path -Leaf $script:ScriptPath
$script:ScriptDir = Split-Path -Parent $script:ScriptPath
$script:CliArgs = $args
if ([string]::IsNullOrWhiteSpace($env:AGENT_KIT_HOME)) {
  $env:AGENT_KIT_HOME = (Resolve-Path (Join-Path $script:ScriptDir "..")).Path
}
$script:AgentKitHome = [System.IO.Path]::GetFullPath($env:AGENT_KIT_HOME)
$script:BootstrapVersion = "2026-03-23-core-v2"

$script:DryRun = $false
$script:Force = $false
$script:Quiet = $false
$script:NoMcp = $false
$script:ProjectRoot = ""
$script:AgentName = ""
$script:ForcedProfile = ""
$script:StrictIsolation = if ([string]::IsNullOrWhiteSpace($env:AGENT_KIT_STRICT_ISOLATION)) { "1" } else { $env:AGENT_KIT_STRICT_ISOLATION }
$script:AllowCopyFallback = if ([string]::IsNullOrWhiteSpace($env:AGENT_KIT_ALLOW_COPY_FALLBACK)) { "1" } else { $env:AGENT_KIT_ALLOW_COPY_FALLBACK }

function Show-Usage {
  Write-Host @"
Usage: $script:ScriptName [options]

Options:
  --project-root <path>  Bootstrap this repository root directly
  --agent <name>         Agent command name
  --profile <name>       Force profile name
  --dry-run              Show planned changes only
  --force                Override marker and replace existing symlinks
  --quiet                Minimal output
  --no-strict            Disable strict isolation checks
  --no-mcp               Skip MCP server propagation via ruler
  -h, --help             Show help
"@
}

function Log {
  param([string]$Message)
  if (-not $script:Quiet) {
    Write-Host $Message
  }
}

function Normalize-PathValue {
  param(
    [string]$PathValue,
    [string]$BaseDir = ""
  )

  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return ""
  }

  $candidate = $PathValue
  if (-not [System.IO.Path]::IsPathRooted($candidate) -and -not [string]::IsNullOrWhiteSpace($BaseDir)) {
    $candidate = Join-Path $BaseDir $candidate
  }

  return [System.IO.Path]::GetFullPath($candidate).TrimEnd("\", "/")
}

function Ensure-Dir {
  param([string]$DirPath)

  if ([string]::IsNullOrWhiteSpace($DirPath)) {
    return
  }
  if (Test-Path -LiteralPath $DirPath) {
    return
  }

  if ($script:DryRun) {
    Log "[dry-run] mkdir -p `"$DirPath`""
    return
  }

  New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
}

function Is-SymbolicLinkItem {
  param([System.IO.FileSystemInfo]$Item)

  if (-not ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
    return $false
  }

  $linkTypeProperty = $Item.PSObject.Properties["LinkType"]
  if ($null -eq $linkTypeProperty) {
    return $false
  }

  return $linkTypeProperty.Value -eq "SymbolicLink"
}

function Get-LinkTargetValue {
  param([System.IO.FileSystemInfo]$Item)

  $target = $Item.Target
  if ($target -is [System.Array]) {
    if ($target.Count -eq 0) {
      return ""
    }
    return [string]$target[0]
  }

  return [string]$target
}

function Get-HardLinkPaths {
  param([string]$PathValue)

  if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
    return @()
  }

  try {
    $output = & fsutil hardlink list $PathValue 2>$null
    if ($LASTEXITCODE -ne 0) {
      return @()
    }
    $resolved = (Resolve-Path -LiteralPath $PathValue).Path
    $entries = @()
    foreach ($line in $output) {
      $trimmed = $line.Trim()
      if ([string]::IsNullOrWhiteSpace($trimmed)) {
        continue
      }
      $entries += (Normalize-PathValue -PathValue $trimmed -BaseDir (Split-Path -Parent $resolved))
    }
    return @($entries)
  } catch {
    return @()
  }
}

function Is-HardLinkToTarget {
  param(
    [string]$PathValue,
    [string]$Target
  )

  $targetNormalized = Normalize-PathValue -PathValue $Target
  foreach ($linkedPath in Get-HardLinkPaths -PathValue $PathValue) {
    if ($linkedPath.Equals($targetNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Set-ManagedLink {
  param(
    [string]$Target,
    [string]$LinkPath
  )

  if ($script:DryRun) {
    Log "[dry-run] link `"$Target`" -> `"$LinkPath`""
    return
  }

  if (Test-Path -LiteralPath $LinkPath) {
    Remove-Item -LiteralPath $LinkPath -Force
  }

  try {
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target | Out-Null
  } catch {
    try {
      New-Item -ItemType HardLink -Path $LinkPath -Target $Target | Out-Null
      Log "[warn] symlink unavailable; created hardlink: $LinkPath"
    } catch {
      if ($script:AllowCopyFallback -eq "1") {
        Copy-Item -LiteralPath $Target -Destination $LinkPath -Force
        Log "[warn] link unavailable; copied file instead: $LinkPath"
      } else {
        throw "failed to create symlink or hardlink: $LinkPath -> $Target"
      }
    }
  }
}

function Safe-Symlink {
  param(
    [string]$Target,
    [string]$LinkPath
  )

  Ensure-Dir (Split-Path -Parent $LinkPath)

  if (Test-Path -LiteralPath $LinkPath) {
    $item = Get-Item -LiteralPath $LinkPath -Force
    if (Is-SymbolicLinkItem $item) {
      $currentTargetRaw = Get-LinkTargetValue $item
      $currentTarget = Normalize-PathValue -PathValue $currentTargetRaw -BaseDir (Split-Path -Parent $LinkPath)
      $desiredTarget = Normalize-PathValue -PathValue $Target
      if ($currentTarget.Equals($desiredTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
        return
      }
      if ($script:Force) {
        Set-ManagedLink -Target $Target -LinkPath $LinkPath
      } else {
        Log "[warn] keep existing symlink (use --force to replace): $LinkPath -> $currentTargetRaw"
      }
      return
    }

    if (Is-HardLinkToTarget -PathValue $LinkPath -Target $Target) {
      return
    }

    $hardlinks = Get-HardLinkPaths -PathValue $LinkPath
    if (@($hardlinks).Count -gt 0) {
      if ($script:Force) {
        Set-ManagedLink -Target $Target -LinkPath $LinkPath
      } else {
        Log "[warn] keep existing hardlink (use --force to replace): $LinkPath"
      }
      return
    }

    if ($script:Force) {
      Set-ManagedLink -Target $Target -LinkPath $LinkPath
    } else {
      Log "[warn] keep existing regular file: $LinkPath"
    }
    return
  }

  Set-ManagedLink -Target $Target -LinkPath $LinkPath
}

function Copy-IfMissing {
  param(
    [string]$Source,
    [string]$Destination
  )

  Ensure-Dir (Split-Path -Parent $Destination)
  if (Test-Path -LiteralPath $Destination) {
    return
  }

  if ($script:DryRun) {
    Log "[dry-run] cp `"$Source`" `"$Destination`""
    return
  }

  Copy-Item -LiteralPath $Source -Destination $Destination
}

function Sanitize-Name {
  param([string]$Value)

  $lower = $Value.ToLowerInvariant()
  return [regex]::Replace($lower, "[^a-z0-9._-]+", "_")
}

function Detect-ProjectRoot {
  if (-not [string]::IsNullOrWhiteSpace($script:ProjectRoot)) {
    $gitDir = Join-Path $script:ProjectRoot ".git"
    if (Test-Path -LiteralPath $gitDir) {
      return [System.IO.Path]::GetFullPath($script:ProjectRoot)
    }
    Log "[warn] --project-root is not a git repository: $script:ProjectRoot"
    return $null
  }

  $root = & git rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $null
  }

  return [System.IO.Path]::GetFullPath($root.Trim())
}

function Read-Map-Profile {
  param([string]$ProjectPath)

  $mapFile = Join-Path $script:AgentKitHome "config/project-map.tsv"
  if (-not (Test-Path -LiteralPath $mapFile)) {
    return $null
  }

  $bestProfile = $null
  $bestLength = -1
  foreach ($line in Get-Content -LiteralPath $mapFile) {
    if ($line -match "^\s*$" -or $line -match "^\s*#") {
      continue
    }
    $parts = $line -split "`t", 2
    if ($parts.Count -lt 2) {
      continue
    }
    $prefix = $parts[0].Trim()
    $profile = $parts[1].Trim()
    if ([string]::IsNullOrWhiteSpace($prefix) -or [string]::IsNullOrWhiteSpace($profile)) {
      continue
    }
    if ($ProjectPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      if ($prefix.Length -gt $bestLength) {
        $bestProfile = $profile
        $bestLength = $prefix.Length
      }
    }
  }

  return $bestProfile
}

function Detect-Profile {
  param([string]$ProjectPath)

  if (-not [string]::IsNullOrWhiteSpace($script:ForcedProfile)) {
    return $script:ForcedProfile
  }

  $profileHint = Join-Path $ProjectPath ".agent-workflow/profile"
  if (Test-Path -LiteralPath $profileHint) {
    $profile = ((Get-Content -LiteralPath $profileHint -Raw) -replace "\s", "")
    if (-not [string]::IsNullOrWhiteSpace($profile)) {
      return $profile
    }
  }

  $mappedProfile = Read-Map-Profile -ProjectPath $ProjectPath
  if (-not [string]::IsNullOrWhiteSpace($mappedProfile)) {
    return $mappedProfile
  }

  return "generic"
}

function Is-ManagedSymlink {
  param([string]$PathValue)

  if (-not (Test-Path -LiteralPath $PathValue)) {
    return $false
  }

  $item = Get-Item -LiteralPath $PathValue -Force
  if (-not (Is-SymbolicLinkItem $item)) {
    return $false
  }

  $targetRaw = Get-LinkTargetValue $item
  if ([string]::IsNullOrWhiteSpace($targetRaw)) {
    return $false
  }

  $target = Normalize-PathValue -PathValue $targetRaw -BaseDir (Split-Path -Parent $PathValue)
  $homePath = Normalize-PathValue -PathValue $script:AgentKitHome
  $prefix = "$homePath\"

  return $target.Equals($homePath, [System.StringComparison]::OrdinalIgnoreCase) -or
    $target.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Is-ManagedHardLink {
  param([string]$PathValue)

  $pathNormalized = Normalize-PathValue -PathValue $PathValue
  $linkedPaths = @(Get-HardLinkPaths -PathValue $PathValue)
  if ($linkedPaths.Count -lt 2) {
    return $false
  }

  foreach ($linkedPath in $linkedPaths) {
    if ($linkedPath.Equals($pathNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }
    $homePath = Normalize-PathValue -PathValue $script:AgentKitHome
    $prefix = "$homePath\"
    if ($linkedPath.Equals($homePath, [System.StringComparison]::OrdinalIgnoreCase) -or
      $linkedPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function Strict-IsolationCheck {
  param([string]$ProjectPath)

  if ($script:StrictIsolation -ne "1") {
    return $true
  }
  if ($script:Force) {
    return $true
  }

  foreach ($name in @("AGENTS.md", "CLAUDE.md", "GEMINI.md", "MEMORY.md", "SKILLS.md")) {
    $path = Join-Path $ProjectPath $name
    if ((Test-Path -LiteralPath $path) -and -not (Is-ManagedSymlink -PathValue $path) -and -not (Is-ManagedHardLink -PathValue $path)) {
      Log "[block] strict isolation: unmanaged existing file/symlink at $path"
      Log "[hint] use --force for explicit replacement or migrate in a controlled step"
      return $false
    }
  }

  return $true
}

function Write-MemoryFile {
  param(
    [string]$MemoryFile,
    [string]$ProjectPath,
    [string]$Profile
  )

  if (Test-Path -LiteralPath $MemoryFile) {
    return
  }

  if ($script:DryRun) {
    Log "[dry-run] create memory file $MemoryFile"
    return
  }

  @"
# $(Split-Path -Leaf $ProjectPath)_MEMORY

## Project
- Root: $ProjectPath
- Profile: $Profile

## Notes
- Add persistent project-specific learnings here.
- Keep gotchas and validated command snippets concise.
"@ | Set-Content -LiteralPath $MemoryFile
}

function Write-StateFile {
  param(
    [string]$StateFile,
    [string]$ProjectPath,
    [string]$Profile,
    [string]$MemoryFile
  )

  if ($script:DryRun) {
    Log "[dry-run] write $StateFile"
    return
  }

  $agentValue = if ([string]::IsNullOrWhiteSpace($script:AgentName)) { "unknown" } else { $script:AgentName }
  $now = (Get-Date).ToString("o")

  @"
MODE=v2
BOOTSTRAP_VERSION=$script:BootstrapVersion
BOOTSTRAPPED_AT=$now
AGENT_NAME=$agentValue
PROJECT_ROOT=$ProjectPath
PROFILE=$Profile
AGENT_KIT_HOME=$script:AgentKitHome
MEMORY_FILE=$MemoryFile
"@ | Set-Content -LiteralPath $StateFile
}

function Parse-Args {
  param([string[]]$InputArgs)

  $i = 0
  while ($i -lt $InputArgs.Count) {
    $arg = $InputArgs[$i]
    switch ($arg) {
      "--project-root" {
        if ($i + 1 -ge $InputArgs.Count) {
          throw "missing value for --project-root"
        }
        $script:ProjectRoot = $InputArgs[$i + 1]
        $i += 2
      }
      "--agent" {
        if ($i + 1 -ge $InputArgs.Count) {
          throw "missing value for --agent"
        }
        $script:AgentName = $InputArgs[$i + 1]
        $i += 2
      }
      "--profile" {
        if ($i + 1 -ge $InputArgs.Count) {
          throw "missing value for --profile"
        }
        $script:ForcedProfile = $InputArgs[$i + 1]
        $i += 2
      }
      "--dry-run" {
        $script:DryRun = $true
        $i += 1
      }
      "--force" {
        $script:Force = $true
        $i += 1
      }
      "--quiet" {
        $script:Quiet = $true
        $i += 1
      }
      "--no-strict" {
        $script:StrictIsolation = "0"
        $i += 1
      }
      "--no-mcp" {
        $script:NoMcp = $true
        $i += 1
      }
      "--help" {
        Show-Usage
        return $false
      }
      "-h" {
        Show-Usage
        return $false
      }
      default {
        throw "unknown argument: $arg"
      }
    }
  }

  return $true
}

function Main {
  param([string[]]$CliArgs)

  if (-not (Parse-Args -InputArgs $CliArgs)) {
    return 0
  }

  $project = Detect-ProjectRoot
  if ([string]::IsNullOrWhiteSpace($project)) {
    Log "[skip] not inside a git repository"
    return 0
  }

  $markerDir = Join-Path $project ".agent-workflow"
  $stateFile = Join-Path $markerDir "state.env"
  if (-not $script:Force -and (Test-Path -LiteralPath $stateFile)) {
    $versionPattern = "^BOOTSTRAP_VERSION=$([regex]::Escape($script:BootstrapVersion))$"
    if (Select-String -LiteralPath $stateFile -Pattern $versionPattern -Quiet) {
      Log "[ok] already bootstrapped: $project"
      return 0
    }
  }

  if (-not (Strict-IsolationCheck -ProjectPath $project)) {
    return 2
  }

  $profile = Detect-Profile -ProjectPath $project
  $profileFile = Join-Path $script:AgentKitHome "profiles/$profile.md"
  if (-not (Test-Path -LiteralPath $profileFile)) {
    $profile = "generic"
    $profileFile = Join-Path $script:AgentKitHome "profiles/generic.md"
  }

  $projectName = Sanitize-Name -Value (Split-Path -Leaf $project)
  $memoryFile = Join-Path $script:AgentKitHome "memory/${projectName}_MEMORY.md"

  Log "[info] project: $project"
  Log "[info] profile: $profile"

  Ensure-Dir $markerDir
  Ensure-Dir (Join-Path $script:AgentKitHome "memory")

  Write-MemoryFile -MemoryFile $memoryFile -ProjectPath $project -Profile $profile

  Safe-Symlink -Target $profileFile -LinkPath (Join-Path $project "AGENTS.md")
  Safe-Symlink -Target $profileFile -LinkPath (Join-Path $project "CLAUDE.md")
  Safe-Symlink -Target $profileFile -LinkPath (Join-Path $project "GEMINI.md")
  Safe-Symlink -Target $memoryFile -LinkPath (Join-Path $project "MEMORY.md")
  Safe-Symlink -Target (Join-Path $script:AgentKitHome "SKILLS.md") -LinkPath (Join-Path $project "SKILLS.md")

  Copy-IfMissing -Source (Join-Path $script:AgentKitHome "templates/workitems/INDEX.md") -Destination (Join-Path $project "workitems/INDEX.md")
  Copy-IfMissing -Source (Join-Path $script:AgentKitHome "templates/workitems/template.md") -Destination (Join-Path $project "workitems/template.md")

  Write-StateFile -StateFile $stateFile -ProjectPath $project -Profile $profile -MemoryFile $memoryFile

  # --- MCP propagation via ruler ---
  Propagate-Mcp -ProjectPath $project

  Log "[done] bootstrap complete"
  return 0
}

function Propagate-Mcp {
  param([string]$ProjectPath)

  if ($script:NoMcp) {
    Log "[skip] MCP propagation disabled (--no-mcp)"
    return
  }

  $rulerSource = Join-Path $script:AgentKitHome ".ruler"
  $rulerToml = Join-Path $rulerSource "ruler.toml"
  if (-not (Test-Path -LiteralPath $rulerToml)) {
    Log "[skip] no .ruler/ruler.toml found in agent-kit"
    return
  }

  # find ruler binary
  $rulerBin = $null
  try {
    $rulerBin = (Get-Command ruler -ErrorAction SilentlyContinue).Source
  } catch {}
  if ([string]::IsNullOrWhiteSpace($rulerBin)) {
    $npmGlobalRuler = Join-Path $env:APPDATA "npm/ruler.cmd"
    if (Test-Path -LiteralPath $npmGlobalRuler) {
      $rulerBin = $npmGlobalRuler
    } else {
      Log "[skip] ruler not found in PATH - install with: npm install -g @intellectronica/ruler"
      return
    }
  }

  # symlink .ruler/ into project
  Safe-Symlink -Target $rulerSource -LinkPath (Join-Path $ProjectPath ".ruler")

  # collect server names for display
  $tomlContent = Get-Content -LiteralPath $rulerToml
  $serverNames = @()
  foreach ($line in $tomlContent) {
    if ($line -match '^\[mcp_servers\.(.+)\]') {
      $serverNames += $Matches[1]
    }
  }
  $serverList = $serverNames -join ", "

  # interactive mode: show servers and ask for confirmation
  # quiet/force mode (e.g. via wrapper): apply automatically with info line
  if (-not $script:Quiet -and -not $script:Force -and [Environment]::UserInteractive) {
    Log ""
    Log "[mcp] The following MCP servers will be configured:"
    foreach ($name in $serverNames) {
      Log "  - $name"
    }
    Log ""
    $answer = Read-Host "Apply MCP server configs to this project? [y/N]"
    if ($answer -notmatch '^[yYjJ]') {
      Log "[skip] MCP propagation declined by user"
      return
    }
  } else {
    # always show a brief info, even in quiet mode
    Write-Host "[mcp] configuring servers: $serverList"
  }

  # determine which agents to configure from agents.list
  $agentsListFile = Join-Path $script:AgentKitHome "config/agents.list"
  $rulerAgents = "claude,codex,gemini-cli,copilot"
  if (Test-Path -LiteralPath $agentsListFile) {
    $parsed = (Get-Content -LiteralPath $agentsListFile | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' }) -join ","
    if (-not [string]::IsNullOrWhiteSpace($parsed)) {
      $rulerAgents = $parsed
    }
  }

  if ($script:DryRun) {
    Log "[dry-run] ruler apply --mcp --no-skills --no-backup --agents $rulerAgents --project-root `"$ProjectPath`""
    return
  }

  Log "[mcp] running ruler apply ..."
  try {
    $output = & $rulerBin apply --mcp --no-skills --no-gitignore --no-backup --agents $rulerAgents 2>&1
    foreach ($line in $output) {
      Log "[ruler] $line"
    }
  } catch {
    Log "[warn] ruler apply failed: $($_.Exception.Message)"
  }
}

try {
  $exitCode = Main -CliArgs $script:CliArgs
  exit $exitCode
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
