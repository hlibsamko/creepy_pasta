param(
    [string]$HostName = "138.2.166.64",
    [string]$User = "ubuntu",
    [string]$KeyPath = "D:\Soft\oracle-server\ssh-key-2026-06-07.key",
    [string]$Domain = "creepy-pasta.duckdns.org",
    [switch]$AllowSetupPending
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw "SSH key not found: $KeyPath"
}
if ($Domain -notmatch '^[A-Za-z0-9.-]+$') {
    throw "Domain contains unsupported characters."
}

$allowSetupPendingFlag = if ($AllowSetupPending) { "1" } else { "0" }
$remoteScript = @'
set -eu
allow_setup_pending="__ALLOW_SETUP_PENDING__"
domain="__DOMAIN__"

sudo systemctl is-active --quiet creepy-pasta-account.service
sudo systemctl is-enabled --quiet creepy-pasta-account.service
sudo systemctl is-active --quiet creepy-pasta-account-backup.timer
sudo systemctl is-enabled --quiet creepy-pasta-account-backup.timer

curl --silent --show-error --fail http://127.0.0.1:8080/healthz >/dev/null
ready_body="$(mktemp)"
trap 'rm -f "$ready_body"' EXIT
ready_code="$(curl --silent --show-error --output "$ready_body" --write-out '%{http_code}' http://127.0.0.1:8080/readyz)"
if [ "$ready_code" = "200" ]; then
    :
elif [ "$allow_setup_pending" = "1" ] && [ "$ready_code" = "503" ] && grep -q 'setup_pending' "$ready_body"; then
    echo "Account API setup is pending Google OAuth credentials."
else
    echo "Unexpected account readiness response: HTTP $ready_code" >&2
    exit 1
fi

if ! ss -lnt | grep -Eq '127\.0\.0\.1:8080[[:space:]]'; then
    echo "Account API is not listening on the loopback interface." >&2
    exit 1
fi
if ss -lnt | grep -Eq '(^|[[:space:]])(0\.0\.0\.0|\*|\[::\]):8080[[:space:]]'; then
    echo "Account API is unexpectedly exposed on a public interface." >&2
    exit 1
fi

sudo test "$(sudo stat -c '%U:%G:%a' /etc/creepy-pasta/account.env)" = "root:root:600"
sudo test "$(sudo stat -c '%U:%G:%a' /etc/creepy-pasta/game-server.env)" = "root:root:600"
sudo test "$(sudo stat -c '%U:%G:%a' /var/backups/creepy-pasta)" = "root:root:700"
sudo find /var/backups/creepy-pasta -maxdepth 1 -type f -name 'accounts-*.db' -print -quit | sudo grep -q .
sudo /usr/bin/python3 - <<'PY'
from pathlib import Path

def parse(path: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        key, value = line.split("=", 1)
        if len(value) >= 2 and value[0] == value[-1] == '"':
            value = value[1:-1]
        values[key] = value
    return values

account = parse("/etc/creepy-pasta/account.env")
game = parse("/etc/creepy-pasta/game-server.env")
game_lines = [
    line for line in Path("/etc/creepy-pasta/game-server.env").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
if len(game_lines) != 1:
    raise SystemExit("game-server.env must contain exactly one non-empty line")
if set(game) != {"CREEPY_PASTA_INTERNAL_SECRET"}:
    raise SystemExit("game-server.env contains unexpected keys")
if len(account.get("CREEPY_ACCOUNT_INTERNAL_SECRET", "")) < 32:
    raise SystemExit("account internal secret is missing or too short")
if game["CREEPY_PASTA_INTERNAL_SECRET"] != account["CREEPY_ACCOUNT_INTERNAL_SECRET"]:
    raise SystemExit("account and game server internal secrets differ")
PY

sudo caddy validate --config /etc/caddy/Caddyfile >/dev/null
sudo grep -q 'path /internal/\* /healthz /readyz' /etc/caddy/Caddyfile
sudo grep -q 'respond @account_private 404' /etc/caddy/Caddyfile
sudo grep -q 'path /api/\*' /etc/caddy/Caddyfile
sudo grep -q 'reverse_proxy @account_api 127.0.0.1:8080' /etc/caddy/Caddyfile
sudo grep -q 'path /privacy /terms' /etc/caddy/Caddyfile
sudo grep -q 'reverse_proxy @account_legal 127.0.0.1:8080' /etc/caddy/Caddyfile
curl --silent --show-error --fail --noproxy '*' --resolve "${domain}:443:127.0.0.1" "https://${domain}/privacy" >/dev/null
private_code="$(curl --silent --show-error --noproxy '*' --resolve "${domain}:443:127.0.0.1" --output /dev/null --write-out '%{http_code}' "https://${domain}/internal/v1/tickets/redeem")"
if [ "$private_code" != "404" ]; then
    echo "Account-internal route is publicly reachable: HTTP $private_code" >&2
    exit 1
fi
api_code="$(curl --silent --show-error --noproxy '*' --resolve "${domain}:443:127.0.0.1" --output /dev/null --write-out '%{http_code}' "https://${domain}/api/v1/me")"
if [ "$api_code" != "401" ]; then
    echo "Unexpected public account API response: HTTP $api_code" >&2
    exit 1
fi

echo "Account API smoke checks passed."
'@
$remoteScript = $remoteScript.Replace("__ALLOW_SETUP_PENDING__", $allowSetupPendingFlag).Replace("__DOMAIN__", $Domain)
$remote = "$User@$HostName"
$remoteScript | ssh -i $KeyPath $remote "bash -s"
if ($LASTEXITCODE -ne 0) {
    throw "Account API smoke checks failed."
}
