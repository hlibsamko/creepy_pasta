# Creepy Pasta Workflow

This file is the source of truth for how we change, test, deploy, and explain this project.

## Current Topology

- GitHub repo: `https://github.com/hlibsamko/creepy_pasta.git`
- Main branch: `main`
- Oracle dedicated server: `138.2.166.64`
- Current domain: `creepy-pasta.duckdns.org`
- Game server port: `24567`
- Browser site: `https://creepy-pasta.duckdns.org`
- Browser WebSocket address: `wss://creepy-pasta.duckdns.org`
- Direct test join address: `ws://138.2.166.64:24567`
- Remote server directory: `/home/ubuntu/creepy-pasta-server`
- Remote web directory: `/var/www/creepy-pasta`
- Local web build directory: `D:\Codex_projects\creepy-website`
- systemd service: `creepy-pasta-server`
- web service: `caddy`
- Dedicated server export preset: `Linux Dedicated Server`
- Web export preset: `Web`

Players using the Oracle server should not press `Host`. Desktop players can join this direct test address:

```text
ws://138.2.166.64:24567
```

Browser players should open:

```text
https://creepy-pasta.duckdns.org
```

## Core Rule

The client and Oracle dedicated server must run the same network contract.

Any change touching multiplayer behavior requires thinking about both sides. This includes:

- `@rpc` methods, names, annotations, parameters, or call sites
- node paths used by RPC, especially `Main`, `Players`, and player node names
- spawning, despawning, teleporting, level transitions, scene changes
- `NetworkManager`, connection flow, host/join behavior, transport type
- `player.tscn`, `main.tscn`, or any scene/script used by the dedicated server

If one of those changes happens, rebuild and redeploy the Oracle dedicated server before telling the user it is fixed.

If a browser build is involved, rebuild and redeploy the Web client too. The Web client and dedicated server should come from the same commit/project state.

Current session sync contract includes level path, current-level collected note IDs, session collected-note count, level-exit open state, pressure plate states keyed by level-relative node path, and note-gated monster activation states keyed by level-relative node path. Changes to any of these fields require rebuilding both the Web client and dedicated server together.

## Fix Workflow

1. Inspect the bug and identify whether it affects client only, server only, or both.
2. If multiplayer is involved, assume both client and dedicated server may be affected until proven otherwise.
3. Make the smallest code change that fixes the issue.
4. Run the standard local smoke suite:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\local_smoke.ps1
```

Use `-Exports` when the change should also prove Linux dedicated export and Web export:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\local_smoke.ps1 -Exports
```

`local_smoke.ps1` treats Godot script/load error text as failure even if the process exits with code `0`.

5. For a faster single parse/startup check:

```powershell
& 'D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe' --headless --path . --quit-after 2
```

6. If the change affects multiplayer or RPC, build the Linux dedicated server:

```powershell
& 'D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe' --headless --path . --export-release 'Linux Dedicated Server' 'build\server\creepy_pasta_server.x86_64'
```

7. Deploy to Oracle. If replacing the running binary directly fails, upload to a temporary file, stop the service, move it into place, and restart:

```powershell
$key='D:\Soft\oracle-server\ssh-key-2026-06-07.key'
$hostName='ubuntu@138.2.166.64'
scp -i $key .\build\server\creepy_pasta_server.x86_64 "$hostName`:/home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64.new"
ssh -i $key $hostName "set -eu; sudo systemctl stop creepy-pasta-server; mv /home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64.new /home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64; chmod +x /home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64; sudo systemctl start creepy-pasta-server; sleep 2; sudo systemctl --no-pager --full status creepy-pasta-server; ss -tulpen | grep 24567"
```

8. Verify Oracle TCP connectivity:

```powershell
$c = [Net.Sockets.TcpClient]::new()
$iar = $c.BeginConnect('138.2.166.64',24567,$null,$null)
if (-not $iar.AsyncWaitHandle.WaitOne(5000)) { $c.Close(); throw 'TCP timeout' }
$c.EndConnect($iar)
$c.Close()
'TCP 138.2.166.64:24567 OK'
```

9. Commit and push the code change to GitHub.
10. Tell the user exactly what changed, what was deployed, and the join address if relevant.

## Browser Website Workflow

Build the local website copy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\build_web_site.ps1
```

This writes the current Web export to:

```text
D:\Codex_projects\creepy-website
```

Deploy the website to Oracle/Caddy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_web_oracle.ps1
```

Deploy both the website and dedicated server:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\deploy_full_oracle.ps1
```

The Web deploy script writes Caddy cache headers. `index.html` is served with no-cache headers so players pick up the latest build entrypoint. Godot export assets such as `.wasm`, `.pck`, `.js`, worklets, and icons are served with long immutable caching to reduce reload cost.

The deploy scripts keep one rollback point on the Oracle VM:

- `deploy_server.ps1` copies the previously running binary to `/home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64.bak` before replacing it.
- `deploy_web_oracle.ps1` archives the previous web directory to `/tmp/creepy-pasta-site-previous.tar.gz` before replacing it.

Rollback commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\rollback_oracle.ps1 -Server
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\rollback_oracle.ps1 -Web
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\rollback_oracle.ps1 -Server -Web
```

Oracle Cloud Console must allow inbound TCP `80`, `443`, and `24567`. Ubuntu iptables alone is not enough; the Oracle VCN security list or NSG must also allow those ports.

## Do Not Claim Fixed Until

- The local project starts headless without script errors.
- The Oracle service is `active (running)` after redeploy when multiplayer/server code changed.
- Port `24567` is reachable from the local machine.
- For browser deploys, Caddy is `active (running)` and `https://creepy-pasta.duckdns.org` loads.
- The GitHub branch contains the code matching the deployed server.

## Common Failure Signals

`rpc node checksum failed`

The client and dedicated server are running different scripts or RPC signatures. Rebuild and redeploy the Oracle server from the same project state as the client.

`Node not found: Main/Players/...`

RPC packets are targeting player nodes that do not exist on that peer. Check spawn/despawn timing, dedicated server fake players, and whether player nodes are removed during level transitions.

`Removing a CollisionObject node during a physics callback is not allowed`

Do not remove/change scenes directly from physics callbacks. Use `call_deferred`.
