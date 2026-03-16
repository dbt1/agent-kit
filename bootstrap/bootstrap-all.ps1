#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptPath = if ([string]::IsNullOrWhiteSpace($PSCommandPath)) { $MyInvocation.MyCommand.Definition } else { $PSCommandPath }
$ScriptName = Split-Path -Leaf $ScriptPath
$ScriptDir = Split-Path -Parent $ScriptPath
$ScriptArgs = $args
$BootstrapScript = Join-Path $ScriptDir "bootstrap.ps1"
$PathSeparator = [System.IO.Path]::PathSeparator
$Roots = if ([string]::IsNullOrWhiteSpace($env:AGENT_KIT_PROJECT_ROOTS)) {
  "$HOME/sources$PathSeparator$HOME/source"
} else {
  $env:AGENT_KIT_PROJECT_ROOTS
}
$DryRun = $false
$Force = $false

function Show-Usage {
  Write-Host @"
Usage: $ScriptName [--dry-run] [--force] [--roots path1$PathSeparator path2]
"@
}

function Parse-Args {
  param([string[]]$InputArgs)

  $i = 0
  while ($i -lt $InputArgs.Count) {
    $arg = $InputArgs[$i]
    switch ($arg) {
      "--dry-run" {
        $script:DryRun = $true
        $i += 1
      }
      "--force" {
        $script:Force = $true
        $i += 1
      }
      "--roots" {
        if ($i + 1 -ge $InputArgs.Count) {
          throw "missing value for --roots"
        }
        $script:Roots = $InputArgs[$i + 1]
        $i += 2
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

  $shellPath = (Get-Process -Id $PID).Path
  foreach ($root in ($Roots -split [regex]::Escape([string]$PathSeparator))) {
    $trimmedRoot = $root.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedRoot)) {
      continue
    }
    if (-not (Test-Path -LiteralPath $trimmedRoot -PathType Container)) {
      continue
    }

    foreach ($project in Get-ChildItem -LiteralPath $trimmedRoot -Directory -ErrorAction SilentlyContinue) {
      $gitPath = Join-Path $project.FullName ".git"
      if (-not (Test-Path -LiteralPath $gitPath)) {
        continue
      }

      $invokeArgs = @("-NoProfile", "-File", $BootstrapScript, "--project-root", $project.FullName)
      if ($DryRun) {
        $invokeArgs += "--dry-run"
      }
      if ($Force) {
        $invokeArgs += "--force"
      }

      & $shellPath @invokeArgs
      if ($LASTEXITCODE -ne 0) {
        return $LASTEXITCODE
      }
    }
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
