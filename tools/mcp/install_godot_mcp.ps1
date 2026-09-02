[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$releaseTag = "2026.09.02"
$wheelName = "godot_editor_mcp-2026.9.2-py3-none-any.whl"
$addonName = "godot_mcp_addon.zip"
$runtimePython = "C:\Users\Admin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$toolRoot = "C:\Users\Admin\.codex\tools\godot-editor-mcp\$releaseTag"
$venvPython = Join-Path $toolRoot ".venv\Scripts\python.exe"
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$addonDestination = Join-Path $projectRoot "addons\godot_mcp"

if (-not (Test-Path -LiteralPath $runtimePython -PathType Leaf)) {
    throw "The bundled Python runtime was not found: $runtimePython"
}
if (Test-Path -LiteralPath $addonDestination) {
    throw "Refusing to overwrite the existing addon directory: $addonDestination"
}

New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
    & $runtimePython -m venv (Join-Path $toolRoot ".venv")
}

$headers = @{ "User-Agent" = "Creepy-Pasta-Godot-MCP-Installer" }
$releaseUri = "https://api.github.com/repos/hybridindie/godot-mcp/releases/tags/$releaseTag"
$release = Invoke-RestMethod -Uri $releaseUri -Headers $headers
$wheel = @($release.assets | Where-Object name -EQ $wheelName)
$addon = @($release.assets | Where-Object name -EQ $addonName)
if ($wheel.Count -ne 1 -or $addon.Count -ne 1) {
    throw "The pinned MCP release does not contain the expected server and addon artifacts."
}

& $venvPython -m pip install $wheel[0].browser_download_url

$workDir = Join-Path ([IO.Path]::GetTempPath()) ("creepy-pasta-godot-mcp-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $workDir $addonName
$extractDir = Join-Path $workDir "extract"
New-Item -ItemType Directory -Path $workDir, $extractDir -Force | Out-Null
try {
    Invoke-WebRequest -Uri $addon[0].browser_download_url -Headers $headers -OutFile $archivePath
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir
    $plugin = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter "plugin.cfg" |
        Where-Object { $_.Directory.Name -eq "godot_mcp" } |
        Select-Object -First 1
    if (-not $plugin) {
        throw "The pinned addon archive does not contain godot_mcp/plugin.cfg."
    }
    New-Item -ItemType Directory -Path (Split-Path $addonDestination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $plugin.Directory.FullName -Destination $addonDestination -Recurse
}
finally {
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "MCP server: $toolRoot"
Write-Output "Godot addon: $addonDestination"
