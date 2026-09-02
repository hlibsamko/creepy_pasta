param(
    [string]$GodotExe = "",
    [string]$Preset = "Linux Dedicated Server"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $GodotExe) {
    $GodotExe = & (Join-Path $projectRoot "tools\engine\get_godot.ps1")
}
$buildDir = Join-Path $projectRoot "build\server"
$output = Join-Path $buildDir "creepy_pasta_server.x86_64"

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$stdoutPath = [System.IO.Path]::GetTempFileName()
$stderrPath = [System.IO.Path]::GetTempFileName()
try {
    $arguments = "--headless --path `"$projectRoot`" --export-release `"$Preset`" `"$output`""
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WorkingDirectory $projectRoot -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $exportOutput = (Get-Content -Raw -LiteralPath $stdoutPath) + (Get-Content -Raw -LiteralPath $stderrPath)
    $exportOutput | Write-Host
    if ($process.ExitCode -ne 0 -or $exportOutput -match "SCRIPT ERROR|ERROR: Failed|Parse Error") {
        throw "Godot export failed with exit code $($process.ExitCode)"
    }
}
finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Built $output"
