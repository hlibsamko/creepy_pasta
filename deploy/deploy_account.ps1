param(
    [string]$HostName = "138.2.166.64",
    [string]$User = "ubuntu",
    [string]$KeyPath = "D:\Soft\oracle-server\ssh-key-2026-06-07.key",
    [string]$BackendDir = "",
    [string]$PythonExe = "python",
    [string]$Domain = "creepy-pasta.duckdns.org",
    [string]$LocalEnvPath = "",
    [string]$GoogleClientId = "",
    [Security.SecureString]$GoogleClientSecret,
    [switch]$AllowSetupPending,
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ($BackendDir -eq "") {
    $BackendDir = Join-Path $projectRoot "backend"
}
$BackendDir = [string](Resolve-Path -LiteralPath $BackendDir)

if (-not $ValidateOnly -and -not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw "SSH key not found: $KeyPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $BackendDir "creepy_accounts") -PathType Container)) {
    throw "Account backend package not found under $BackendDir"
}
if ($Domain -notmatch '^[A-Za-z0-9.-]+$') {
    throw "Domain contains unsupported characters."
}
if ($User -notmatch '^[A-Za-z_][A-Za-z0-9_-]*$') {
    throw "SSH user contains unsupported characters."
}

$runtimeFiles = Get-ChildItem -LiteralPath $BackendDir -Recurse -Force -File | Where-Object {
    $_.Name -eq ".env" -or
    ($_.Name -like ".env.*" -and $_.Name -ne ".env.example") -or
    $_.Extension -in @(".db", ".sqlite", ".sqlite3") -or
    $_.Name -match '\.(db|sqlite|sqlite3)-(wal|shm|journal)$'
}
if ($runtimeFiles) {
    $names = ($runtimeFiles | ForEach-Object { $_.FullName }) -join [Environment]::NewLine
    throw "Refusing to package account secrets or runtime databases:`n$names"
}

& $PythonExe -c "import sqlite3, sys; assert sys.version_info >= (3, 12), 'Python 3.12 or newer is required'; assert sqlite3.sqlite_version_info >= (3, 37, 0), 'SQLite 3.37 or newer is required'"
if ($LASTEXITCODE -ne 0) {
    throw "The local Python/SQLite runtime does not meet the account-service requirements."
}
& $PythonExe -B -m unittest discover -s (Join-Path $BackendDir "tests") -t $BackendDir -v
if ($LASTEXITCODE -ne 0) {
    throw "Account backend tests failed with exit code $LASTEXITCODE."
}

function ConvertFrom-Secret {
    param([Security.SecureString]$Secret)

    if ($null -eq $Secret) {
        return ""
    }
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function ConvertTo-EnvironmentValue {
    param([string]$Value)

    if ($Value -match "[`r`n]") {
        throw "Environment values must not contain newlines."
    }
    return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function Read-GoogleEnvironment {
    param([string]$Path)

    $values = @{}
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) {
            continue
        }
        $separator = $line.IndexOf("=")
        if ($separator -lt 1) {
            throw "Invalid environment line in $Path."
        }
        $name = $line.Substring(0, $separator).Trim()
        if ($name -notin @("CREEPY_GOOGLE_CLIENT_ID", "CREEPY_GOOGLE_CLIENT_SECRET")) {
            throw "Unsupported key in local account environment: $name"
        }
        $value = $line.Substring($separator + 1).Trim()
        if ($value.Length -ge 2 -and (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        )) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if ($value -match "[`r`n]") {
            throw "Environment values must not contain newlines."
        }
        $values[$name] = $value
    }
    return $values
}

$google = @{}
if ($LocalEnvPath -ne "") {
    $resolvedEnvPath = [string](Resolve-Path -LiteralPath $LocalEnvPath)
    $google = Read-GoogleEnvironment -Path $resolvedEnvPath
}
if ($GoogleClientId -ne "") {
    $google["CREEPY_GOOGLE_CLIENT_ID"] = $GoogleClientId
}
$plainGoogleClientSecret = ConvertFrom-Secret -Secret $GoogleClientSecret
if ($plainGoogleClientSecret -ne "") {
    $google["CREEPY_GOOGLE_CLIENT_SECRET"] = $plainGoogleClientSecret
}

$hasGoogleClientId = $google.ContainsKey("CREEPY_GOOGLE_CLIENT_ID") -and $google["CREEPY_GOOGLE_CLIENT_ID"] -ne ""
$hasGoogleClientSecret = $google.ContainsKey("CREEPY_GOOGLE_CLIENT_SECRET") -and $google["CREEPY_GOOGLE_CLIENT_SECRET"] -ne ""
if ($hasGoogleClientId -xor $hasGoogleClientSecret) {
    throw "Google client ID and client secret must be supplied together."
}

$deployId = [Guid]::NewGuid().ToString("N")
$archive = Join-Path $env:TEMP "creepy-pasta-account-$deployId.tar.gz"
$remoteStageDir = "/tmp/creepy-pasta-account-$deployId"
$remoteArchive = "$remoteStageDir/backend.tar.gz"
$secretFile = $null
$remoteSecretFile = "$remoteStageDir/google.env"
$remoteScriptFile = "$remoteStageDir/deploy.sh"
$scriptFile = [System.IO.Path]::GetTempFileName()
$remote = "$User@$HostName"
$stageCreated = $false

try {
    tar -czf $archive --exclude="__pycache__" --exclude="*.pyc" -C $BackendDir .
    if ($LASTEXITCODE -ne 0) {
        throw "Could not package the account backend."
    }
    if ($ValidateOnly) {
        Write-Host "Account deploy validation passed; no remote files or services were changed."
        return
    }

    if ($hasGoogleClientId -and $hasGoogleClientSecret) {
        $secretFile = [System.IO.Path]::GetTempFileName()
        $secretContent = @(
            "CREEPY_GOOGLE_CLIENT_ID=$(ConvertTo-EnvironmentValue ([string]$google['CREEPY_GOOGLE_CLIENT_ID']))",
            "CREEPY_GOOGLE_CLIENT_SECRET=$(ConvertTo-EnvironmentValue ([string]$google['CREEPY_GOOGLE_CLIENT_SECRET']))"
        ) -join "`n"
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            & icacls.exe $secretFile /inheritance:r /grant:r "${identity}:(F)" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Could not restrict the temporary credential file ACL."
            }
        }
        [IO.File]::WriteAllText($secretFile, $secretContent + "`n", [Text.UTF8Encoding]::new($false))
    }

    $allowSetupPendingFlag = if ($AllowSetupPending) { "1" } else { "0" }
    $remoteScript = @'
