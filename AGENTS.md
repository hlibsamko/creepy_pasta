# Creepy Pasta project rules

These rules are the durable project contract for human and AI edits. Direct user instructions in the current task take precedence. If an instruction genuinely conflicts with a technical or safety constraint, stop and explain the conflict; never silently substitute a different goal.

## Editor-first scenes

- Production scenes must be understandable and editable in the Godot editor without reading their scripts first.
- Use one vocabulary everywhere: snake_case for files and PascalCase for scene nodes. Name a thing by its role and room, for example `office_ceiling.tscn` / `OfficeCeiling`.
- Group authored level geometry under `Environment/Architecture/{Floors,Walls,Ceilings,Openings}`. Put visual props under `Environment/Props` and lights under `Environment/Lighting`.
- Keep gameplay, collision, navigation, markers, and network-owned nodes outside visual-only containers.
- Preserve stable runtime/network paths (`Main`, `NetworkManager`, `Players`, direct `Notes`, discoverable `LevelExit`, and path-addressed mechanics/monsters) unless every consumer is migrated in the same small change.
- Generated levels may retain `GeneratedBackrooms`, but generated architecture must be split into `Floors`, `Walls`, `Ceilings`, and `Openings` so each category can be hidden or selected at once.

## Production and internal tooling

- Production content belongs under `scenes/`, `scripts/`, `resources/`, and `assets/` with descriptive names. Do not use `test`, `smoke`, `demo`, `temp`, or numbered placeholder names for a production route.
- Automated fixtures belong under `tests/{smoke,visual,fixtures}`. Human-only QA tools belong under `devtools/qa`.
- Production scenes and scripts must not depend on anything below `tests/` or `devtools/`.
- QA UI is temporary development tooling. Keep it isolated and removable behind one project setting; while the game is private it may default to enabled.

## External models and assets

- A requested downloaded model is not complete merely because files exist in `assets/`. Integrate it visibly into a production scene or production kit and record that placement in `docs/asset_inventory.md`.
- Select models for visual fit, editability, performance, and production usefulness. Do not silently replace the user's requested sourcing criteria with different criteria.
- Wrap imported models in project-owned scenes. Apply transforms and material overrides in wrappers instead of editing generated import files.
- If a requested model cannot be downloaded, imported, or placed, report the exact blocker instead of quietly falling back to primitive geometry.

## Change discipline

- Work in small, coherent commits. Preserve user-owned uncommitted changes and stage only files that belong to the current chunk.
- Update `docs/project_map.md` when paths, scene roles, or stable contracts change.
- Do not run tests, builds, linting, smoke checks, browser QA, or other verification unless the user explicitly requests that specific validation.
