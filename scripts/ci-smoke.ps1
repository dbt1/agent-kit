#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".."))
$BootstrapScript = Join-Path $RootDir "bootstrap/bootstrap.ps1"
$InstallScript = Join-Path $RootDir "bootstrap/install-auto-bootstrap.ps1"

function Assert-PowerShellSyntax {
  param([string]$PathValue)

  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($PathValue, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    $messages = $errors | ForEach-Object {
      "$($_.Message) at $($_.Extent.File):$($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber)"
    }
    throw "syntax check failed for $PathValue`n$($messages -join "`n")"
  }
}

function New-TempDir {
  $path = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-kit-smoke-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $path | Out-Null
  return $path
}

function Restore-Env {
  param(
    [string]$Name,
    [string]$PreviousValue
  )

  if ($null -eq $PreviousValue) {
    Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
  } else {
    Set-Item "Env:$Name" $PreviousValue
  }
}

$tmpRepo = New-TempDir
$tmpBlock = New-TempDir
$tmpInstall = New-TempDir
$tmpAgentList = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-kit-agents-" + [System.Guid]::NewGuid().ToString("N") + ".list")
$tmpHostMapDir = Join-Path $RootDir "config/project-map"
$tmpHostMap = Join-Path $tmpHostMapDir "smoke-host.tsv"
$tmpHostMapOther = Join-Path $tmpHostMapDir "other-host.tsv"
$tmpMemoryRoot = Join-Path $RootDir "memory/projects/smoke-project"
$tmpActiveRoot = Join-Path $RootDir "workitems/active/smoke-project"
$logSmoke = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-kit-smoke-" + [System.Guid]::NewGuid().ToString("N") + ".log")
$logStrict = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-kit-strict-" + [System.Guid]::NewGuid().ToString("N") + ".log")
$logInstall = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-kit-install-" + [System.Guid]::NewGuid().ToString("N") + ".log")
$oldAgentKitHome = $env:AGENT_KIT_HOME
$oldStrict = $env:AGENT_KIT_STRICT_ISOLATION
$oldHostId = $env:AGENT_KIT_HOST_ID
$oldInstallDir = $env:AGENT_KIT_INSTALL_DIR
$oldAgentList = $env:AGENT_KIT_AGENT_LIST

try {
  foreach ($relativeScript in @(
      "bin/agent-wrapper.ps1",
      "bootstrap/bootstrap.ps1",
      "bootstrap/bootstrap-all.ps1",
      "bootstrap/install-auto-bootstrap.ps1",
      "scripts/ci-smoke.ps1"
    )) {
    Assert-PowerShellSyntax -PathValue (Join-Path $RootDir $relativeScript)
  }

  & git -C $tmpRepo init -q
  if ($LASTEXITCODE -ne 0) {
    throw "git init failed for smoke repo: $tmpRepo"
  }

  $shellPath = (Get-Process -Id $PID).Path
  $env:AGENT_KIT_HOME = $RootDir
  $env:AGENT_KIT_STRICT_ISOLATION = "1"
  $env:AGENT_KIT_HOST_ID = "smoke-host"
  New-Item -ItemType Directory -Path $tmpHostMapDir -Force | Out-Null
  Set-Content -LiteralPath $tmpHostMap -Value "$tmpRepo`tgeneric`tsmoke-project"
  Set-Content -LiteralPath $tmpHostMapOther -Value "$tmpRepo`tgeneric`tsmoke-project"

  & $shellPath -NoProfile -File $BootstrapScript --project-root $tmpRepo *> $logSmoke
  if ($LASTEXITCODE -ne 0) {
    Write-Error "bootstrap smoke failed"
    Get-Content -LiteralPath $logSmoke | Write-Error
    exit 1
  }

  foreach ($path in @(
      (Join-Path $RootDir "memory/projects/smoke-project/shared.md"),
      (Join-Path $RootDir "memory/projects/smoke-project/hosts/smoke-host.md"),
      (Join-Path $RootDir "memory/projects/smoke-project/index/smoke-host.md"),
      (Join-Path $RootDir "workitems/active/smoke-project"),
      "AGENTS.md",
      "CLAUDE.md",
      "GEMINI.md",
      "MEMORY.md",
      "SKILLS.md",
      "workitems/INDEX.md",
      "workitems/template.md",
      ".agent-workflow/state.env"
    )) {
    $fullPath = if ([System.IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $tmpRepo $path }
    if (-not (Test-Path -LiteralPath $fullPath)) {
      Write-Error "expected path missing after bootstrap: $path"
      Write-Error "--- bootstrap log ---"
      Get-Content -LiteralPath $logSmoke | Write-Error
      Write-Error "--- repo tree ---"
      Get-ChildItem -LiteralPath $tmpRepo -Recurse -Force | ForEach-Object { $_.FullName } | Write-Error
      exit 1
    }
  }

  $stateFile = Join-Path $tmpRepo ".agent-workflow/state.env"
  if (-not (Select-String -LiteralPath $stateFile -Pattern '^HOST_ID=smoke-host$' -Quiet)) {
    Write-Error "HOST_ID missing in state.env"
    Get-Content -LiteralPath $stateFile | Write-Error
    exit 1
  }
  if (-not (Select-String -LiteralPath $stateFile -Pattern '^PROJECT_ID=smoke-project$' -Quiet)) {
    Write-Error "PROJECT_ID missing in state.env"
    Get-Content -LiteralPath $stateFile | Write-Error
    exit 1
  }
  if (-not (Select-String -LiteralPath $stateFile -Pattern ([regex]::Escape("ACTIVE_WORK_DIR=$tmpActiveRoot")) -Quiet)) {
    Write-Error "ACTIVE_WORK_DIR missing in state.env"
    Get-Content -LiteralPath $stateFile | Write-Error
    exit 1
  }
  $memoryIndex = Join-Path $RootDir "memory/projects/smoke-project/index/smoke-host.md"
  if (-not (Select-String -LiteralPath $memoryIndex -Pattern '^## Active Work$' -Quiet)) {
    Write-Error "Active Work section missing in memory index"
    Get-Content -LiteralPath $memoryIndex | Write-Error
    exit 1
  }
  if (-not (Select-String -LiteralPath $memoryIndex -Pattern ([regex]::Escape($tmpActiveRoot)) -Quiet)) {
    Write-Error "Active Work directory missing in memory index"
    Get-Content -LiteralPath $memoryIndex | Write-Error
    exit 1
  }

  $env:AGENT_KIT_HOST_ID = "other-host"
  & $shellPath -NoProfile -File $BootstrapScript --project-root $tmpRepo --force *> $logSmoke
  if ($LASTEXITCODE -ne 0) {
    Write-Error "second-host bootstrap smoke failed"
    Get-Content -LiteralPath $logSmoke | Write-Error
    exit 1
  }

  foreach ($path in @(
      (Join-Path $RootDir "memory/projects/smoke-project/hosts/other-host.md"),
      (Join-Path $RootDir "memory/projects/smoke-project/index/other-host.md")
    )) {
    if (-not (Test-Path -LiteralPath $path)) {
      Write-Error "expected second host memory path missing: $path"
      Get-ChildItem -LiteralPath $tmpMemoryRoot -Recurse -Force | ForEach-Object { $_.FullName } | Write-Error
      exit 1
    }
  }

  $env:AGENT_KIT_INSTALL_DIR = $tmpInstall
  $env:AGENT_KIT_AGENT_LIST = $tmpAgentList
  & $shellPath -NoProfile -File $InstallScript *> $logInstall
  if ($LASTEXITCODE -ne 0) {
    Write-Error "install-auto-bootstrap smoke failed"
    Get-Content -LiteralPath $logInstall | Write-Error
    exit 1
  }

  if (-not (Test-Path -LiteralPath $tmpAgentList -PathType Leaf)) {
    Write-Error "expected generated agent list missing: $tmpAgentList"
    Get-Content -LiteralPath $logInstall | Write-Error
    exit 1
  }

  $configuredAgents = New-Object System.Collections.Generic.List[string]
  foreach ($raw in Get-Content -LiteralPath $tmpAgentList) {
    $line = [string]$raw
    $line = [regex]::Replace($line, "\r$", "")
    $line = [regex]::Replace($line, "\s*#.*$", "")
    $line = $line.Trim()
    if (-not [string]::IsNullOrWhiteSpace($line)) {
      if (-not $configuredAgents.Contains($line)) {
        $configuredAgents.Add($line)
      }
    }
  }

  if ($configuredAgents.Count -eq 0) {
    Write-Error "generated agent list does not contain usable entries"
    Get-Content -LiteralPath $tmpAgentList | Write-Error
    Get-Content -LiteralPath $logInstall | Write-Error
    exit 1
  }

  foreach ($agent in $configuredAgents) {
    $cmdShim = Join-Path $tmpInstall "$agent.cmd"
    $psShim = Join-Path $tmpInstall "$agent.ps1"
    if (-not (Test-Path -LiteralPath $cmdShim -PathType Leaf)) {
      Write-Error "expected cmd wrapper missing for configured agent '$agent'"
      Get-Content -LiteralPath $logInstall | Write-Error
      Get-ChildItem -LiteralPath $tmpInstall -Force | ForEach-Object { $_.FullName } | Write-Error
      exit 1
    }
    if (-not (Test-Path -LiteralPath $psShim -PathType Leaf)) {
      Write-Error "expected powershell wrapper missing for configured agent '$agent'"
      Get-Content -LiteralPath $logInstall | Write-Error
      Get-ChildItem -LiteralPath $tmpInstall -Force | ForEach-Object { $_.FullName } | Write-Error
      exit 1
    }
  }

  & git -C $tmpBlock init -q
  if ($LASTEXITCODE -ne 0) {
    throw "git init failed for strict repo: $tmpBlock"
  }
  Set-Content -LiteralPath (Join-Path $tmpBlock "AGENTS.md") -Value "legacy"

  & $shellPath -NoProfile -File $BootstrapScript --project-root $tmpBlock *> $logStrict
  if ($LASTEXITCODE -eq 0) {
    Write-Error "strict isolation expected to block but command succeeded"
    Get-Content -LiteralPath $logStrict | Write-Error
    exit 1
  }

  if (-not (Select-String -LiteralPath $logStrict -Pattern "strict isolation|unmanaged existing" -Quiet)) {
    Write-Error "strict isolation failure message missing"
    Get-Content -LiteralPath $logStrict | Write-Error
    exit 1
  }

  Write-Output "ci-smoke: ok"
} finally {
  Restore-Env -Name "AGENT_KIT_HOME" -PreviousValue $oldAgentKitHome
  Restore-Env -Name "AGENT_KIT_STRICT_ISOLATION" -PreviousValue $oldStrict
  Restore-Env -Name "AGENT_KIT_HOST_ID" -PreviousValue $oldHostId
  Restore-Env -Name "AGENT_KIT_INSTALL_DIR" -PreviousValue $oldInstallDir
  Restore-Env -Name "AGENT_KIT_AGENT_LIST" -PreviousValue $oldAgentList
  Remove-Item -LiteralPath $tmpRepo -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpBlock -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpInstall -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpMemoryRoot -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpActiveRoot -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpHostMap -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpHostMapOther -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpAgentList -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $logSmoke -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $logStrict -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $logInstall -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $tmpHostMapDir) {
    $remainingHostMapEntries = @(Get-ChildItem -LiteralPath $tmpHostMapDir -Force -ErrorAction SilentlyContinue)
    if ($remainingHostMapEntries.Count -eq 0) {
      Remove-Item -LiteralPath $tmpHostMapDir -Force -ErrorAction SilentlyContinue
    }
  }
  $activeRootParent = Join-Path $RootDir "workitems/active"
  if (Test-Path -LiteralPath $activeRootParent) {
    $remainingActiveEntries = @(Get-ChildItem -LiteralPath $activeRootParent -Force -ErrorAction SilentlyContinue)
    if ($remainingActiveEntries.Count -eq 0) {
      Remove-Item -LiteralPath $activeRootParent -Force -ErrorAction SilentlyContinue
    }
  }
}
