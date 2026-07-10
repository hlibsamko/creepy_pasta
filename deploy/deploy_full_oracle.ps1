param(
    [string]$GodotExe = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [string]$SiteDir = "D:\Codex_projects\creepy-website"
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "build_web_site.ps1") -GodotExe $GodotExe -SiteDir $SiteDir
& $GodotExe --headless --path (Resolve-Path (Join-Path $PSScriptRoot "..")) --export-release "Linux Dedicated Server" "build\server\creepy_pasta_server.x86_64"
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Godot dedicated server export failed with exit code $LASTEXITCODE"
}
& (Join-Path $PSScriptRoot "deploy_server.ps1")
& (Join-Path $PSScriptRoot "deploy_web_oracle.ps1") -SiteDir $SiteDir
