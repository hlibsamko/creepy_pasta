# Project Documentation Map

Use this file to keep Luna's context small. **Do not load every document every cycle.**

## Always Read at Session Start

1. `docs/roadmap.md` — current mission and exactly one active task.
2. `docs/document_map.md` — routes the current task to the right technical file.

Read `docs/workflow.md` when the task reaches testing/release or if a change could touch multiplayer/server contracts.

## Read Only When Relevant

- `docs/architecture.md` — scene-tree layers, stable runtime paths, code boundaries, and imported-asset conventions.

- `docs/asset_needs.md` — replacement slots, dimensions, priorities, candidate sources, integration status.
- `docs/asset_credits.md` — exact external source/license ledger.
- `docs/publication_asset_clearance.md` — short `CHECK`/`REPLACE` queue for temporary models that cannot ship unchanged.
- `docs/endless_house_builder.md` — Endless House kit replacement/dressing; 4 m / 3.2 m/root-offset contract.
- `docs/backrooms_builder.md` — shared/Backrooms builder semantics, visual kit slots, `R/U/T` and other generated contracts.
- `docs/light_shy_monster.md` — The Unlit production/server-authoritative behavior and visual warning contract.
- `docs/branch_research.md` — Compatibility-renderer constraints, Web-safe effect choices, prior asset references.
- `docs/questions_for_user.md` — non-blocking decisions and machine follow-up.
- `docs/web_deploy_oracle.md` — infrastructure/setup reference only; normally irrelevant to asset integration.
- `docs/roadmap_history.md` — archive only; use only when historical reasoning is specifically needed.

## Conflict Rule

1. Active roadmap wins for **priority**.
2. Workflow wins for **testing/release/network safety**.
3. Current feature doc wins for **that feature's technical contract**.
4. Asset needs/credits win for **asset source records**; the publication-clearance queue wins for **replace-before-release actions**.
5. Branch research wins for **renderer/research constraints**.
6. History never overrides current state.

If a feature doc clearly contains an older statement contradicted by a newer production-state doc, do not silently follow the old statement; reconcile it against the actual project state before editing gameplay-affecting content.
