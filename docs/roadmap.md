# Creepy Pasta — Active Roadmap

This is the short operational source of truth for current work. Historical visual-pass notes live in `docs/roadmap_progress_archive_2026_09.md`; the older product roadmap lives in `docs/roadmap_history.md`.

## Current Focus — ONE TASK ONLY

**ACTIVE — private QA feedback and editor-first iteration.**

Current question: does the main-menu diorama feel better when furniture `Sprite3D` billboarding is explicitly disabled? Keep this experiment reversible and collect human feedback before changing the projection approach.

## Current Production State

- Godot is pinned to official 4.7.2 stable through `tools/engine/`.
- Private Web builds use `Web QA`; its collapsible test menu is enabled by default and production Web builds exclude it.
- Campaign identity, titles, QA labels, scene lookup, and order live in `scripts/level_catalog.gd`.
- Authored levels expose `Environment/Architecture/{Floors,Walls,Ceilings,Openings}`, plus `Props` and `Lighting`.
- Generated layouts expose the same architecture categories below `GeneratedBackrooms`.
- Automated fixtures live under `tests/`; human-only QA tooling lives under `devtools/qa`.
- Imported models are wrapped under `scenes/props/` and their visible placements are recorded in `docs/asset_inventory.md`.
- The dense House sideboard wall cluster is edited through `house_sideboard_wall_dressing.tscn` without moving gameplay collision.

## Near-Term Queue

1. Evaluate the fixed-orientation menu furniture in the running game; keep it if the rug/furniture relationship reads better, otherwise revert only that experiment.
2. Move remaining path-keyed per-level mechanic data out of `main.gd` only when touching the corresponding mechanic. Do not change the network snapshot format casually.
3. Split more sideboard dressing only if the current wall-dressing extraction is still inconvenient in the editor.
4. Restore account/Google routes only when online-friends testing becomes the explicit priority.

## Change Rules

- Work in small commits and preserve stable RPC, session, collision, marker, and monster paths.
- Keep gameplay and collision outside visual-only containers.
- Apply imported-model transforms through project-owned wrappers or owning kit scenes.
- Do not add broad new gameplay, networking, or infrastructure work during a visual/editor polish task.
- Run smoke, browser, build, or visual validation only when the user explicitly requests it.
- Update `docs/project_map.md` whenever paths, scene roles, or stable contracts change.

## Practical Definition of Done

- A human can find a level and its floors, walls, ceilings, props, lights, gameplay nodes, and collision in the editor without reading implementation scripts first.
- QA tools remain isolated and removable through one project setting.
- A downloaded production model is wrapped, visibly placed, and recorded.
- The active roadmap stays short; completed micro-history goes to an archive.

## Non-Blocking Risks

- Final art direction is not locked across every branch; prefer reversible scene wrappers and branch-specific identity.
- Browser rendering limits some desktop effects; use the Compatibility renderer contract documented in `docs/branch_research.md`.
- The headless exporter may print resource-lifetime warnings after a successful export; investigate only if this begins breaking or delaying releases.

## Documentation Precedence

1. Current user request and root `AGENTS.md`.
2. `docs/roadmap.md` for current priority.
3. `docs/project_map.md` for structure, paths, and naming.
4. `docs/workflow.md` for requested test/release work and network safety.
5. Current feature documentation and `docs/asset_inventory.md`.
6. Archived roadmap files for historical context only.
