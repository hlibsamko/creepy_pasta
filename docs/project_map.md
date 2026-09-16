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
| Temporary model downloads | `.asset_work/<asset_id>/` | Inside the project; ignored by Godot, Git and every export preset. Clean only owned temporary files after successful preparation and placement. |
| Asset preparation recipes | `tools/asset_pipeline/` | Toolchain, bounded batch and task cards; production has no dependency on this tree. |
| Automated fixtures | `tests/{smoke,visual,fixtures}/{scenes,scripts}` | Production must not reference this tree. |
| Manual QA UI/tools | `devtools/qa/` | Injected behind one setting and removable without touching production scenes. |

All export presets exclude `tests/`, `addons/godot_mcp/`, and `tools/`. The clean `Web` and `Linux Dedicated Server` presets also exclude `devtools/`; the private `Web QA` preset intentionally includes the temporary QA tools. Editor automation must not be shipped in any package, and internal QA tools must not be shipped in public client or dedicated-server packages.

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

## Current maintenance queue

The current recurring mission is the eight-model package in `docs/asset_pipeline_plan.md` and `tools/asset_pipeline/batch.json`. Its content/optimization/readability allocation takes precedence over the older optional cleanup items below.

1. Evaluate the fixed-orientation main-menu furniture experiment during ordinary QA play.
2. Move remaining path-keyed mechanic definitions from `main.gd` into catalog-owned data only in small mechanic-specific changes; keep the current network snapshot compatible.
3. Use the pinned Godot MCP for inspection when the editor bridge is running; filesystem edits remain the fallback when it is offline.
4. Split additional dense visual groups only when they still obstruct normal editor work.

Account/Google deployment is deliberately outside this queue until online-friends testing is requested explicitly.

## Migration progress

- Visual capture harnesses now live under `tests/visual/{scenes,scripts}`. Production scenes and scripts no longer share their folders with those capture-only files.
- Automated smoke harnesses now live under `tests/smoke/{scenes,scripts}`. `scenes/smoke` has been retired, and smoke-only scripts no longer sit beside production gameplay scripts.
- The QA overlay lives under `devtools/qa` and is loaded optionally through `creepy_pasta/qa/enabled` (default `true` while the game is private). `scenes/game_ui.tscn` has no packed-scene dependency on it.
- Private site builds use the `Web QA` preset and include `devtools/qa`; the clean `Web` preset and dedicated-server preset exclude all internal tooling. `deploy/build_web_site.ps1` defaults to the private preset until public release preparation.
- Production routes now use descriptive filenames: `wrong_copy_room.tscn`, `copied_door_room.tscn`, `backrooms.tscn`, `house_survey.tscn`, `unlit_evidence_chamber.tscn`, `corridor.tscn`, and `final_watcher_room.tscn`.
- Campaign IDs, titles, QA labels, scene lookup, transition order, and authoritative exit positions now live in `scripts/level_catalog.gd`; pressure-plate, breaker, authoritative monster metadata, and note-gated monster activation requirements live in `scripts/level_mechanics_catalog.gd`. Network snapshots retain `level_path` until a dedicated protocol migration.
- Authored rooms and branch studies expose `Environment/Architecture/{Floors,Walls,Ceilings,Openings}`, `Environment/Props`, and `Environment/Lighting`; generated layouts expose the same categories below `GeneratedBackrooms`.
- The dense House sideboard keeps collision and surface/floor props in `house_low_sideboard.tscn`, while its editor-only wall cluster is isolated in `house_sideboard_wall_dressing.tscn` and instanced at the stable visual path `Visuals/WallDressing`.
- Imported furniture is isolated behind project-owned scenes in `scenes/props/`. Four higher-detail Poly Haven models are visibly placed in House Survey, Dreamcore, Empty Mall, and Endless Hotel and recorded in `docs/asset_inventory.md`.
- The new asset package adds a Blender-prepared worn bench at `PoolroomsGallery/Environment/Props/PoolroomsPaintedBench`; its collision is outside `Visuals`. This is an authored placement, not a claim of completed game QA.
- The second package model is a 2.7m open locker at `DreamcoreSchoolhouse/Environment/Props/DreamcoreSchoolLocker`. Its project-owned wrapper separates `Visuals` and `LockerCollision`; the recipe exports only this assembly, not the source storage pack. QA remains unperformed.

## Model integration ledger

The detailed ledger lives in `docs/asset_inventory.md`. A model status progresses through `selected -> downloaded -> wrapped -> production`. Only `production` means the request has been fulfilled.