#!/usr/bin/env bash
set -Eeuo pipefail

deploy_id="__DEPLOY_ID__"
domain="__DOMAIN__"
allow_setup_pending="__ALLOW_SETUP_PENDING__"
stage_dir="/tmp/creepy-pasta-account-${deploy_id}"
archive="${stage_dir}/backend.tar.gz"
incoming_google="${stage_dir}/google.env"
account_service="${stage_dir}/account.service"
backup_service="${stage_dir}/backup.service"
backup_timer="${stage_dir}/backup.timer"
backup_script="${stage_dir}/backup.py"
this_script="${stage_dir}/deploy.sh"
selected_google="$(mktemp)"
selected_optional="$(mktemp)"
account_env="$(mktemp)"
game_env="$(mktemp)"
internal_file="$(mktemp)"
ready_body="$(mktemp)"
preflight_dir="$(mktemp -d)"
release_dir=""
old_target=""
rollback_dir="${stage_dir}/rollback"
rollback_needed="0"
rollback_in_progress="0"
rollback_failed="0"
account_was_active="0"
account_was_enabled="0"
timer_was_active="0"
timer_was_enabled="0"
backup_was_active="0"

cleanup() {
    local exit_code="$?"
    trap - EXIT ERR
    if [ "$rollback_needed" = "1" ]; then
        if ! rollback_deployment; then exit_code="1"; fi
    fi
    if [ "$rollback_failed" != "1" ] && [ -d "$rollback_dir" ]; then
        sudo -n rm -rf -- "$rollback_dir" 2>/dev/null || true
    elif [ "$rollback_failed" = "1" ]; then
        echo "Rollback snapshots retained at ${rollback_dir}." >&2
    fi
    rm -f "$archive" "$incoming_google" "$account_service" "$backup_service" \
        "$backup_timer" "$backup_script" "$this_script" "$selected_google" \
        "$selected_optional" "$account_env" "$game_env" "$internal_file" "$ready_body"
    rm -rf -- "$preflight_dir"
    rmdir "$stage_dir" 2>/dev/null || true
    exit "$exit_code"
}
preserve_path() {
    local name="$1"
    local path="$2"
    if sudo test -e "$path"; then
        sudo cp -a -- "$path" "${rollback_dir}/${name}"
    else
        touch "${rollback_dir}/${name}.absent"
    fi
}
restore_path() {
    local name="$1"
    local path="$2"
    local restore_tmp="${path}.rollback-${deploy_id}"
    local failed="0"
    if sudo test -e "${rollback_dir}/${name}"; then
        sudo rm -f -- "$restore_tmp" || failed="1"
        sudo cp -a -- "${rollback_dir}/${name}" "$restore_tmp" || failed="1"
        sudo mv -Tf -- "$restore_tmp" "$path" || failed="1"
    elif [ -f "${rollback_dir}/${name}.absent" ]; then
        sudo rm -f -- "$restore_tmp" "$path" || failed="1"
    else
        failed="1"
    fi
    [ "$failed" = "0" ]
}
rollback_deployment() {
    if [ "$rollback_needed" != "1" ] || [ "$rollback_in_progress" = "1" ]; then
        return
    fi
    rollback_in_progress="1"
    trap - ERR
    set +e
    rollback_failed="0"
    echo "Account deployment failed; restoring the previous release and configuration." >&2

    if [ -n "$old_target" ] && [ -d "$old_target" ]; then
        sudo ln -sfn "$old_target" /opt/creepy-pasta-account/current.rollback || rollback_failed="1"
        sudo mv -Tf /opt/creepy-pasta-account/current.rollback /opt/creepy-pasta-account/current || rollback_failed="1"
    else
        sudo rm -f /opt/creepy-pasta-account/current || rollback_failed="1"
    fi

    restore_path account.env /etc/creepy-pasta/account.env || rollback_failed="1"
    restore_path game-server.env /etc/creepy-pasta/game-server.env || rollback_failed="1"
    restore_path internal.secret /etc/creepy-pasta/internal.secret || rollback_failed="1"
    restore_path account.service /etc/systemd/system/creepy-pasta-account.service || rollback_failed="1"
    restore_path backup.service /etc/systemd/system/creepy-pasta-account-backup.service || rollback_failed="1"
    restore_path backup.timer /etc/systemd/system/creepy-pasta-account-backup.timer || rollback_failed="1"
    restore_path backup.py /usr/local/lib/creepy-pasta/backup_account_db.py || rollback_failed="1"
    sudo systemctl daemon-reload || rollback_failed="1"

    if sudo test -e "${rollback_dir}/account.service"; then
        if [ "$account_was_enabled" = "1" ]; then
            sudo systemctl enable creepy-pasta-account.service || rollback_failed="1"
        else
            sudo systemctl disable creepy-pasta-account.service || rollback_failed="1"
        fi
        if [ "$account_was_active" = "1" ]; then
            sudo systemctl restart creepy-pasta-account.service || rollback_failed="1"
        else
            sudo systemctl stop creepy-pasta-account.service || rollback_failed="1"
        fi
    fi
    if sudo test -e "${rollback_dir}/backup.timer"; then
        if [ "$timer_was_enabled" = "1" ]; then
            sudo systemctl enable creepy-pasta-account-backup.timer || rollback_failed="1"
        else
            sudo systemctl disable creepy-pasta-account-backup.timer || rollback_failed="1"
        fi
        if [ "$timer_was_active" = "1" ]; then
            sudo systemctl start creepy-pasta-account-backup.timer || rollback_failed="1"
        else
            sudo systemctl stop creepy-pasta-account-backup.timer || rollback_failed="1"
        fi
    fi
    if [ "$backup_was_active" = "1" ] && sudo test -e "${rollback_dir}/backup.service"; then
        sudo systemctl start creepy-pasta-account-backup.service || rollback_failed="1"
    fi

    if [ -n "$release_dir" ]; then
        case "$release_dir" in
            /opt/creepy-pasta-account/releases/*) sudo rm -rf -- "$release_dir" || rollback_failed="1" ;;
        esac
    fi
    rollback_needed="0"
    rollback_in_progress="0"
    set -e
    if sudo test -f /var/lib/creepy-pasta/accounts.db; then
        echo "The live SQLite database was not rolled back automatically; use the root-only predeploy backup only after reviewing potential post-backup writes." >&2
    fi
    if [ "$rollback_failed" = "1" ]; then
        echo "CRITICAL: account rollback was incomplete; inspect Oracle manually." >&2
        return 1
    fi
    return 0
}
handle_error() {
    local exit_code="$?"
    if ! rollback_deployment; then exit_code="1"; fi
    exit "$exit_code"
}
trap cleanup EXIT
trap handle_error ERR
chmod 600 "$selected_google" "$selected_optional" "$account_env" "$game_env" "$internal_file" "$ready_body"

sudo -n true
for required_file in "$archive" "$account_service" "$backup_service" "$backup_timer" "$backup_script"; do
    if [ ! -f "$required_file" ]; then
        echo "Missing staged deploy file: $required_file" >&2
        exit 1
    fi
done
/usr/bin/python3 - <<'PY'
import sqlite3
import sys

if sys.version_info < (3, 12):
    raise SystemExit("Python 3.12 or newer is required")
if sqlite3.sqlite_version_info < (3, 37, 0):
    raise SystemExit("SQLite 3.37 or newer is required")
PY

if ! getent passwd creepy-pasta-account >/dev/null; then
    sudo useradd --system --home-dir /var/lib/creepy-pasta --shell /usr/sbin/nologin creepy-pasta-account
fi
sudo install -d -o root -g root -m 0755 /opt/creepy-pasta-account /opt/creepy-pasta-account/releases
sudo install -d -o root -g root -m 0700 /etc/creepy-pasta
sudo install -d -o creepy-pasta-account -g creepy-pasta-account -m 0700 /var/lib/creepy-pasta
sudo install -d -o root -g root -m 0700 /var/backups/creepy-pasta
sudo install -d -o root -g root -m 0755 /usr/local/lib/creepy-pasta
mkdir -m 0700 "$rollback_dir"
preserve_path account.env /etc/creepy-pasta/account.env
preserve_path game-server.env /etc/creepy-pasta/game-server.env
preserve_path internal.secret /etc/creepy-pasta/internal.secret
preserve_path account.service /etc/systemd/system/creepy-pasta-account.service
preserve_path backup.service /etc/systemd/system/creepy-pasta-account-backup.service
preserve_path backup.timer /etc/systemd/system/creepy-pasta-account-backup.timer
preserve_path backup.py /usr/local/lib/creepy-pasta/backup_account_db.py
old_target="$(readlink -f /opt/creepy-pasta-account/current 2>/dev/null || true)"
if [ -n "$old_target" ]; then
    case "$old_target" in
        /opt/creepy-pasta-account/releases/*) ;;
        *) echo "Current account release points outside the managed release directory." >&2; exit 1 ;;
    esac
fi
if sudo systemctl is-active --quiet creepy-pasta-account.service; then account_was_active="1"; fi
if sudo systemctl is-enabled --quiet creepy-pasta-account.service; then account_was_enabled="1"; fi
if sudo systemctl is-active --quiet creepy-pasta-account-backup.timer; then timer_was_active="1"; fi
if sudo systemctl is-enabled --quiet creepy-pasta-account-backup.timer; then timer_was_enabled="1"; fi
if sudo systemctl is-active --quiet creepy-pasta-account-backup.service; then backup_was_active="1"; fi
rollback_needed="1"
if sudo systemctl cat creepy-pasta-account-backup.timer >/dev/null 2>&1; then
    sudo systemctl stop creepy-pasta-account-backup.timer
fi
if sudo systemctl cat creepy-pasta-account-backup.service >/dev/null 2>&1; then
    sudo systemctl stop creepy-pasta-account-backup.service
fi

if [ -f "$incoming_google" ]; then
    line_count=0
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            CREEPY_GOOGLE_CLIENT_ID=*|CREEPY_GOOGLE_CLIENT_SECRET=*) ;;
            *) echo "Incoming Google environment contains an unsupported line." >&2; exit 1 ;;
        esac
        printf '%s\n' "$line" >> "$selected_google"
        line_count=$((line_count + 1))
    done < "$incoming_google"
    if [ "$line_count" -ne 2 ]; then
        echo "Incoming Google environment must contain exactly two values." >&2
        exit 1
    fi
elif sudo test -f /etc/creepy-pasta/account.env; then
    sudo grep -E '^CREEPY_GOOGLE_CLIENT_(ID|SECRET)=' /etc/creepy-pasta/account.env > "$selected_google" || true
fi
if sudo test -f /etc/creepy-pasta/account.env; then
    sudo grep -E '^(CREEPY_ACCOUNT_(CONTACT_EMAIL|ACCESS_TTL_SECONDS|REFRESH_TTL_SECONDS|LOGIN_TTL_SECONDS|TICKET_TTL_SECONDS|HEARTBEAT_CREDIT_CAP_SECONDS|PLAY_SESSION_IDLE_TTL_SECONDS|MAX_BODY_BYTES)|CREEPY_GOOGLE_HTTP_TIMEOUT_SECONDS)=' /etc/creepy-pasta/account.env > "$selected_optional" || true
    /usr/bin/python3 - "$selected_optional" <<'PY'
from pathlib import Path
import re
import sys

allowed = {
    "CREEPY_ACCOUNT_CONTACT_EMAIL": "text",
    "CREEPY_ACCOUNT_ACCESS_TTL_SECONDS": "integer",
    "CREEPY_ACCOUNT_REFRESH_TTL_SECONDS": "integer",
    "CREEPY_ACCOUNT_LOGIN_TTL_SECONDS": "integer",
    "CREEPY_ACCOUNT_TICKET_TTL_SECONDS": "integer",
    "CREEPY_ACCOUNT_HEARTBEAT_CREDIT_CAP_SECONDS": "integer",
    "CREEPY_ACCOUNT_PLAY_SESSION_IDLE_TTL_SECONDS": "integer",
    "CREEPY_ACCOUNT_MAX_BODY_BYTES": "integer",
    "CREEPY_GOOGLE_HTTP_TIMEOUT_SECONDS": "integer",
}
seen: set[str] = set()
for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    name, value = line.split("=", 1)
    if name not in allowed or name in seen:
        raise SystemExit("stored account environment has an invalid/duplicate optional setting")
    seen.add(name)
    if allowed[name] == "integer":
        if not re.fullmatch(r'"[0-9]+"', value):
            raise SystemExit(f"stored optional integer has invalid syntax: {name}")
    elif not re.fullmatch(r'"[^"\\\r\n]*"', value):
        raise SystemExit(f"stored optional text has invalid syntax: {name}")
PY
fi

google_id_count="$(grep -c '^CREEPY_GOOGLE_CLIENT_ID=' "$selected_google" || true)"
google_secret_count="$(grep -c '^CREEPY_GOOGLE_CLIENT_SECRET=' "$selected_google" || true)"
if [ "$google_id_count" -ne "$google_secret_count" ] || [ "$google_id_count" -gt 1 ]; then
    echo "Stored Google credentials are incomplete or duplicated." >&2
    exit 1
fi
if [ "$google_id_count" -eq 0 ] && [ "$allow_setup_pending" != "1" ]; then
    echo "Google OAuth credentials are missing. Supply -LocalEnvPath/-GoogleClientId or explicitly use -AllowSetupPending." >&2
    exit 1
fi
if [ "$google_id_count" -eq 1 ]; then
    /usr/bin/python3 - "$selected_google" <<'PY'
from pathlib import Path
import sys


def decode(raw: str) -> str:
    if len(raw) < 2 or raw[0] != '"' or raw[-1] != '"':
        raise SystemExit("Google OAuth environment values must be double-quoted")
    output: list[str] = []
    index = 1
    while index < len(raw) - 1:
        character = raw[index]
        if character == "\\":
            index += 1
            if index >= len(raw) - 1 or raw[index] not in {'"', "\\"}:
                raise SystemExit("Google OAuth environment contains an invalid escape")
            character = raw[index]
        output.append(character)
        index += 1
    value = "".join(output)
    if not value:
        raise SystemExit("Google OAuth environment values must not be empty")
    return value


values: dict[str, str] = {}
for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    name, raw_value = line.split("=", 1)
    values[name] = decode(raw_value)
if set(values) != {"CREEPY_GOOGLE_CLIENT_ID", "CREEPY_GOOGLE_CLIENT_SECRET"}:
    raise SystemExit("Google OAuth environment keys are incomplete")
PY
fi

internal_secret=""
accept_stored_secret() {
    local label="$1"
    local candidate="$2"
    if ! [[ "$candidate" =~ ^[A-Za-z0-9._~-]{32,}$ ]]; then
        echo "Stored internal secret in ${label} has invalid syntax." >&2
        exit 1
    fi
    if [ -n "$internal_secret" ] && [ "$candidate" != "$internal_secret" ]; then
        echo "Stored account/game internal secrets disagree; refusing to break a running service." >&2
        exit 1
    fi
    internal_secret="$candidate"
}
if sudo test -f /etc/creepy-pasta/internal.secret; then
    secret_line_count="$(sudo awk 'END { print NR }' /etc/creepy-pasta/internal.secret)"
    if [ "$secret_line_count" -ne 1 ]; then
        echo "Stored internal secret file must contain exactly one line." >&2
        exit 1
    fi
    accept_stored_secret internal.secret "$(sudo cat /etc/creepy-pasta/internal.secret)"
fi
if sudo test -f /etc/creepy-pasta/account.env; then
    account_secret_count="$(sudo grep -Ec '^CREEPY_ACCOUNT_INTERNAL_SECRET=' /etc/creepy-pasta/account.env || true)"
    if [ "$account_secret_count" -gt 1 ]; then
        echo "Stored account environment contains duplicate internal secrets." >&2
        exit 1
    elif [ "$account_secret_count" -eq 1 ]; then
        internal_line="$(sudo grep -E '^CREEPY_ACCOUNT_INTERNAL_SECRET=' /etc/creepy-pasta/account.env)"
        if ! [[ "$internal_line" =~ ^CREEPY_ACCOUNT_INTERNAL_SECRET=\"[A-Za-z0-9._~-]{32,}\"$ ]]; then
            echo "Stored account internal secret has invalid syntax." >&2
            exit 1
        fi
        candidate="${internal_line#CREEPY_ACCOUNT_INTERNAL_SECRET=\"}"
        candidate="${candidate%\"}"
        accept_stored_secret account.env "$candidate"
    fi
fi
if sudo test -f /etc/creepy-pasta/game-server.env; then
    game_secret_count="$(sudo grep -Ec '^CREEPY_PASTA_INTERNAL_SECRET=' /etc/creepy-pasta/game-server.env || true)"
    if [ "$game_secret_count" -ne 1 ]; then
        echo "Stored game server environment must contain exactly one internal secret." >&2
        exit 1
    fi
    internal_line="$(sudo grep -E '^CREEPY_PASTA_INTERNAL_SECRET=' /etc/creepy-pasta/game-server.env)"
    if ! [[ "$internal_line" =~ ^CREEPY_PASTA_INTERNAL_SECRET=\"[A-Za-z0-9._~-]{32,}\"$ ]]; then
        echo "Stored game server internal secret has invalid syntax." >&2
        exit 1
    fi
    candidate="${internal_line#CREEPY_PASTA_INTERNAL_SECRET=\"}"
    candidate="${candidate%\"}"
    accept_stored_secret game-server.env "$candidate"
fi
if [ -z "$internal_secret" ]; then
    internal_secret="$(/usr/bin/python3 -c 'import secrets; print(secrets.token_hex(32))')"
fi
printf '%s\n' "$internal_secret" > "$internal_file"

setup_pending="0"
if [ "$google_id_count" -eq 0 ]; then
    setup_pending="1"
fi
{
    printf 'CREEPY_ACCOUNT_PUBLIC_BASE_URL="https://%s"\n' "$domain"
    printf 'CREEPY_ACCOUNT_ALLOWED_ORIGINS="https://%s"\n' "$domain"
    printf 'CREEPY_ACCOUNT_ALLOW_SETUP_PENDING="%s"\n' "$setup_pending"
    cat "$selected_google"
    cat "$selected_optional"
    printf 'CREEPY_ACCOUNT_INTERNAL_SECRET="%s"\n' "$internal_secret"
} > "$account_env"
printf 'CREEPY_PASTA_INTERNAL_SECRET="%s"\n' "$internal_secret" > "$game_env"

release_stamp="$(date -u +%Y%m%dT%H%M%SZ)-${deploy_id}"
release_dir="/opt/creepy-pasta-account/releases/${release_stamp}"
sudo install -d -o root -g root -m 0755 "$release_dir"
sudo tar --warning=no-timestamp -xzf "$archive" -C "$release_dir"
if ! sudo test -f "$release_dir/creepy_accounts/__main__.py"; then
    echo "The staged backend has no creepy_accounts/__main__.py entry point." >&2
    rollback_deployment || true
    exit 1
fi

# Exercise the new migrations against a disposable online copy before touching production.
preflight_db="${preflight_dir}/accounts.db"
if sudo test -f /var/lib/creepy-pasta/accounts.db; then
    sudo /usr/bin/python3 - /var/lib/creepy-pasta/accounts.db "$preflight_db" <<'PY'
import sqlite3
import sys

source_path, target_path = sys.argv[1:]
with sqlite3.connect(f"file:{source_path}?mode=ro", uri=True) as source:
    with sqlite3.connect(target_path) as target:
        source.backup(target)
PY
    sudo chown "$(id -u):$(id -g)" "$preflight_db"
fi
chmod 700 "$preflight_dir"
chmod 600 "$preflight_db" 2>/dev/null || true
(
    cd "$release_dir"
    HOME="$preflight_dir" \
    PYTHONDONTWRITEBYTECODE=1 \
    /usr/bin/python3 - "$account_env" "$preflight_db" <<'PY'
import os
from pathlib import Path
import sys

from creepy_accounts.config import Config
from creepy_accounts.service import AccountService


def decode_environment_value(raw: str) -> str:
    if len(raw) < 2 or raw[0] != '"' or raw[-1] != '"':
        raise SystemExit("migration preflight found an invalid environment value")
    output: list[str] = []
    index = 1
    while index < len(raw) - 1:
        character = raw[index]
        if character == "\\":
            index += 1
            if index >= len(raw) - 1 or raw[index] not in {'"', "\\"}:
                raise SystemExit("migration preflight found an invalid environment escape")
            character = raw[index]
        output.append(character)
        index += 1
    return "".join(output)


for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    name, raw_value = line.split("=", 1)
    os.environ[name] = decode_environment_value(raw_value)
os.environ.update(
    CREEPY_ACCOUNT_DB_PATH=sys.argv[2],
    CREEPY_ACCOUNT_BIND_HOST="127.0.0.1",
    CREEPY_ACCOUNT_PORT="0",
)
config = Config.from_env()
service = AccountService(config)
ready, details = service.readiness()
if not ready and not (config.allow_setup_pending and details.get("status") == "setup_pending"):
    raise SystemExit(f"migration preflight is not ready: {details.get('status')}")
PY
)
sudo install -o root -g root -m 0755 "$backup_script" /usr/local/lib/creepy-pasta/backup_account_db.py
sudo install -o root -g root -m 0600 "$internal_file" /etc/creepy-pasta/internal.secret
sudo install -o root -g root -m 0600 "$account_env" /etc/creepy-pasta/account.env
sudo install -o root -g root -m 0600 "$game_env" /etc/creepy-pasta/game-server.env

if sudo test -f /var/lib/creepy-pasta/accounts.db; then
    sudo env \
        CREEPY_ACCOUNT_DB_PATH=/var/lib/creepy-pasta/accounts.db \
        CREEPY_ACCOUNT_BACKUP_DIR=/var/backups/creepy-pasta \
        CREEPY_ACCOUNT_BACKUP_KEEP=14 \
        /usr/bin/python3 /usr/local/lib/creepy-pasta/backup_account_db.py
fi
sudo ln -sfn "$release_dir" /opt/creepy-pasta-account/current.new
sudo mv -Tf /opt/creepy-pasta-account/current.new /opt/creepy-pasta-account/current

sudo install -o root -g root -m 0644 "$account_service" /etc/systemd/system/creepy-pasta-account.service
sudo install -o root -g root -m 0644 "$backup_service" /etc/systemd/system/creepy-pasta-account-backup.service
sudo install -o root -g root -m 0644 "$backup_timer" /etc/systemd/system/creepy-pasta-account-backup.timer
sudo systemctl daemon-reload
sudo systemctl enable creepy-pasta-account.service creepy-pasta-account-backup.timer

if ! sudo systemctl restart creepy-pasta-account.service; then
    sudo journalctl -u creepy-pasta-account.service --since=-2min --no-pager -n 80 >&2 || true
    rollback_deployment || true
    exit 1
fi
sudo systemctl start creepy-pasta-account-backup.timer

healthy=0
for _ in $(seq 1 20); do
    if curl --silent --show-error --fail http://127.0.0.1:8080/healthz >/dev/null; then
        healthy=1
        break
    fi
    sleep 1
done
if [ "$healthy" -ne 1 ]; then
    sudo journalctl -u creepy-pasta-account.service --since=-2min --no-pager -n 80 >&2 || true
    rollback_deployment || true
    exit 1
fi

ready_code="$(curl --silent --show-error --output "$ready_body" --write-out '%{http_code}' http://127.0.0.1:8080/readyz)"
if [ "$ready_code" = "200" ]; then
    :
elif [ "$setup_pending" = "1" ] && [ "$ready_code" = "503" ] && grep -q 'setup_pending' "$ready_body"; then
    echo "Account API is healthy and waiting for Google OAuth credentials."
else
    echo "Account API readiness check failed with HTTP $ready_code." >&2
    sudo journalctl -u creepy-pasta-account.service --since=-2min --no-pager -n 80 >&2 || true
    rollback_deployment || true
    exit 1
fi
sudo systemctl start creepy-pasta-account-backup.service

current_target="$(readlink -f /opt/creepy-pasta-account/current)"
for candidate in /opt/creepy-pasta-account/releases/*; do
    [ -d "$candidate" ] || continue
    candidate_target="$(readlink -f "$candidate")"
    case "$candidate_target" in
        /opt/creepy-pasta-account/releases/*) ;;
        *) echo "Refusing to prune an account release outside the release directory." >&2; exit 1 ;;
    esac
    if [ "$candidate_target" = "$current_target" ] || [ "$candidate_target" = "$old_target" ]; then
        continue
    fi
    sudo rm -rf -- "$candidate_target"
done

sudo systemctl --no-pager --full status creepy-pasta-account.service
sudo systemctl --no-pager --full status creepy-pasta-account-backup.timer
rollback_needed="0"
echo "Account API deployed on the Oracle server."
'@
    $remoteScript = $remoteScript.Replace("__DEPLOY_ID__", $deployId).Replace("__DOMAIN__", $Domain).Replace("__ALLOW_SETUP_PENDING__", $allowSetupPendingFlag)
    [IO.File]::WriteAllText($scriptFile, $remoteScript, [Text.UTF8Encoding]::new($false))

    ssh -i $KeyPath $remote "umask 077; mkdir '$remoteStageDir'; chmod 700 '$remoteStageDir'"
    if ($LASTEXITCODE -ne 0) { throw "Could not create a protected remote staging directory." }
    $stageCreated = $true
    scp -i $KeyPath $archive "$remote`:$remoteArchive"
    if ($LASTEXITCODE -ne 0) { throw "Account archive upload failed." }
    if ($secretFile) {
        scp -i $KeyPath $secretFile "$remote`:$remoteSecretFile"
        if ($LASTEXITCODE -ne 0) { throw "Account credential upload failed." }
    }
    scp -i $KeyPath (Join-Path $PSScriptRoot "creepy-pasta-account.service") "$remote`:$remoteStageDir/account.service"
    if ($LASTEXITCODE -ne 0) { throw "Account service upload failed." }
    scp -i $KeyPath (Join-Path $PSScriptRoot "creepy-pasta-account-backup.service") "$remote`:$remoteStageDir/backup.service"
    if ($LASTEXITCODE -ne 0) { throw "Backup service upload failed." }
    scp -i $KeyPath (Join-Path $PSScriptRoot "creepy-pasta-account-backup.timer") "$remote`:$remoteStageDir/backup.timer"
    if ($LASTEXITCODE -ne 0) { throw "Backup timer upload failed." }
    scp -i $KeyPath (Join-Path $PSScriptRoot "backup_account_db.py") "$remote`:$remoteStageDir/backup.py"
    if ($LASTEXITCODE -ne 0) { throw "Backup helper upload failed." }
    scp -i $KeyPath $scriptFile "$remote`:$remoteScriptFile"
    if ($LASTEXITCODE -ne 0) { throw "Remote account deploy script upload failed." }

    ssh -i $KeyPath $remote "bash '$remoteScriptFile'"
    if ($LASTEXITCODE -ne 0) {
        throw "Account deployment failed. The previous release was restored when possible; the database backup was retained."
    }
    Write-Host "Account service is healthy on Oracle loopback. Run deploy\deploy_web_oracle.ps1 to publish /api/*, /privacy, and /terms through Caddy."
}
finally {
    $plainGoogleClientSecret = $null
    $secretContent = $null
    if ($google) {
        $google.Clear()
    }
    if ($stageCreated) {
        ssh -i $KeyPath $remote "rm -f '$remoteStageDir/backend.tar.gz' '$remoteStageDir/google.env' '$remoteStageDir/account.service' '$remoteStageDir/backup.service' '$remoteStageDir/backup.timer' '$remoteStageDir/backup.py' '$remoteStageDir/deploy.sh'; rmdir '$remoteStageDir' 2>/dev/null || true" 2>$null | Out-Null
    }
    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
    if ($secretFile -and (Test-Path -LiteralPath $secretFile)) {
        Remove-Item -LiteralPath $secretFile -Force
    }
    if (Test-Path -LiteralPath $scriptFile) {
        Remove-Item -LiteralPath $scriptFile -Force
    }
}
