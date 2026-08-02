param(
    [string]$GodotExe = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [string]$SiteDir = "D:\Codex_projects\creepy-website",
    [string]$Preset = "Web"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

New-Item -ItemType Directory -Force -Path $SiteDir | Out-Null

Get-ChildItem -LiteralPath $SiteDir -Force | Remove-Item -Recurse -Force

$output = Join-Path $SiteDir "index.html"
$stdoutPath = [System.IO.Path]::GetTempFileName()
$stderrPath = [System.IO.Path]::GetTempFileName()
try {
    $arguments = "--headless --path `"$projectRoot`" --export-release `"$Preset`" `"$output`""
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WorkingDirectory $projectRoot -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $exportOutput = (Get-Content -Raw -LiteralPath $stdoutPath) + (Get-Content -Raw -LiteralPath $stderrPath)
    $exportOutput | Write-Host
    if ($process.ExitCode -ne 0 -or $exportOutput -match "SCRIPT ERROR|ERROR: Failed|Parse Error") {
        throw "Godot Web export failed with exit code $($process.ExitCode)"
    }
}
finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Built Web site at $SiteDir"
