# Godot MCP setup

The project pins `hybridindie/godot-mcp` release `2026.09.02`. The checked-in Godot addon talks only to a loopback WebSocket. The Python server is installed outside the repository at:

```text
C:\Users\Admin\.codex\tools\godot-editor-mcp\2026.09.02
```

Codex starts that server through `.codex/config.toml`. Restart Codex after changing MCP configuration, open this project in Godot 4.7.2, and leave the `Godot MCP` editor plugin enabled.

Only the MCP `core` and read-only `inspection` surfaces are enabled by default. Enable a mutating toolset only for a named small change, use dry-run where offered, and keep the runtime probe out of project autoloads unless the user explicitly requests runtime automation.

Run `tools/mcp/install_godot_mcp.ps1` to reproduce the pinned local server/addon installation. The installer refuses to overwrite an existing addon directory.
