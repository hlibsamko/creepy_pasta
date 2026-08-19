param(
    [string]$GodotPath = "D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe",
    [string]$SiteDir = "D:\Codex_projects\creepy-website",
    [switch]$Exports,
    [switch]$NetworkOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Invoke-GodotCheck {
    param(
        [string[]]$Arguments,
        [string]$Name
    )

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        Write-Host "== $Name =="
        $godotArguments = @("--headless", "--path", [string]$projectRoot) + $Arguments
        $argumentString = ($godotArguments | ForEach-Object {
            $value = [string]$_
            if ($value -match '\s') { '"' + $value.Replace('"', '\"') + '"' } else { $value }
        }) -join " "
        $process = Start-Process -FilePath $GodotPath -ArgumentList $argumentString -WorkingDirectory $projectRoot -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $output = @()
        $output += Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
        $output += Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue
        $output | Write-Host
        $outputText = $output -join [Environment]::NewLine
        if ($outputText -match "(?m)^(SCRIPT ERROR|ERROR:)|Parse Error") {
            throw "$Name failed; Godot reported script/load errors."
        }
        if ($process.ExitCode -ne 0) {
            throw "$Name failed with exit code $($process.ExitCode)"
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-NetworkSessionCheck {
    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    $clientOut = [System.IO.Path]::GetTempFileName()
    $clientErr = [System.IO.Path]::GetTempFileName()
    $server = $null
    try {
        Write-Host "== Network note/journal/reset smoke =="
        $serverArguments = "--headless --path `"$projectRoot`" --server --account-auth-test-mode"
        $server = Start-Process -FilePath $GodotPath -ArgumentList $serverArguments -WorkingDirectory $projectRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        Start-Sleep -Seconds 2
        if ($server.HasExited) {
            throw "Network smoke server exited before the client connected."
        }
        Write-Host "== Network session client =="
        $clientArguments = "--headless --path `"$projectRoot`" --quit-after 20000 res://scenes/smoke/network_note_smoke.tscn"
        $client = Start-Process -FilePath $GodotPath -ArgumentList $clientArguments -WorkingDirectory $projectRoot -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $clientOut -RedirectStandardError $clientErr
        $clientOutput = @()
        $clientOutput += Get-Content -LiteralPath $clientOut -ErrorAction SilentlyContinue
        $clientOutput += Get-Content -LiteralPath $clientErr -ErrorAction SilentlyContinue
        $clientOutput | Write-Host
        $clientText = $clientOutput -join [Environment]::NewLine
        if ($client.ExitCode -ne 0 -or $clientText -notmatch "Session create, House and Unlit sync, Restart, and isolated reset kept server alive") {
            throw "Network session client did not complete the expected scenario."
        }
        if ($clientText -match "(?m)^(SCRIPT ERROR|ERROR:)|Parse Error") {
            throw "Network session client reported an error."
        }
        if ($server.HasExited) {
            throw "Network smoke server exited during the client scenario."
        }
        $serverOutput = (Get-Content -Raw -LiteralPath $stdoutPath) + (Get-Content -Raw -LiteralPath $stderrPath)
        $serverOutput | Write-Host
        if ($serverOutput -match "(?m)^(SCRIPT ERROR|ERROR:)|Parse Error") {
            throw "Network smoke server reported an error."
        }
    }
    finally {
        if ($server -and -not $server.HasExited) {
            Stop-Process -Id $server.Id -ErrorAction SilentlyContinue
            $server.WaitForExit()
        }
        Remove-Item -LiteralPath $stdoutPath, $stderrPath, $clientOut, $clientErr -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-NetworkIsolationCheck {
    $serverOut = [System.IO.Path]::GetTempFileName()
    $serverErr = [System.IO.Path]::GetTempFileName()
    $ownerOut = [System.IO.Path]::GetTempFileName()
    $ownerErr = [System.IO.Path]::GetTempFileName()
    $guestOut = [System.IO.Path]::GetTempFileName()
    $guestErr = [System.IO.Path]::GetTempFileName()
    $server = $null
    $owner = $null
    try {
        Write-Host "== Two-session isolation smoke =="
        $serverArguments = "--headless --path `"$projectRoot`" --server --account-auth-test-mode"
        $server = Start-Process -FilePath $GodotPath -ArgumentList $serverArguments -WorkingDirectory $projectRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $serverOut -RedirectStandardError $serverErr
        Start-Sleep -Seconds 2
        $ownerArguments = "--headless --path `"$projectRoot`" --quit-after 1800 res://scenes/smoke/network_session_owner_smoke.tscn"
        $owner = Start-Process -FilePath $GodotPath -ArgumentList $ownerArguments -WorkingDirectory $projectRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $ownerOut -RedirectStandardError $ownerErr
        Start-Sleep -Seconds 3
        $guestArguments = "--headless --path `"$projectRoot`" --quit-after 1800 res://scenes/smoke/network_session_guest_smoke.tscn"
        $guest = Start-Process -FilePath $GodotPath -ArgumentList $guestArguments -WorkingDirectory $projectRoot -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $guestOut -RedirectStandardError $guestErr
        $guestOutput = @()
        $guestOutput += Get-Content -LiteralPath $guestOut -ErrorAction SilentlyContinue
        $guestOutput += Get-Content -LiteralPath $guestErr -ErrorAction SilentlyContinue
        $guestOutput | Write-Host
        if (-not $owner.WaitForExit(12000)) {
            throw "Owner isolation client timed out."
        }
        $ownerOutput = (Get-Content -Raw -LiteralPath $ownerOut) + (Get-Content -Raw -LiteralPath $ownerErr)
        $ownerOutput | Write-Host
        $guestText = $guestOutput -join [Environment]::NewLine
        if ($guest.ExitCode -ne 0 -or $guestText -notmatch "Guest created and reset an isolated session") {
            throw "Guest isolation client failed."
        }
        if ($guestText -match "(?m)^(SCRIPT ERROR|ERROR:)|Parse Error") {
            throw "Guest isolation client reported an error."
        }
        if ($ownerOutput -notmatch "Owner session retained isolated progress") {
            throw "Owner isolation client lost its progress."
        }
        $serverOutput = (Get-Content -Raw -LiteralPath $serverOut) + (Get-Content -Raw -LiteralPath $serverErr)
        $serverOutput | Write-Host
        if ($serverOutput -match "(?m)^(SCRIPT ERROR|ERROR:)|Parse Error") {
            throw "Two-session server reported an error."
        }
    }
    finally {
        if ($owner -and -not $owner.HasExited) {
            Stop-Process -Id $owner.Id -ErrorAction SilentlyContinue
        }
        if ($server -and -not $server.HasExited) {
            Stop-Process -Id $server.Id -ErrorAction SilentlyContinue
            $server.WaitForExit()
        }
        Remove-Item -LiteralPath $serverOut, $serverErr, $ownerOut, $ownerErr, $guestOut, $guestErr -Force -ErrorAction SilentlyContinue
    }
}

if (-not $NetworkOnly) {
Invoke-GodotCheck -Name "Project parse" -Arguments @("--quit")
Invoke-GodotCheck -Name "Account client smoke" -Arguments @("res://scenes/smoke/account_client_smoke.tscn")
Invoke-GodotCheck -Name "Account game bridge queue smoke" -Arguments @("res://scenes/smoke/account_game_bridge_smoke.tscn")
Invoke-GodotCheck -Name "Physical input bindings smoke" -Arguments @("res://scenes/smoke/input_bindings_smoke.tscn")
Invoke-GodotCheck -Name "Remote player sync validation smoke" -Arguments @("res://scenes/smoke/player_sync_validation_smoke.tscn")
Invoke-GodotCheck -Name "Day/night cycle smoke" -Arguments @("res://scenes/smoke/day_night_cycle_smoke.tscn")
Invoke-GodotCheck -Name "Looping room ambience smoke" -Arguments @("res://scenes/smoke/audio_cues_smoke.tscn")
Invoke-GodotCheck -Name "Monster journal smoke" -Arguments @("res://scenes/smoke/monster_journal_smoke.tscn")
Invoke-GodotCheck -Name "Collectible evidence visuals smoke" -Arguments @("res://scenes/smoke/note_visual_smoke.tscn")
Invoke-GodotCheck -Name "Listener behavior variants smoke" -Arguments @("res://scenes/smoke/corridor_monster_behavior_smoke.tscn")
Invoke-GodotCheck -Name "Watcher behavior variants smoke" -Arguments @("--quit-after", "600", "res://scenes/smoke/watcher_behavior_smoke.tscn")
Invoke-GodotCheck -Name "False Door monster smoke" -Arguments @("--quit-after", "600", "res://scenes/smoke/mimic_door_smoke.tscn")
Invoke-GodotCheck -Name "The Unlit flashlight behavior smoke" -Arguments @("--quit-after", "600", "res://scenes/smoke/light_shy_monster_smoke.tscn")
Invoke-GodotCheck -Name "The Unlit evidence chamber smoke" -Arguments @("--quit-after", "600", "res://scenes/smoke/unlit_evidence_demo_smoke.tscn")
Invoke-GodotCheck -Name "Main scene smoke" -Arguments @("--quit-after", "2", "res://scenes/main.tscn")
Invoke-GodotCheck -Name "UI scene smoke" -Arguments @("--quit-after", "2", "res://scenes/game_ui.tscn")
Invoke-GodotCheck -Name "UI control text smoke" -Arguments @("res://scenes/smoke/ui_control_text_smoke.tscn")
Invoke-GodotCheck -Name "UI end-state smoke" -Arguments @("res://scenes/smoke/ui_end_state_smoke.tscn")
Invoke-GodotCheck -Name "UI menu smoke" -Arguments @("res://scenes/smoke/ui_menu_smoke.tscn")
Invoke-GodotCheck -Name "UI puzzle modes smoke" -Arguments @("res://scenes/smoke/ui_puzzle_smoke.tscn")
Invoke-GodotCheck -Name "Main state discovery smoke" -Arguments @("--quit-after", "600", "res://scenes/smoke/main_state_smoke.tscn")
Invoke-GodotCheck -Name "Endless House builder smoke" -Arguments @("res://scenes/smoke/endless_house_builder_smoke.tscn")
Invoke-GodotCheck -Name "Backrooms builder smoke" -Arguments @("--quit-after", "2", "res://scenes/backrooms/backrooms_builder_demo.tscn")
Invoke-GodotCheck -Name "Backrooms builder variants smoke" -Arguments @("res://scenes/smoke/backrooms_builder_variants_smoke.tscn")
Invoke-GodotCheck -Name "Backrooms builder paired Unlit smoke" -Arguments @("--quit-after", "600", "res://scenes/smoke/backrooms_builder_unlit_pairs_smoke.tscn")
Invoke-GodotCheck -Name "Backrooms builder Inspector warnings smoke" -Arguments @("res://scenes/smoke/backrooms_builder_warnings_smoke.tscn")
Invoke-GodotCheck -Name "Dedicated startup smoke" -Arguments @("--server", "--account-auth-test-mode", "--quit-after", "2")
}
Invoke-NetworkSessionCheck
Invoke-NetworkIsolationCheck

$scripts = @(
    "deploy\deploy_server.ps1",
    "deploy\deploy_web_oracle.ps1",
    "deploy\rollback_oracle.ps1",
    "deploy\deploy_full_oracle.ps1",
    "deploy\build_web_site.ps1"
)

foreach ($scriptPath in $scripts) {
    $fullPath = Join-Path $projectRoot $scriptPath
    $script = Get-Content -Raw -LiteralPath $fullPath
    [scriptblock]::Create($script) | Out-Null
    Write-Host "== $scriptPath syntax OK =="
}

if ($Exports -and -not $NetworkOnly) {
    Invoke-GodotCheck -Name "Linux dedicated export" -Arguments @("--export-release", "Linux Dedicated Server", "build\server\creepy_pasta_server.x86_64")
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot "deploy\build_web_site.ps1") -GodotExe $GodotPath -SiteDir $SiteDir
    if ($LASTEXITCODE -ne 0) {
        throw "Web build failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Local smoke checks passed."
