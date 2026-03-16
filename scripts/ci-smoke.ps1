#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".."))
$BootstrapScript = Join-Path $RootDir "bootstrap/bootstrap.ps1"

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
$logSmoke = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-kit-smoke-" + [System.Guid]::NewGuid().ToString("N") + ".log")
$logStrict = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-kit-strict-" + [System.Guid]::NewGuid().ToString("N") + ".log")
$oldAgentKitHome = $env:AGENT_KIT_HOME
$oldStrict = $env:AGENT_KIT_STRICT_ISOLATION

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

  & $shellPath -NoProfile -File $BootstrapScript --project-root $tmpRepo *> $logSmoke
  if ($LASTEXITCODE -ne 0) {
    Write-Error "bootstrap smoke failed"
    Get-Content -LiteralPath $logSmoke | Write-Error
    exit 1
  }

  foreach ($path in @(
      "AGENTS.md",
      "CLAUDE.md",
      "GEMINI.md",
      "MEMORY.md",
      "SKILLS.md",
      "workitems/INDEX.md",
      "workitems/template.md",
      ".agent-workflow/state.env"
    )) {
    $fullPath = Join-Path $tmpRepo $path
    if (-not (Test-Path -LiteralPath $fullPath)) {
      Write-Error "expected path missing after bootstrap: $path"
      Write-Error "--- bootstrap log ---"
      Get-Content -LiteralPath $logSmoke | Write-Error
      Write-Error "--- repo tree ---"
      Get-ChildItem -LiteralPath $tmpRepo -Recurse -Force | ForEach-Object { $_.FullName } | Write-Error
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
  Remove-Item -LiteralPath $tmpRepo -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpBlock -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $logSmoke -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $logStrict -Force -ErrorAction SilentlyContinue
}
