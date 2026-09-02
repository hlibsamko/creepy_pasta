[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$pin = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "godot-version.json") | ConvertFrom-Json

if ($env:CREEPY_PASTA_GODOT_BIN) {
    $override = [IO.Path]::GetFullPath($env:CREEPY_PASTA_GODOT_BIN)
    if (-not (Test-Path -LiteralPath $override -PathType Leaf)) {
        throw "CREEPY_PASTA_GODOT_BIN does not point to a file: $override"
    }
    return $override
}

$workspaceEngineDir = [IO.Path]::GetFullPath((Join-Path $projectRoot "..\.."))
$candidate = Join-Path $workspaceEngineDir $pin.executable
if (Test-Path -LiteralPath $candidate -PathType Leaf) {
    return $candidate
}

throw "Godot $($pin.version) was not found at $candidate. Run tools/engine/update_godot.ps1."
