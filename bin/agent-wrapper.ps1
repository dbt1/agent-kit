#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptPath = if ([string]::IsNullOrWhiteSpace($PSCommandPath)) { $MyInvocation.MyCommand.Definition } else { $PSCommandPath }
$ScriptArgs = $args
$ScriptDir = Split-Path -Parent $ScriptPath
$ScriptName = Split-Path -Leaf $ScriptPath
if ([string]::IsNullOrWhiteSpace($env:AGENT_KIT_HOME)) {
  $env:AGENT_KIT_HOME = (Resolve-Path (Join-Path $ScriptDir "..")).Path
}

$AgentKitHome = [System.IO.Path]::GetFullPath($env:AGENT_KIT_HOME)
$BootstrapScript = Join-Path $AgentKitHome "bootstrap/bootstrap.ps1"
$CurrentScript = [System.IO.Path]::GetFullPath($ScriptPath)
$WrapperDir = if ([string]::IsNullOrWhiteSpace($env:AGENT_KIT_WRAPPER_DIR)) { "" } else { [System.IO.Path]::GetFullPath($env:AGENT_KIT_WRAPPER_DIR) }
$ForceRoots = [System.Environment]::GetEnvironmentVariable("AGENT_KIT_AUTOBOOTSTRAP_FORCE_ROOTS")
$AgentName = ""
$ForwardArgs = New-Object System.Collections.Generic.List[string]

function Show-Usage {
  Write-Host @"
Usage: $ScriptName --agent <name> [--] [args...]
"@
}

function Name-ToEnvSuffix {
  param([string]$Value)

  $upper = $Value.ToUpperInvariant()
  return [regex]::Replace($upper, "[^A-Z0-9]+", "_")
}

function Is-ExecutablePath {
  param([string]$PathValue)
  return -not [string]::IsNullOrWhiteSpace($PathValue) -and (Test-Path -LiteralPath $PathValue -PathType Leaf)
}

function Normalize-DirPath {
  param([string]$PathValue)

  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return $null
  }

  try {
    $fullPath = [System.IO.Path]::GetFullPath($PathValue).TrimEnd("\", "/")
    if ([string]::IsNullOrWhiteSpace($fullPath)) {
      return $null
    }
    return $fullPath
  } catch {
    return $null
  }
}

function Get-CurrentProjectRoot {
  $projectRoot = & git rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($projectRoot)) {
    return $null
  }
  return Normalize-DirPath -PathValue $projectRoot.Trim()
}

function Should-ForceBootstrap {
  if ([string]::IsNullOrWhiteSpace($ForceRoots)) {
    return $false
  }

  $projectRoot = Get-CurrentProjectRoot
  if ([string]::IsNullOrWhiteSpace($projectRoot)) {
    return $false
  }

  $separator = [regex]::Escape([string][System.IO.Path]::PathSeparator)
  foreach ($candidateRoot in ($ForceRoots -split $separator)) {
    $normalizedRoot = Normalize-DirPath -PathValue $candidateRoot.Trim()
    if ([string]::IsNullOrWhiteSpace($normalizedRoot)) {
      continue
    }
    if ($projectRoot.Equals($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function Get-RealCommand {
  param([string]$CommandName)

  $overrideEnv = "AGENT_KIT_REAL_$(Name-ToEnvSuffix -Value $CommandName)"
  $overridePath = [System.Environment]::GetEnvironmentVariable($overrideEnv)
  if (Is-ExecutablePath -PathValue $overridePath) {
    return [System.IO.Path]::GetFullPath($overridePath)
  }

  $agentKitBin = [System.IO.Path]::GetFullPath((Join-Path $AgentKitHome "bin"))
  $candidates = Get-Command -Name $CommandName -All -ErrorAction SilentlyContinue
  foreach ($candidate in $candidates) {
    if ($candidate.CommandType -notin @("Application", "ExternalScript")) {
      continue
    }
    $path = $candidate.Path
    if (-not (Is-ExecutablePath -PathValue $path)) {
      continue
    }

    $fullPath = [System.IO.Path]::GetFullPath($path)
    if ($fullPath.Equals($CurrentScript, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }

    if (-not [string]::IsNullOrWhiteSpace($WrapperDir)) {
      $wrapperPrefix = "$WrapperDir\"
      if ($fullPath.StartsWith($wrapperPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.Equals($WrapperDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        continue
      }
    }

    $agentKitPrefix = "$agentKitBin\"
    if ($fullPath.StartsWith($agentKitPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }

    return $fullPath
  }

  return $null
}

function Parse-Args {
  param([string[]]$InputArgs)

  $i = 0
  while ($i -lt $InputArgs.Count) {
    $arg = $InputArgs[$i]
    switch ($arg) {
      "--agent" {
        if ($i + 1 -ge $InputArgs.Count) {
          throw "missing value for --agent"
        }
        $script:AgentName = $InputArgs[$i + 1]
        $i += 2
      }
      "--" {
        for ($j = $i + 1; $j -lt $InputArgs.Count; $j++) {
          $script:ForwardArgs.Add($InputArgs[$j])
        }
        return $true
      }
      default {
        $script:ForwardArgs.Add($arg)
        $i += 1
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

  if ([string]::IsNullOrWhiteSpace($AgentName)) {
    $invokedName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    if (-not [string]::IsNullOrWhiteSpace($invokedName) -and $invokedName -ne "agent-wrapper") {
      $AgentName = $invokedName
    }
  }
  if ([string]::IsNullOrWhiteSpace($AgentName)) {
    throw "agent-wrapper: missing --agent <name>"
  }

  if ($env:AGENT_KIT_AUTOBOOTSTRAP -ne "0" -and (Test-Path -LiteralPath $BootstrapScript)) {
    try {
      $shellPath = (Get-Process -Id $PID).Path
      $bootstrapArgs = @("-NoProfile", "-File", $BootstrapScript, "--agent", $AgentName, "--quiet")
      if (Should-ForceBootstrap) {
        $bootstrapArgs += "--force"
      }
      & $shellPath @bootstrapArgs *> $null
    } catch {
      # Keep wrapper execution resilient even if bootstrap fails.
    }
  }

  $realCommand = Get-RealCommand -CommandName $AgentName
  if ([string]::IsNullOrWhiteSpace($realCommand)) {
    Write-Error "agent-wrapper: unable to resolve real command for '$AgentName'"
    return 127
  }

  & $realCommand @ForwardArgs
  return $LASTEXITCODE
}

try {
  $exitCode = Main -CliArgs $ScriptArgs
  if ($null -eq $exitCode) {
    $exitCode = 0
  }
  exit $exitCode
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
