param(
    [string]$HostName = "138.2.166.64",
    [string]$User = "ubuntu",
    [string]$KeyPath = "D:\Soft\oracle-server\ssh-key-2026-06-07.key",
    [string]$RemoteDir = "/home/ubuntu/creepy-pasta-server"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$binary = Join-Path $projectRoot "build\server\creepy_pasta_server.x86_64"
$service = Join-Path $projectRoot "deploy\creepy-pasta-server.service"

if (-not (Test-Path $binary)) {
    throw "Server binary not found: $binary. Run deploy\build_server.ps1 first."
}

ssh -i $KeyPath "$User@$HostName" "mkdir -p '$RemoteDir'"
scp -i $KeyPath $binary "$User@$HostName`:$RemoteDir/creepy_pasta_server.x86_64.new"
scp -i $KeyPath $service "$User@$HostName`:/tmp/creepy-pasta-server.service"

ssh -i $KeyPath "$User@$HostName" @"
set -eu
sudo iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 24567 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 5 -p tcp -m state --state NEW -m tcp --dport 24567 -j ACCEPT
if command -v netfilter-persistent >/dev/null 2>&1; then
    sudo netfilter-persistent save
fi
sudo systemctl stop creepy-pasta-server 2>/dev/null || true
if [ -f '$RemoteDir/creepy_pasta_server.x86_64' ]; then
    cp '$RemoteDir/creepy_pasta_server.x86_64' '$RemoteDir/creepy_pasta_server.x86_64.bak'
fi
mv '$RemoteDir/creepy_pasta_server.x86_64.new' '$RemoteDir/creepy_pasta_server.x86_64'
chmod +x '$RemoteDir/creepy_pasta_server.x86_64'
sudo mv /tmp/creepy-pasta-server.service /etc/systemd/system/creepy-pasta-server.service
sudo systemctl daemon-reload
sudo systemctl enable creepy-pasta-server
sudo systemctl start creepy-pasta-server
sleep 2
sudo systemctl --no-pager --full status creepy-pasta-server
ss -tulpen | grep 24567 || true
sudo journalctl -u creepy-pasta-server --since=-2min --no-pager | tee /tmp/creepy-pasta-server-recent.log
if grep -E -e SCRIPT.ERROR -e Parse.Error -e Failed.to.load.script -e status=11/SEGV -e core.dump -e Main.process.exited /tmp/creepy-pasta-server-recent.log; then
    echo 'Fresh server logs contain Godot script/load errors or a native crash.' >&2
    exit 1
fi
rm -f /tmp/creepy-pasta-server-recent.log
"@
