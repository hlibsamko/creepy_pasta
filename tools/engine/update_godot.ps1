[CmdletBinding()]
param(
    [switch]$RemoveOlderPinnedExecutables,
    [switch]$InstallExportTemplates
)

$ErrorActionPreference = "Stop"

$pinPath = Join-Path $PSScriptRoot "godot-version.json"
$pin = Get-Content -Raw -LiteralPath $pinPath | ConvertFrom-Json
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$engineDir = [IO.Path]::GetFullPath((Join-Path $projectRoot "..\.."))
$expectedEngineDir = [IO.Path]::GetFullPath("D:\Soft\Godot_4.6")
if (-not $engineDir.Equals($expectedEngineDir, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to install outside the expected engine directory: $engineDir"
}

$headers = @{ "User-Agent" = "Creepy-Pasta-Godot-Updater" }
$releaseUri = "https://api.github.com/repos/$($pin.repository)/releases/tags/$($pin.version)"
$release = Invoke-RestMethod -Uri $releaseUri -Headers $headers
$asset = @($release.assets | Where-Object name -EQ $pin.asset)
if ($asset.Count -ne 1) {
    throw "Expected exactly one official release asset named $($pin.asset); found $($asset.Count)."
}
$templatesAsset = @()
if ($InstallExportTemplates) {
    $templatesAsset = @($release.assets | Where-Object name -EQ $pin.export_templates_asset)
    if ($templatesAsset.Count -ne 1) {
        throw "Expected exactly one official release asset named $($pin.export_templates_asset); found $($templatesAsset.Count)."
    }
}

$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$workDir = [IO.Path]::GetFullPath((Join-Path $tempRoot ("creepy-pasta-godot-" + [guid]::NewGuid().ToString("N"))))
if (-not $workDir.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a temporary directory outside the system temp root: $workDir"
}
$archivePath = Join-Path $workDir $pin.asset
$extractDir = Join-Path $workDir "extract"
$destination = Join-Path $engineDir $pin.executable

New-Item -ItemType Directory -Path $workDir, $extractDir -Force | Out-Null
try {
    Invoke-WebRequest -Uri $asset[0].browser_download_url -Headers $headers -OutFile $archivePath
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir
    $source = Get-ChildItem -LiteralPath $extractDir -Recurse -File | Where-Object Name -EQ $pin.executable | Select-Object -First 1
    if (-not $source) {
        throw "The official archive did not contain $($pin.executable)."
    }
    Move-Item -LiteralPath $source.FullName -Destination $destination -Force

    if ($InstallExportTemplates) {
        $templatesArchivePath = Join-Path $workDir $pin.export_templates_asset
        $templatesExtractDir = Join-Path $workDir "export_templates"
        New-Item -ItemType Directory -Path $templatesExtractDir -Force | Out-Null
        Invoke-WebRequest -Uri $templatesAsset[0].browser_download_url -Headers $headers -OutFile $templatesArchivePath
        Expand-Archive -LiteralPath $templatesArchivePath -DestinationPath $templatesExtractDir
        $templatesSource = Get-ChildItem -LiteralPath $templatesExtractDir -Directory -Filter "templates" -Recurse | Select-Object -First 1
        if (-not $templatesSource) {
            throw "The official template archive did not contain a templates directory."
        }
        $templateVersion = $pin.version.Replace("-", ".")
        $templatesDestination = Join-Path $env:APPDATA "Godot\export_templates\$templateVersion"
        New-Item -ItemType Directory -Path $templatesDestination -Force | Out-Null
        Copy-Item -Path (Join-Path $templatesSource.FullName "*") -Destination $templatesDestination -Recurse -Force
        Write-Output $templatesDestination
    }

    if ($RemoveOlderPinnedExecutables) {
        $olderExecutables = Get-ChildItem -LiteralPath $engineDir -File -Filter "Godot_v*-stable_win64.exe" |
            Where-Object { -not $_.FullName.Equals($destination, [StringComparison]::OrdinalIgnoreCase) }
        foreach ($olderExecutable in $olderExecutables) {
            try {
                Remove-Item -LiteralPath $olderExecutable.FullName -Force
            }
            catch {
                Write-Warning "Godot was updated, but the older executable is still locked: $($olderExecutable.FullName)"
            }
        }
    }
}
finally {
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output $destination
