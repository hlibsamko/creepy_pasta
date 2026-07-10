# Web + Oracle deployment

This project now supports a browser client joining a dedicated WebSocket server.

## Local smoke test

Start the server from the project folder:

```bash
godot --headless --path . --server
```

Then run the game normally and join:

```text
ws://127.0.0.1:24567
```

## Oracle VM

1. Create an Always Free VM.
2. Open inbound TCP ports `80`, `443`, and `24567` in the Oracle security rules.
3. Copy the Linux dedicated server export to the VM.
4. Run the server:

```bash
./creepy_pasta_server.x86_64 --headless --server
```

Current test VPS:

```text
ubuntu@138.2.166.64
/home/ubuntu/creepy-pasta-server
TCP 24567
```

Current test domain:

```text
creepy-pasta.duckdns.org -> 138.2.166.64
```

The lightweight production path is a native binary plus systemd, not Docker:

```bash
sudo systemctl status creepy-pasta-server
journalctl -u creepy-pasta-server -f
ss -tulpen | grep 24567
```

Oracle-provided Ubuntu images may use iptables even when UFW is not installed. The local VM rule is:

```bash
sudo iptables -I INPUT 5 -p tcp -m state --state NEW -m tcp --dport 24567 -j ACCEPT
sudo netfilter-persistent save
```

Oracle Cloud Console still needs subnet ingress rules. For the dedicated Godot server:

```text
Networking -> Virtual cloud networks -> creepy-pasta-vcn
Subnets -> public subnet-creepy-pasta-vcn
Security Lists -> default/security list for the subnet
Add Ingress Rule:
  Source CIDR: 0.0.0.0/0
  IP Protocol: TCP
  Destination Port Range: 24567
  Stateless: No
  Description: Creepy Pasta Godot WebSocket server
```

Keep the existing SSH rule for TCP `22`.

For the browser site and HTTPS/WSS, add two more ingress rules:

```text
Source CIDR: 0.0.0.0/0
IP Protocol: TCP
Destination Port Range: 80
Stateless: No
Description: HTTP for Caddy/Let's Encrypt
```

```text
Source CIDR: 0.0.0.0/0
IP Protocol: TCP
Destination Port Range: 443
Stateless: No
Description: HTTPS/WSS for browser game
```

For a browser client hosted on HTTPS, use `wss://`. The simplest production setup is Caddy in front of the Godot server:

```caddyfile
creepy-pasta.example.com {
	reverse_proxy 127.0.0.1:24567
}
```

With that proxy, players open the game site:

```text
https://creepy-pasta.duckdns.org
```

The browser client then joins the server through:

```text
wss://creepy-pasta.duckdns.org
```

## Godot web export

1. Use the Web export preset.
2. Keep the export single-threaded unless the web host is configured for cross-origin isolation headers.
3. Export the web build as `index.html`.
4. Upload the generated `.html`, `.js`, `.pck`, `.wasm`, and related files to itch.io, Cloudflare Pages, or another static host.

Before exporting for public play, set the `NetworkManager.server_url` value in `scenes/main.tscn` to the production `wss://` address. Current value:

```text
wss://creepy-pasta.duckdns.org
```

## Local website copy

The local browser-site build folder is outside the Godot project:

```text
D:\Codex_projects\creepy-website
```

Build it with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\build_web_site.ps1
```

Deploy only the browser site to Oracle:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_web_oracle.ps1
```

Deploy both Web client and dedicated server from the same project state:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_full_oracle.ps1
```
