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

## Model integration ledger

The detailed ledger lives in `docs/asset_inventory.md`. A model status progresses through `selected -> downloaded -> wrapped -> production`. Only `production` means the request has been fulfilled.
