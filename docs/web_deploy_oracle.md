# Web + Oracle deployment

> **Reference-only during the visual-upgrade mission.** Normal asset/model/material work should not spend context here unless a Web export/deploy issue is relevant. `docs/workflow.md` remains authoritative for current deploy/release behavior.


This project supports an authenticated browser client joining a dedicated
WebSocket server through Caddy. The account service and Godot listener are
loopback-only; only HTTPS/WSS is public.

## Local smoke test

Start the account API and server test harness through the project smoke script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\local_smoke.ps1 -NetworkOnly
```

The debug-only smoke ticket mode is never present in a release export.

## Oracle VM

1. Create an Always Free VM.
2. Open inbound TCP ports `80` and `443` in the Oracle security rules. Keep SSH
   `22` restricted to administrative sources. Do not expose `24567` or `8080`.
3. Copy the Linux dedicated server export to the VM.
4. Run the server:

```bash
./creepy_pasta_server.x86_64 --headless --server
```

Current test VPS:

```text
ubuntu@138.2.166.64
/home/ubuntu/creepy-pasta-server
Godot: 127.0.0.1:24567
Account API: 127.0.0.1:8080
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

Oracle Cloud Console still needs subnet ingress rules for the browser site and
HTTPS/WSS:

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

Caddy also proxies `/api/*`, `/privacy`, and `/terms` to the account service.
It must never proxy `/internal/*`; that interface additionally requires a
root-managed shared secret and a loopback source address.

The deployed Caddy config should keep `index.html` uncached (`no-store`). Fixed-name Godot runtime files such as `.wasm`, `.pck`, `.js`, and worklets must revalidate on reload; do not mark them immutable unless the export pipeline first gives them content-hashed filenames. Longer-lived caching is appropriate only where filenames/content rules make stale runtime mismatches impossible. `docs/workflow.md` is authoritative if cache guidance differs.

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

When Google account login is intentionally not part of the current release,
publish the static Web client and game WebSocket routes without the account
service preflight or `/api/*` proxy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_web_oracle.ps1 -SkipGoogleAuth
```

Deploy the account API, Web client, and dedicated server from the same project
state (with a root-private Google credential file):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_full_oracle.ps1 `
  -AccountEnvPath 'D:\private\creepy-pasta-google.local.env'
```

See `docs/account_auth_oracle.md` for Google Cloud configuration, stored data,
backup/restore, and setup-pending deployment.

The deploy scripts keep a single previous-version rollback point on the Oracle VM. Use these only after a bad deploy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\rollback_oracle.ps1 -Server
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\rollback_oracle.ps1 -Web
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\rollback_oracle.ps1 -Server -Web
```
