param(
    [string]$GodotExe = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [string]$SiteDir = "D:\Codex_projects\creepy-website",
    [string]$Preset = "Web"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$sitePath = [IO.Path]::GetFullPath($SiteDir).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$siteRoot = [IO.Path]::GetPathRoot($sitePath).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$projectPath = [string]$projectRoot
if ($sitePath -eq $siteRoot -or $sitePath -eq $projectPath -or $projectPath.StartsWith($sitePath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a drive root, project root, or project ancestor as the Web export directory: $sitePath"
}

New-Item -ItemType Directory -Force -Path $sitePath | Out-Null

$existingEntries = @(Get-ChildItem -LiteralPath $sitePath -Force)
$unexpectedEntries = @($existingEntries | Where-Object { $_.Name -notlike "index.*" })
if ($unexpectedEntries.Count -gt 0) {
    $names = ($unexpectedEntries | ForEach-Object Name) -join ", "
    throw "Refusing to clean a Web export directory containing non-Godot entries: $names"
}
$existingEntries | Remove-Item -Recurse -Force

$output = Join-Path $sitePath "index.html"
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

$indexHtml = [IO.File]::ReadAllText($output)
if ($indexHtml -notmatch 'id="creepy-pasta-policy-links"') {
    $policyLinks = @'
<nav id="creepy-pasta-policy-links" aria-label="Account policies" style="position:fixed;right:12px;bottom:8px;z-index:2147483647;font:12px sans-serif"><a href="/privacy" target="_blank" rel="noopener noreferrer" style="color:#d8c8aa">Privacy</a><span aria-hidden="true" style="color:#8f816b"> · </span><a href="/terms" target="_blank" rel="noopener noreferrer" style="color:#d8c8aa">Terms</a></nav>
'@
    if (-not $indexHtml.Contains("</body>")) {
        throw "Godot Web export has no closing body tag for account policy links."
    }
    $indexHtml = $indexHtml.Replace("</body>", "$policyLinks`n</body>")
    [IO.File]::WriteAllText($output, $indexHtml, [Text.UTF8Encoding]::new($false))
}

Write-Host "Built Web site at $sitePath"
