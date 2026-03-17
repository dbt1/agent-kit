#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptPath = if ([string]::IsNullOrWhiteSpace($PSCommandPath)) { $MyInvocation.MyCommand.Definition } else { $PSCommandPath }
$ScriptName = Split-Path -Leaf $ScriptPath
$ScriptDir = Split-Path -Parent $ScriptPath
$ScriptArgs = $args
if ([string]::IsNullOrWhiteSpace($env:AGENT_KIT_HOME)) {
  $env:AGENT_KIT_HOME = (Resolve-Path (Join-Path $ScriptDir "..")).Path
}

$AgentKitHome = [System.IO.Path]::GetFullPath($env:AGENT_KIT_HOME)
$WrapperSource = Join-Path $AgentKitHome "bin/agent-wrapper.ps1"
$InstallDir = if ([string]::IsNullOrWhiteSpace($env:AGENT_KIT_INSTALL_DIR)) {
  Join-Path $HOME "AppData/Local/agent-kit/bin"
} else {
  $env:AGENT_KIT_INSTALL_DIR
}
$AgentListSample = Join-Path $AgentKitHome "config/agents.list.sample"
$PreferredAgentListFile = Join-Path $AgentKitHome "config/agents.list"
$FallbackAgentListFile = Join-Path $HOME ".config/agent-kit/agents.list"
$AgentListFile = ""
$ConfiguredAgents = New-Object System.Collections.Generic.List[string]
$ActivateProfile = $false

function Show-Usage {
  Write-Host @"
Usage: $ScriptName [--activate-profile]

Installs wrappers for configured agent commands into:
  $InstallDir

Agent list file (first match wins):
  AGENT_KIT_AGENT_LIST (if set)
  $PreferredAgentListFile (if writable)
  $FallbackAgentListFile (fallback)
"@
}

function Get-ProfilePath {
  if ($PROFILE -is [string]) {
    return $PROFILE
  }
  $property = $PROFILE.PSObject.Properties["CurrentUserCurrentHost"]
  if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace($property.Value)) {
    return [string]$property.Value
  }
  return [string]$PROFILE
}

