param(
    [string]$GodotPath = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [switch]$Exports
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Invoke-GodotCheck {
    param(
        [string[]]$Arguments,
        [string]$Name
    )

    Write-Host "== $Name =="
    $output = & $GodotPath --headless --path $projectRoot @Arguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    $output | Write-Host
    if ($output -match "SCRIPT ERROR|ERROR: Failed|Parse Error") {
        throw "$Name failed; Godot reported script/load errors."
    }
    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode"
    }
}

Invoke-GodotCheck -Name "Project parse" -Arguments @("--quit")
Invoke-GodotCheck -Name "Main scene smoke" -Arguments @("--quit-after", "2", "res://scenes/main.tscn")
Invoke-GodotCheck -Name "UI scene smoke" -Arguments @("--quit-after", "2", "res://scenes/game_ui.tscn")
Invoke-GodotCheck -Name "Backrooms builder smoke" -Arguments @("--quit-after", "2", "res://scenes/backrooms/backrooms_builder_demo.tscn")
Invoke-GodotCheck -Name "Dedicated startup smoke" -Arguments @("--server", "--quit-after", "2")

$scripts = @(
    "deploy\deploy_server.ps1",
    "deploy\deploy_web_oracle.ps1",
    "deploy\rollback_oracle.ps1",
    "deploy\deploy_full_oracle.ps1",
    "deploy\build_web_site.ps1"
)

foreach ($scriptPath in $scripts) {
    $fullPath = Join-Path $projectRoot $scriptPath
    $script = Get-Content -Raw -LiteralPath $fullPath
    [scriptblock]::Create($script) | Out-Null
    Write-Host "== $scriptPath syntax OK =="
}

if ($Exports) {
    Invoke-GodotCheck -Name "Linux dedicated export" -Arguments @("--export-release", "Linux Dedicated Server", "build\server\creepy_pasta_server.x86_64")
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot "deploy\build_web_site.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "Web build failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Local smoke checks passed."
