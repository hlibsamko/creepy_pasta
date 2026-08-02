param(
    [string]$GodotExe = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [string]$SiteDir = "D:\Codex_projects\creepy-website"
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "local_smoke.ps1") -GodotPath $GodotExe -SiteDir $SiteDir -Exports
& (Join-Path $PSScriptRoot "deploy_server.ps1")
& (Join-Path $PSScriptRoot "deploy_web_oracle.ps1") -SiteDir $SiteDir
