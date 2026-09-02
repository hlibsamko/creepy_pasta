# Project Documentation Map

Use this file to keep agent context small. **Do not load every document every cycle.**

## Always Read at Session Start

1. `AGENTS.md` — durable editing, naming, asset-integration, and change-discipline rules.
2. `docs/roadmap.md` — current mission and exactly one active task.
3. `docs/project_map.md` — canonical ownership, scene tree, naming, and migration queue.
4. `docs/document_map.md` — routes the current task to the right technical file.

Read `docs/workflow.md` when the task reaches testing/release or if a change could touch multiplayer/server contracts.

## Read Only When Relevant

- `docs/architecture.md` — scene-tree layers, stable runtime paths, code boundaries, and imported-asset conventions.
- `docs/asset_inventory.md` — downloaded model wrappers and exact production placements.

- `docs/asset_needs.md` — replacement slots, dimensions, priorities, candidate sources, integration status.
- `docs/asset_credits.md` — historical source ledger; read only when the user asks about provenance.
- `docs/endless_house_builder.md` — Endless House kit replacement/dressing; 4 m / 3.2 m/root-offset contract.
- `docs/backrooms_builder.md` — shared/Backrooms builder semantics, visual kit slots, `R/U/T` and other generated contracts.
- `docs/light_shy_monster.md` — The Unlit production/server-authoritative behavior and visual warning contract.
- `docs/branch_research.md` — Compatibility-renderer constraints, Web-safe effect choices, prior asset references.
- `docs/questions_for_user.md` — non-blocking decisions and machine follow-up.
- `docs/web_deploy_oracle.md` — infrastructure/setup reference only; normally irrelevant to asset integration.
- `docs/roadmap_history.md` — archive only; use only when historical reasoning is specifically needed.

## Conflict Rule

1. Current user request, then root `AGENTS.md`.
2. Active roadmap wins for **priority**.
3. `docs/project_map.md` wins for **path, naming, and editor-structure conventions**.
4. Workflow wins for **release/network safety** when the user explicitly requests that work.
5. Current feature doc wins for **that feature's technical contract**.
6. Asset inventory wins for **actual production placement**.
7. Branch research wins for **renderer/research constraints**.
8. History never overrides current state.

If a feature doc clearly contains an older statement contradicted by a newer production-state doc, do not silently follow the old statement; reconcile it against the actual project state before editing gameplay-affecting content.
