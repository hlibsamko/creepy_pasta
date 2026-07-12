param(
    [string]$HostName = "138.2.166.64",
    [string]$User = "ubuntu",
    [string]$KeyPath = "D:\Soft\oracle-server\ssh-key-2026-06-07.key",
    [string]$RemoteServerDir = "/home/ubuntu/creepy-pasta-server",
    [string]$RemoteSiteDir = "/var/www/creepy-pasta",
    [switch]$Server,
    [switch]$Web
)

$ErrorActionPreference = "Stop"

if (-not $Server -and -not $Web) {
    throw "Choose at least one rollback target: -Server, -Web, or both."
}

$remote = "$User@$HostName"
$serverFlag = if ($Server) { "1" } else { "0" }
$webFlag = if ($Web) { "1" } else { "0" }

ssh -i $KeyPath $remote @"
set -eu

if [ '$serverFlag' = '1' ]; then
    if [ ! -f '$RemoteServerDir/creepy_pasta_server.x86_64.bak' ]; then
        echo 'No server backup found at $RemoteServerDir/creepy_pasta_server.x86_64.bak' >&2
        exit 1
    fi
    sudo systemctl stop creepy-pasta-server 2>/dev/null || true
    cp '$RemoteServerDir/creepy_pasta_server.x86_64' '$RemoteServerDir/creepy_pasta_server.x86_64.rollback-from' 2>/dev/null || true
    cp '$RemoteServerDir/creepy_pasta_server.x86_64.bak' '$RemoteServerDir/creepy_pasta_server.x86_64'
    chmod +x '$RemoteServerDir/creepy_pasta_server.x86_64'
    sudo systemctl start creepy-pasta-server
    sudo systemctl --no-pager --full status creepy-pasta-server
fi

if [ '$webFlag' = '1' ]; then
    if [ ! -f /tmp/creepy-pasta-site-previous.tar.gz ]; then
        echo 'No web backup found at /tmp/creepy-pasta-site-previous.tar.gz' >&2
        exit 1
    fi
    sudo rm -rf '$RemoteSiteDir'/*
    sudo tar --warning=no-timestamp -xzf /tmp/creepy-pasta-site-previous.tar.gz -C '$RemoteSiteDir'
    sudo chown -R www-data:www-data '$RemoteSiteDir'
    sudo systemctl reload caddy || sudo systemctl restart caddy
    sudo systemctl --no-pager --full status caddy
fi
"@
