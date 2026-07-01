# Creepy Pasta Workflow

This file is the source of truth for how we change, test, deploy, and explain this project.

## Current Topology

- GitHub repo: `https://github.com/hlibsamko/creepy_pasta.git`
- Main branch: `main`
- Oracle dedicated server: `138.2.166.64`
- Game server port: `24567`
- Player join address: `ws://138.2.166.64:24567`
- Remote server directory: `/home/ubuntu/creepy-pasta-server`
- systemd service: `creepy-pasta-server`
- Dedicated server export preset: `Linux Dedicated Server`

Players using the Oracle server should not press `Host`. Every player joins the same address:

```text
ws://138.2.166.64:24567
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

## Fix Workflow

1. Inspect the bug and identify whether it affects client only, server only, or both.
2. If multiplayer is involved, assume both client and dedicated server may be affected until proven otherwise.
3. Make the smallest code change that fixes the issue.
4. Run a local Godot parse/startup check:

```powershell
& 'D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe' --headless --path . --quit-after 2
```

5. If the change affects multiplayer or RPC, build the Linux dedicated server:

```powershell
& 'D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe' --headless --path . --export-release 'Linux Dedicated Server' 'build\server\creepy_pasta_server.x86_64'
```

6. Deploy to Oracle. If replacing the running binary directly fails, upload to a temporary file, stop the service, move it into place, and restart:

```powershell
$key='D:\Soft\oracle-server\ssh-key-2026-06-07.key'
$hostName='ubuntu@138.2.166.64'
scp -i $key .\build\server\creepy_pasta_server.x86_64 "$hostName`:/home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64.new"
ssh -i $key $hostName "set -eu; sudo systemctl stop creepy-pasta-server; mv /home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64.new /home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64; chmod +x /home/ubuntu/creepy-pasta-server/creepy_pasta_server.x86_64; sudo systemctl start creepy-pasta-server; sleep 2; sudo systemctl --no-pager --full status creepy-pasta-server; ss -tulpen | grep 24567"
```

7. Verify Oracle TCP connectivity:

```powershell
$c = [Net.Sockets.TcpClient]::new()
$iar = $c.BeginConnect('138.2.166.64',24567,$null,$null)
if (-not $iar.AsyncWaitHandle.WaitOne(5000)) { $c.Close(); throw 'TCP timeout' }
$c.EndConnect($iar)
$c.Close()
'TCP 138.2.166.64:24567 OK'
```

8. Commit and push the code change to GitHub.
9. Tell the user exactly what changed, what was deployed, and the join address if relevant.

## Do Not Claim Fixed Until

- The local project starts headless without script errors.
- The Oracle service is `active (running)` after redeploy when multiplayer/server code changed.
- Port `24567` is reachable from the local machine.
- The GitHub branch contains the code matching the deployed server.

## Common Failure Signals

`rpc node checksum failed`

The client and dedicated server are running different scripts or RPC signatures. Rebuild and redeploy the Oracle server from the same project state as the client.

`Node not found: Main/Players/...`

RPC packets are targeting player nodes that do not exist on that peer. Check spawn/despawn timing, dedicated server fake players, and whether player nodes are removed during level transitions.

`Removing a CollisionObject node during a physics callback is not allowed`

Do not remove/change scenes directly from physics callbacks. Use `call_deferred`.

