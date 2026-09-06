# Pinned Godot editor

`godot-version.json` is the single version and GitHub-release asset pin for the project.

```powershell
# Update the editor binary from the official godotengine/godot-builds release.
.\tools\engine\update_godot.ps1

# Also install the matching export templates required for Web/server exports.
.\tools\engine\update_godot.ps1 -InstallExportTemplates

# Print the resolved editor path used by local scripts.
.\tools\engine\get_godot.ps1
```

Set `CREEPY_PASTA_GODOT_BIN` when running from a detached worktree or from a different folder layout.
