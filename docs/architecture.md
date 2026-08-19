# Creepy Pasta Architecture

This document defines the project structure that should remain easy to read in the Godot editor while preserving multiplayer and gameplay contracts.

## Scene-tree layers

Use three explicit layers in reusable scenes:

1. **Gameplay root** — the scripted `Area3D`, `StaticBody3D`, character, or coordinator node. Keep its name and type stable when networking, saves, smoke tests, or builders discover it.
2. **Collision and interaction** — collision shapes, interaction areas, navigation helpers, and other gameplay-facing children. Keep these close to the root and out of visual-only containers.
3. **Visuals** — meshes, lights, decals, dressing, and imported models under an identity-transform `Visuals` node. Add descriptive subgroups such as `Furniture`, `SurfaceProps`, `FloorDressing`, and `WallDressing` when a scene has more than roughly ten visual children.

Identity-transform visual containers are safe to collapse in the editor and do not alter authored child transforms. Do not put gameplay collision or RPC-owned nodes under them.

When a scripted collision/visual cluster appears more than once, prefer a reusable packed scene over copied child blocks. Keep each instance root at the existing gameplay path and express intentional differences as exported-property or child overrides.

## Stable runtime contracts

- Keep `Main`, `NetworkManager`, `Players`, and player node names/paths stable. RPC identity depends on matching scene trees between client and server.
- Keep `main.gd` as the RPC and session coordinator. Pure tree discovery belongs in `scripts/level_runtime_query.gd`.
- Keep a direct `Notes` child on playable level roots because level loading resolves it explicitly.
- Keep one discoverable `LevelExit`; generated builders may nest it, because runtime lookup is recursive.
- Treat level-relative paths used in session snapshots as network data. Reparenting pressure plates, synchronized mechanics, or authoritative monsters requires network-contract review and the full local smoke suite.
- Visual-only children should be discovered by semantic root or edited through their scene, not addressed from `main.gd` by fragile mesh paths.

## Current organization examples

- `scenes/main.tscn` is intentionally shallow: services, the active level, runtime players, and UI remain direct children.
- `scenes/endless_house/kit/house_low_sideboard.tscn` keeps its collision at the gameplay root and groups all dressing under `Visuals`.
- `scenes/fourth_room.tscn` keeps network-addressed evidence, dialogue, monsters, and `LevelExit` paths stable while collapsing its static shell under `Environment/{Geometry,Lighting}`. Its Watcher and exit are instances of reusable common scenes instead of local mesh/script copies.
- `scenes/next_place.tscn` follows the same static-shell hierarchy while retaining direct `PressurePlate`, `DialogueNpcs`, `Notes`, and `LevelExit` contracts.
- `scenes/corridor.tscn` instances `corridor_photo_chaser_basic.tscn` twice, retaining its two stable monster paths and per-instance pacing/visual overrides instead of copying collision and sprite children.
- `scenes/level.tscn` groups only ordinary shell/lighting/dressing nodes. Threshold walls, threshold/spawn markers, evidence, dialogue, monster, and exit roots remain direct children because tests, startup bindings, and session source IDs treat those paths as contracts.
- Builder-generated levels use `GeneratedBackrooms/{Geometry,Markers,Mechanics,Notes,Monsters}` as their runtime hierarchy.
- `scripts/main.gd` uses foldable responsibility regions; tree-query behavior is centralized in `LevelRuntimeQuery` while RPC methods remain on `Main`.

## Imported asset policy

- Store external assets below `assets/third_party/<source_or_pack>/` and record their known provenance in `docs/asset_credits.md`.
- Prototype suitability is separate from publication clearance. An unresolved or non-distributable temporary model may be used in a smoke build, but it must immediately receive a `CHECK` or `REPLACE` row in `docs/publication_asset_clearance.md`.
- Wrap imported models in a project-owned `.tscn`. Apply scale/orientation/material overrides in the wrapper instead of editing generated import files.
- Use a ground pivot, forward `-Z`, practical Web-compatible materials, and a visual child beneath the existing gameplay root.
- Preserve the existing collision and gameplay silhouette until a dedicated collision review proves a replacement is safe.

## Verification by change type

- Visual reparenting: relevant builder smoke, `main_state_smoke`, and player-eye capture.
- Runtime tree-query changes: `main_state_smoke` plus the relevant builder smoke.
- RPC paths or session snapshot paths: full `deploy/local_smoke.ps1`, then matched client/server deployment if released.
- UI hierarchy or styling: UI menu/control/end-state smoke and a rendered UI capture.

Always finish with `git diff --check` and inspect rendered evidence when the change affects what a player sees.
