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
$ActivateProfile = $false

function Show-Usage {
  Write-Host @"
Usage: $ScriptName [--activate-profile]

Installs wrappers for claude/codex/gemini into:
  $InstallDir
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

function Install-Wrappers {
  if (-not (Test-Path -LiteralPath $WrapperSource)) {
    throw "missing wrapper source: $WrapperSource"
  }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

  foreach ($cmd in @("claude", "codex", "gemini")) {
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

  Install-Wrappers

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
