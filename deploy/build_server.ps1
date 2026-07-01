param(
    [string]$GodotExe = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [string]$Preset = "Linux Dedicated Server"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$buildDir = Join-Path $projectRoot "build\server"
$output = Join-Path $buildDir "creepy_pasta_server.x86_64"

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

& $GodotExe --headless --path $projectRoot --export-release $Preset $output
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Godot export failed with exit code $LASTEXITCODE"
}

Write-Host "Built $output"
