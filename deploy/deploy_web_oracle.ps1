param(
    [string]$HostName = "138.2.166.64",
    [string]$User = "ubuntu",
    [string]$KeyPath = "D:\Soft\oracle-server\ssh-key-2026-06-07.key",
    [string]$SiteDir = "D:\Codex_projects\creepy-website",
    [string]$Domain = "creepy-pasta.duckdns.org",
    [string]$RemoteSiteDir = "/var/www/creepy-pasta"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path (Join-Path $SiteDir "index.html"))) {
    throw "Web site not found at $SiteDir. Run deploy\build_web_site.ps1 first."
}
if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw "SSH key not found: $KeyPath"
}
if ($User -ne "ubuntu" -or $RemoteSiteDir -ne "/var/www/creepy-pasta") {
    throw "This Oracle deploy is pinned to ubuntu:/var/www/creepy-pasta; refusing an inconsistent or unsafe remote path."
}
if ($Domain -notmatch '^[A-Za-z0-9.-]+$') {
    throw "Domain contains unsupported characters."
}

$deployId = [Guid]::NewGuid().ToString("N")
$archive = Join-Path $env:TEMP "creepy-pasta-site-$deployId.tar.gz"
$remoteArchive = "/tmp/creepy-pasta-site-$deployId.tar.gz"

try {
    tar -czf $archive -C $SiteDir .
    if ($LASTEXITCODE -ne 0) { throw "Could not package the Web site." }

    $remote = "$User@$HostName"
    scp -i $KeyPath $archive "$remote`:$remoteArchive"
    if ($LASTEXITCODE -ne 0) { throw "Web site upload failed." }

    ssh -i $KeyPath $remote @"
set -eu
remote_archive='$remoteArchive'
site_dir='$RemoteSiteDir'
candidate_site="/var/www/creepy-pasta-$deployId.candidate"
old_site="/var/www/creepy-pasta-$deployId.previous"
candidate_caddy="/tmp/Caddyfile-$deployId"
caddy_backup="/tmp/Caddyfile-$deployId.previous"
had_site=0
had_caddy=0
site_switched=0
caddy_switched=0
deploy_committed=0
rollback_in_progress=0
rollback_failed=0

rollback_web() {
    if [ "`$rollback_in_progress" = '1' ]; then return; fi
    rollback_in_progress=1
    trap - ERR
    set +e
    rollback_failed=0
    echo 'Web deployment failed; restoring the previous site and Caddy configuration.' >&2
    if [ "`$caddy_switched" = '1' ]; then
        if [ "`$had_caddy" = '1' ]; then
            sudo cp -p -- "`$caddy_backup" /etc/caddy/Caddyfile || rollback_failed=1
        else
            sudo rm -f -- /etc/caddy/Caddyfile || rollback_failed=1
        fi
        sudo systemctl reload caddy || sudo systemctl restart caddy || rollback_failed=1
    fi
    if [ "`$site_switched" = '1' ]; then
        sudo rm -rf -- "`$site_dir" || rollback_failed=1
        if [ "`$had_site" = '1' ]; then
            sudo mv -- "`$old_site" "`$site_dir" || rollback_failed=1
        fi
    fi
    if [ "`$rollback_failed" = '1' ]; then
        echo 'CRITICAL: Web/Caddy rollback was incomplete; inspect Oracle manually.' >&2
        return 1
    fi
    return 0
}
cleanup_web() {
    exit_code="`$?"
    trap - EXIT ERR
    if [ "`$deploy_committed" != '1' ] && { [ "`$site_switched" = '1' ] || [ "`$caddy_switched" = '1' ]; } && ! rollback_web; then exit_code=1; fi
    if [ "`$rollback_failed" = '1' ]; then
        echo "Rollback artifacts retained: `$candidate_site `$old_site `$candidate_caddy `$caddy_backup" >&2
    else
        sudo rm -rf -- "`$candidate_site" "`$old_site"
        sudo rm -f -- "`$candidate_caddy" "`$caddy_backup"
    fi
    rm -f -- "`$remote_archive"
    exit "`$exit_code"
}
handle_web_error() {
    exit_code="`$?"
    if ! rollback_web; then exit_code=1; fi
    exit "`$exit_code"
}
trap cleanup_web EXIT
trap handle_web_error ERR

sudo systemctl is-active --quiet creepy-pasta-account.service
curl --silent --show-error --fail http://127.0.0.1:8080/healthz >/dev/null
ready_code="`$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' http://127.0.0.1:8080/readyz)"
if [ "`$ready_code" != '200' ]; then
    echo "Account service is not ready (HTTP `$ready_code); refusing to publish auth routes." >&2
    exit 1
fi

if ! command -v caddy >/dev/null 2>&1; then
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
    sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install -y caddy
fi

sudo install -d -o www-data -g www-data -m 0755 "`$candidate_site"
sudo tar --warning=no-timestamp -xzf "`$remote_archive" -C "`$candidate_site"
sudo chown -R www-data:www-data "`$candidate_site"

cat > /tmp/Caddyfile-$deployId <<'CADDYFILE'
$Domain {
    root * $RemoteSiteDir
    encode zstd gzip

    @html path / /index.html
    header @html Cache-Control "no-cache,no-store,must-revalidate"
    header @html Pragma "no-cache"
    header @html Expires "0"

    # Godot keeps stable export filenames, so clients must revalidate runtime files.
    @godot_runtime path /*.js /*.wasm /*.pck /*.worklet.js
    header @godot_runtime Cache-Control "no-cache,must-revalidate"

    @images path /*.png /*.ico
    header @images Cache-Control "public,max-age=3600,must-revalidate"

    @account_private path /internal/* /healthz /readyz
    respond @account_private 404

    @account_api path /api/*
    reverse_proxy @account_api 127.0.0.1:8080

    @account_legal path /privacy /terms
    reverse_proxy @account_legal 127.0.0.1:8080

    @websocket {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @websocket 127.0.0.1:24567

    file_server
}
CADDYFILE

sudo caddy fmt --overwrite "`$candidate_caddy"
sudo caddy validate --config "`$candidate_caddy"
if sudo test -e "`$site_dir"; then
    had_site=1
    sudo mv -- "`$site_dir" "`$old_site"
fi
sudo mv -- "`$candidate_site" "`$site_dir"
site_switched=1
if sudo test -f /etc/caddy/Caddyfile; then
    had_caddy=1
    sudo cp -p -- /etc/caddy/Caddyfile "`$caddy_backup"
fi
sudo install -o root -g root -m 0644 "`$candidate_caddy" /etc/caddy/Caddyfile
caddy_switched=1
sudo iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 5 -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
sudo iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 5 -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
if command -v netfilter-persistent >/dev/null 2>&1; then
    sudo netfilter-persistent save
fi

sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl enable caddy
sudo systemctl reload caddy || sudo systemctl restart caddy
sleep 2
sudo systemctl is-active --quiet caddy
sudo systemctl --no-pager --full status caddy
deploy_committed=1
"@
    if ($LASTEXITCODE -ne 0) {
        throw "Web/Caddy deployment failed. The previous site and Caddy configuration were restored when possible."
    }

    Write-Host "Deployed Web site to https://$Domain"
}
finally {
    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
}
