param(
    [string]$HostName = "138.2.166.64",
    [string]$User = "ubuntu",
    [string]$KeyPath = "D:\Soft\oracle-server\ssh-key-2026-06-07.key",
    [string]$SiteDir = "D:\Codex_projects\my-website",
    [string]$Domain = "creepy-pasta.duckdns.org",
    [string]$RemoteSiteDir = "/var/www/creepy-pasta"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path (Join-Path $SiteDir "index.html"))) {
    throw "Web site not found at $SiteDir. Run deploy\build_web_site.ps1 first."
}

$archive = Join-Path $env:TEMP "creepy-pasta-site.tar.gz"
if (Test-Path $archive) {
    Remove-Item -LiteralPath $archive -Force
}

tar -czf $archive -C $SiteDir .

$remote = "$User@$HostName"
scp -i $KeyPath $archive "$remote`:/tmp/creepy-pasta-site.tar.gz"

ssh -i $KeyPath $remote @"
set -eu
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gpg
if ! command -v caddy >/dev/null 2>&1; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
    sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install -y caddy
fi

sudo mkdir -p '$RemoteSiteDir'
sudo rm -rf '$RemoteSiteDir'/*
sudo tar -xzf /tmp/creepy-pasta-site.tar.gz -C '$RemoteSiteDir'
sudo chown -R www-data:www-data '$RemoteSiteDir'

sudo tee /etc/caddy/Caddyfile >/dev/null <<'CADDYFILE'
$Domain {
    root * $RemoteSiteDir
    encode zstd gzip

    @websocket {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @websocket 127.0.0.1:24567

    file_server
}
CADDYFILE

sudo iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 5 -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
sudo iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 5 -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
if command -v netfilter-persistent >/dev/null 2>&1; then
    sudo netfilter-persistent save
fi

sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl enable caddy
sudo systemctl reload caddy || sudo systemctl restart caddy
sleep 2
sudo systemctl --no-pager --full status caddy
"@

Write-Host "Deployed Web site to https://$Domain"
