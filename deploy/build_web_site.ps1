param(
    [string]$GodotExe = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [string]$SiteDir = "D:\Codex_projects\my-website",
    [string]$Preset = "Web"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

New-Item -ItemType Directory -Force -Path $SiteDir | Out-Null

Get-ChildItem -LiteralPath $SiteDir -Force | Remove-Item -Recurse -Force

$output = Join-Path $SiteDir "index.html"
& $GodotExe --headless --path $projectRoot --export-release $Preset $output
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Godot Web export failed with exit code $LASTEXITCODE"
}

Write-Host "Built Web site at $SiteDir"
