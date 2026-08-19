# Publication Asset Clearance Queue

This is the short release-facing inventory for temporary external 3D assets. Prototype and smoke-build selection is driven by visual fit and technical usefulness. A model with unclear publication rights may remain in the prototype, but it must be listed as `CHECK` or `REPLACE` here before it is integrated.

## Action required before public release

No currently imported 3D model requires clarification or replacement based on the source records now present in the project.

New external models default to this queue until a release action is assigned:

| Status | Model / pack | Project path | Release action |
| --- | --- | --- | --- |
| CHECK | Future external import with incomplete source or rights metadata | `assets/third_party/<source_or_pack>/` | Clarify publication rights or change status to `REPLACE`. |
| REPLACE | Future paid, restricted, ripped, or otherwise non-distributable prototype model | its project path | Swap for a distributable equivalent and remove the original file/import metadata from the release branch. |

## Current imported 3D inventory

| Status | Models | Source record | Current usage | Release action |
| --- | --- | --- | --- | --- |
| KEEP | `bathroomSinkSquare.glb`, `bathtub.glb`, `bear.glb`, `chairDesk.glb`, `desk.glb`, `doorwayOpen.glb`, `plantSmall2.glb`, `radio.glb`, `showerRound.glb` | Kenney Furniture Kit; CC0 source recorded in `docs/asset_credits.md` | Branch studies, builder barriers, Endless House desk/radio | None required; keep source record. |
| KEEP | `Alien.fbx`, `Demon.fbx`, `Orc_Skull.fbx`, `Atlas_Monsters.png` | Quaternius Ultimate Monsters; CC0 source recorded in `docs/asset_credits.md` | Demon is a hidden chaser candidate; all three appear in the diagnostic model gallery | None required; remove unused candidates only for build size, not clearance. |

Project-authored primitive meshes and materials are not external model-clearance items.

## Import and release routine

1. Put an external model under `assets/third_party/<source_or_pack>/` and use it in the smoke build if it is useful.
2. Add one row to **Action required before public release** when distribution conditions are unknown, restrictive, or tied to a paid seat/account.
3. Mark the row `CHECK` when clarification could allow shipping, or `REPLACE` when the prototype file should definitely not be distributed.
4. Before a public build, search scenes for every `CHECK`/`REPLACE` path, replace or remove it, and rerun the import plus smoke suite.
5. Keep `docs/asset_credits.md` as the detailed provenance ledger; keep this file short and actionable.
