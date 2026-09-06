# Project map

This is the short operational map for editing the game. It describes intended ownership; the migration table records places that still need to be brought into line.

## Entry points and stable runtime paths

| Area | Canonical location | Editing contract |
| --- | --- | --- |
| Game/session coordinator | `scenes/main.tscn`, `scripts/main.gd` | Keep `Main`, `NetworkManager`, and `Players` stable. |
| Production levels | `scenes/<level_id>/` or a clearly named top-level production scene | A playable route must never be named `demo`, `test`, or `smoke`. |
| Reusable production pieces | `scenes/common/`, level-local `kit/` folders | Keep collision/gameplay at the wrapper root and imported visuals below `Visuals`. |
| Shared production code | `scripts/` | Names describe gameplay responsibility, not the experiment that created them. |
| Imported source assets | `assets/third_party/<source_or_pack>/` | Every selected model receives a project-owned wrapper and a recorded production placement. |
| Automated fixtures | `tests/{smoke,visual,fixtures}/{scenes,scripts}` | Production must not reference this tree. |
| Manual QA UI/tools | `devtools/qa/` | Injected behind one setting and removable without touching production scenes. |

Both export presets exclude `tests/`, `devtools/`, `addons/godot_mcp/`, and `tools/`. Editor automation and internal QA resources must not be shipped in client or dedicated-server packages.

## Canonical level scene tree

```text
LevelName
|- Environment
|  |- Architecture
|  |  |- Floors
|  |  |- Walls
|  |  |- Ceilings
|  |  `- Openings
|  |- Props
|  `- Lighting
|- Gameplay
|- Navigation
|- Markers
|- Notes
|- Monsters
`- LevelExit
```

`Notes` remains a direct child where the loader requires it. `LevelExit` must remain recursively discoverable. Existing network-addressed nodes keep their current paths until their consumers are migrated atomically.

## Naming

- Files and folders: `snake_case` (`poolrooms_ceiling.tscn`).
- Scene nodes and named resources: `PascalCase` (`PoolroomsCeiling`).
- Scripts: role-oriented `snake_case` (`level_catalog.gd`, not `new_test.gd`).
- The same semantic terms are used across files, node names, docs, and QA labels: Floor/Floors, Wall/Walls, Ceiling/Ceilings, Opening/Openings, Props, Lighting.

## Current migration queue

1. Pin the editor to Godot 4.7.2 stable and resolve it through `tools/engine/`.
2. Connect the pinned Godot MCP with inspection-only tools enabled by default.
3. Move smoke/capture content from production folders to `tests/`; move the QA overlay to `devtools/qa/`; exclude both from exports.
4. Rename production `*_demo.tscn` routes and replace path-keyed menu dictionaries with stable level IDs/catalog entries.
5. Split builder output into `Floors`, `Walls`, `Ceilings`, and `Openings`, preserving required generated/network paths.
6. Normalize authored scenes one level at a time, starting with Office and Poolrooms, without moving network-addressed gameplay nodes casually.
7. Audit downloaded models by visible production placement, then integrate one high-impact model slot per small batch.

## Migration progress

- Visual capture harnesses now live under `tests/visual/{scenes,scripts}`. Production scenes and scripts no longer share their folders with those capture-only files.
- Automated smoke harnesses now live under `tests/smoke/{scenes,scripts}`. `scenes/smoke` has been retired, and smoke-only scripts no longer sit beside production gameplay scripts.
- The QA overlay lives under `devtools/qa` and is loaded optionally through `creepy_pasta/qa/enabled` (default `true` while the game is private). `scenes/game_ui.tscn` has no packed-scene dependency on it.
- Private site builds use the `Web QA` preset and include `devtools/qa`; the clean `Web` preset and dedicated-server preset exclude all internal tooling. `deploy/build_web_site.ps1` defaults to the private preset until public release preparation.

## Model integration ledger

The detailed ledger lives in `docs/asset_inventory.md`. A model status progresses through `selected -> downloaded -> wrapped -> production`. Only `production` means the request has been fulfilled.
