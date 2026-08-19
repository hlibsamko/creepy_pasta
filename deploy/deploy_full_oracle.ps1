param(
    [string]$GodotExe = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [string]$PythonExe = "python",
    [string]$SiteDir = "D:\Codex_projects\creepy-website",
    [string]$AccountEnvPath = ""
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "local_smoke.ps1") -GodotPath $GodotExe -SiteDir $SiteDir -Exports
$accountDeployArguments = @{ "PythonExe" = $PythonExe }
if ($AccountEnvPath -ne "") {
    $accountDeployArguments["LocalEnvPath"] = $AccountEnvPath
}
& (Join-Path $PSScriptRoot "deploy_account.ps1") @accountDeployArguments
& (Join-Path $PSScriptRoot "deploy_server.ps1")
& (Join-Path $PSScriptRoot "deploy_web_oracle.ps1") -SiteDir $SiteDir
& (Join-Path $PSScriptRoot "smoke_account.ps1")
& (Join-Path $PSScriptRoot "smoke_test_server.ps1")