function Parse-Args {
  param([string[]]$InputArgs)

  $i = 0
  while ($i -lt $InputArgs.Count) {
    $arg = $InputArgs[$i]
    switch ($arg) {
      "--activate-profile" {
        $script:ActivateProfile = $true
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

function Is-ValidAgentName {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }
  return $Value -match '^[A-Za-z0-9._+-]+$'
}

function Add-AgentUnique {
  param(
    [System.Collections.Generic.List[string]]$List,
    [string]$Name
  )
  if ($List.Contains($Name)) {
    return
  }
  $List.Add($Name)
}

function Get-AgentEntriesFromFile {
  param([string]$PathValue)

  if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
    return @()
  }

  $entries = New-Object System.Collections.Generic.List[string]
  foreach ($raw in Get-Content -LiteralPath $PathValue) {
    $line = [string]$raw
    $line = [regex]::Replace($line, "\r$", "")
    $line = [regex]::Replace($line, "\s*#.*$", "")
    $line = $line.Trim()
    if (-not [string]::IsNullOrWhiteSpace($line)) {
      $entries.Add($line)
    }
  }
  return @($entries)
}

function Resolve-AgentListFilePath {
  if (-not [string]::IsNullOrWhiteSpace($env:AGENT_KIT_AGENT_LIST)) {
    return $env:AGENT_KIT_AGENT_LIST
  }

  if (Test-Path -LiteralPath $PreferredAgentListFile -PathType Leaf) {
    return $PreferredAgentListFile
  }

  $preferredDir = Split-Path -Parent $PreferredAgentListFile
  try {
    New-Item -ItemType Directory -Path $preferredDir -Force | Out-Null
    $probe = Join-Path $preferredDir (".agent-kit-write-probe-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType File -Path $probe -Force | Out-Null
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    return $PreferredAgentListFile
  } catch {
    return $FallbackAgentListFile
  }
}

function Resolve-RealCommandPath {
  param([string]$CommandName)

  $agentKitBin = [System.IO.Path]::GetFullPath((Join-Path $AgentKitHome "bin"))
  $installDirFull = [System.IO.Path]::GetFullPath($InstallDir)
  $wrapperSourceFull = [System.IO.Path]::GetFullPath($WrapperSource)
  $candidates = Get-Command -Name $CommandName -All -ErrorAction SilentlyContinue
  foreach ($candidate in $candidates) {
    if ($candidate.CommandType -notin @("Application", "ExternalScript")) {
      continue
    }
    $path = $candidate.Path
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
      continue
    }

    $fullPath = [System.IO.Path]::GetFullPath($path)
    if ($fullPath.Equals($wrapperSourceFull, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }

    $installPrefix = "$installDirFull\"
    if ($fullPath.StartsWith($installPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }

    $agentKitPrefix = "$agentKitBin\"
    if ($fullPath.StartsWith($agentKitPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }

    return $fullPath
  }

  return $null
}

function Initialize-AgentListFile {
  if (Test-Path -LiteralPath $script:AgentListFile -PathType Leaf) {
    return
  }

  $candidates = New-Object System.Collections.Generic.List[string]
  foreach ($entry in (Get-AgentEntriesFromFile -PathValue $AgentListSample)) {
    if (-not (Is-ValidAgentName -Value $entry)) {
      Write-Warning "ignoring invalid agent name in sample: $entry"
      continue
    }
    Add-AgentUnique -List $candidates -Name $entry
  }

  if ($candidates.Count -eq 0) {
    foreach ($fallback in @("codex", "claude", "gemini")) {
      Add-AgentUnique -List $candidates -Name $fallback
    }
  }

  $detected = New-Object System.Collections.Generic.List[string]
  foreach ($candidate in $candidates) {
    if (-not [string]::IsNullOrWhiteSpace((Resolve-RealCommandPath -CommandName $candidate))) {
      Add-AgentUnique -List $detected -Name $candidate
    }
  }

  $selected = if ($detected.Count -gt 0) { $detected } else { $candidates }
  $listDir = Split-Path -Parent $script:AgentListFile
  if ([string]::IsNullOrWhiteSpace($listDir)) {
    $listDir = "."
  }
  New-Item -ItemType Directory -Path $listDir -Force | Out-Null

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# agent-kit local agent command list")
  $lines.Add("# generated: $(Get-Date -Format o)")
  $lines.Add("# one command name per line")
  $lines.Add("")
  foreach ($name in $selected) {
    $lines.Add($name)
  }
  Set-Content -LiteralPath $script:AgentListFile -Value $lines -Encoding ascii

  if ($detected.Count -gt 0) {
    Write-Host "initialized agent list: $($script:AgentListFile) (detected: $($selected -join ', '))"
  } else {
    Write-Host "initialized agent list: $($script:AgentListFile) (no command detected, using sample entries)"
  }
}

function Load-ConfiguredAgents {
  $script:ConfiguredAgents = New-Object System.Collections.Generic.List[string]
  if (-not (Test-Path -LiteralPath $script:AgentListFile -PathType Leaf)) {
    throw "missing agent list: $($script:AgentListFile)"
  }

  foreach ($entry in (Get-AgentEntriesFromFile -PathValue $script:AgentListFile)) {
    if (-not (Is-ValidAgentName -Value $entry)) {
      Write-Warning "ignoring invalid agent name in $($script:AgentListFile): $entry"
      continue
    }
    Add-AgentUnique -List $script:ConfiguredAgents -Name $entry
  }

  if ($script:ConfiguredAgents.Count -eq 0) {
    throw "no valid agent commands found in $($script:AgentListFile)"
  }
}

function Install-Wrappers {
  if (-not (Test-Path -LiteralPath $WrapperSource)) {
    throw "missing wrapper source: $WrapperSource"
  }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

  foreach ($cmd in $script:ConfiguredAgents) {
    $cmdShim = Join-Path $InstallDir "$cmd.cmd"
    $cmdContent = @"
@echo off
setlocal
set "AGENT_KIT_WRAPPER_DIR=$InstallDir"
set "AGENT_KIT_HOME_CURRENT="

if not "%AGENT_KIT_HOME%"=="" if exist "%AGENT_KIT_HOME%\bin\agent-wrapper.ps1" set "AGENT_KIT_HOME_CURRENT=%AGENT_KIT_HOME%"
if "%AGENT_KIT_HOME_CURRENT%"=="" if exist "$AgentKitHome\bin\agent-wrapper.ps1" set "AGENT_KIT_HOME_CURRENT=$AgentKitHome"
if "%AGENT_KIT_HOME_CURRENT%"=="" if exist "%USERPROFILE%\source\agent-kit\bin\agent-wrapper.ps1" set "AGENT_KIT_HOME_CURRENT=%USERPROFILE%\source\agent-kit"
if "%AGENT_KIT_HOME_CURRENT%"=="" if exist "%USERPROFILE%\sources\agent-kit\bin\agent-wrapper.ps1" set "AGENT_KIT_HOME_CURRENT=%USERPROFILE%\sources\agent-kit"
if "%AGENT_KIT_HOME_CURRENT%"=="" if exist "%USERPROFILE%\dev\agent-kit\bin\agent-wrapper.ps1" set "AGENT_KIT_HOME_CURRENT=%USERPROFILE%\dev\agent-kit"
if "%AGENT_KIT_HOME_CURRENT%"=="" if exist "C:\tools\agent-kit\bin\agent-wrapper.ps1" set "AGENT_KIT_HOME_CURRENT=C:\tools\agent-kit"
if "%AGENT_KIT_HOME_CURRENT%"=="" if exist "D:\tools\agent-kit\bin\agent-wrapper.ps1" set "AGENT_KIT_HOME_CURRENT=D:\tools\agent-kit"

if "%AGENT_KIT_HOME_CURRENT%"=="" (
  echo agent-kit wrapper: unable to locate AGENT_KIT_HOME 1>&2
  echo set AGENT_KIT_HOME or re-run install-auto-bootstrap.ps1 1>&2
  exit /b 1
)

set "AGENT_KIT_HOME=%AGENT_KIT_HOME_CURRENT%"
where pwsh >nul 2>nul
if %errorlevel%==0 (
  set "AGENT_KIT_PS=pwsh"
) else (
  set "AGENT_KIT_PS=powershell"
)
%AGENT_KIT_PS% -NoProfile -ExecutionPolicy Bypass -File "%AGENT_KIT_HOME_CURRENT%\bin\agent-wrapper.ps1" --agent "$cmd" %*
"@
    Set-Content -LiteralPath $cmdShim -Value $cmdContent -Encoding ascii

    $psShim = Join-Path $InstallDir "$cmd.ps1"
    $psContent = @"
`$env:AGENT_KIT_WRAPPER_DIR = "$InstallDir"
`$candidateHomes = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace(`$env:AGENT_KIT_HOME)) {
  `$candidateHomes.Add(`$env:AGENT_KIT_HOME)
}
`$candidateHomes.Add("$AgentKitHome")
`$candidateHomes.Add((Join-Path `$HOME "source/agent-kit"))
`$candidateHomes.Add((Join-Path `$HOME "sources/agent-kit"))
`$candidateHomes.Add((Join-Path `$HOME "dev/agent-kit"))
`$candidateHomes.Add("C:\tools\agent-kit")
`$candidateHomes.Add("D:\tools\agent-kit")

`$resolvedHome = `$null
foreach (`$candidate in `$candidateHomes) {
  if ([string]::IsNullOrWhiteSpace(`$candidate)) {
    continue
  }
  try {
    `$fullCandidate = [System.IO.Path]::GetFullPath(`$candidate)
  } catch {
    continue
  }
  if (Test-Path -LiteralPath (Join-Path `$fullCandidate "bin/agent-wrapper.ps1") -PathType Leaf) {
    `$resolvedHome = `$fullCandidate
    break
  }
}

if ([string]::IsNullOrWhiteSpace(`$resolvedHome)) {
  Write-Error "agent-kit wrapper: unable to locate AGENT_KIT_HOME. Set AGENT_KIT_HOME or re-run install-auto-bootstrap.ps1."
  exit 1
}

`$env:AGENT_KIT_HOME = `$resolvedHome
& (Join-Path `$resolvedHome "bin/agent-wrapper.ps1") --agent "$cmd" @args
exit `$LASTEXITCODE
"@
    Set-Content -LiteralPath $psShim -Value $psContent

    Write-Host "created: $cmdShim"
    Write-Host "created: $psShim"
  }
}

function Activate-ProfilePath {
  $profilePath = Get-ProfilePath
  $profileDir = Split-Path -Parent $profilePath
  if (-not (Test-Path -LiteralPath $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
  }

  $start = "# >>> agent-kit auto-bootstrap >>>"
  $end = "# <<< agent-kit auto-bootstrap <<<"

  if ((Test-Path -LiteralPath $profilePath) -and (Select-String -LiteralPath $profilePath -Pattern ([regex]::Escape($start)) -Quiet)) {
    Write-Host "PowerShell profile already contains agent-kit block"
    return
  }

$block = @"
$start
if (-not `$env:AGENT_KIT_HOME) {
  if (Test-Path "$AgentKitHome\bootstrap\bootstrap.ps1") {
    `$env:AGENT_KIT_HOME = "$AgentKitHome"
  }
}
if (Test-Path "$InstallDir") {
  `$pathParts = `$env:PATH -split ';'
  if (`$pathParts -notcontains "$InstallDir") {
    `$env:PATH = "$InstallDir;`$env:PATH"
  }
}
$end
"@

  Add-Content -LiteralPath $profilePath -Value "`n$block"
  Write-Host "added PATH block to $profilePath"
}

function Main {
  param([string[]]$CliArgs)

  if (-not (Parse-Args -InputArgs $CliArgs)) {
    return 0
  }

  $script:AgentListFile = Resolve-AgentListFilePath
  Initialize-AgentListFile
  Load-ConfiguredAgents
  Install-Wrappers
  Write-Host "agent list: $($script:AgentListFile)"

  if ($ActivateProfile) {
    Activate-ProfilePath
    Write-Host "Run: . $(Get-ProfilePath)"
  } else {
    Write-Host "To activate in current shell:"
    Write-Host "  `$env:PATH = `"$InstallDir;`$env:PATH`""
  }

  return 0
}

try {
  $exitCode = Main -CliArgs $ScriptArgs
  exit $exitCode
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
