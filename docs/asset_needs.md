# Endless House / Production Visual Asset Needs

This is the **live visual-integration status file** for the current mission. Update it whenever an external asset is researched, selected, downloaded, imported, placed, verified, or rejected.

Status values: `NEEDED`, `RESEARCHING`, `SELECTED`, `DOWNLOADED`, `IMPORTED`, `PLACED`, `VERIFIED`, `TEMPORARY`, `DEFERRED`, `REJECTED`.

## Current Priority and Status

| Priority | Role | Status | Current state / next action |
| --- | --- | --- | --- |
| P0 | Modular old-house interior | VERIFIED | Floor/wall material tuning, restrained ceiling inset panel, Kenney `desk.glb` visual child, and the verified low-cost dressing batch are assigned to the real Endless House kit slots; collision roots and 4 m / 3.2 m builder contract remain unchanged. Quaternius Ultimate House Interior was re-reviewed as a CC0 123-model candidate, but no specific missing slot justified importing the pack. Verified by startup, builder smoke, and player-eye-level capture. |
| P0 | Survivor / Mara | VERIFIED | Project-owned fallback provides a readable indoor-survivor silhouette (`CoatHem`, `Hair`, arms, boots, eyes) on the existing visual slot. Quaternius Universal Base Characters was re-reviewed as a current CC0/glTF/FBX/Godot-compatible candidate, but remains deferred because no local candidate is present and the fallback already passes player-eye-level capture and gameplay smoke. Dialogue, interaction, collision, and stable `Body`/`Head` paths are preserved. |
| P0 | Listener / ordinary chaser | VERIFIED | Project-owned fallback silhouette (head, body, elongated arms, and warning glow) remains the production visual slot; the imported Quaternius Demon is reversibly retained but hidden because its imported scale/geometry was less readable in the player-like capture. Official Ultimate Monsters source is current CC0 with FBX/OBJ/Blend/glTF, but replacement is deferred until a measurable readability gain is demonstrated. AI, collision, network, and stable paths are preserved. |
| P1 | The Unlit | VERIFIED | Narrow matte silhouette has a readable head/arm profile and enlarged separately addressable four-sided cyan-held/red-moving warning markers. Candidate review found no external replacement with equivalent readability; production-route capture and builder variants smoke pass, and the light/observation gameplay contract is preserved. |
| P1 | Watcher | VERIFIED | Mostly static figure has a distinct head, hanging arms, and enlarged emissive eye marker readable in a player-like capture. Candidate review found no external replacement that improves readability without risking observation clarity; observation, collision, network, and stable paths preserved; watcher behavior and main-state smoke pass. |
| P1 | Field journal | VERIFIED | Paper-style journal panel has a warm title/accent, framed page surface, border, and shadow while preserving journal state, rendered content, scroll, close input, and persistence. Review and journal/UI smoke pass. |
| P1 | Maintenance props | VERIFIED | Work-light housing and breaker panel/indicator remain readable; pressure-plate visual footprint and outage behavior remain unchanged. Review plus paired-Unlit, evidence chamber, and Main-state smoke pass. |
| P1 | Real exit / False Door visual pair | VERIFIED | Real and False Door share a framed silhouette while retaining distinct warm exit glow/DraftCue versus purple false pulse/red seam. Pair review, interaction, collision, network, mimic-door, builder, and main-state smoke pass. |
| P2 | Room dressing | NEEDED | Wall-mounted portrait vignette, survey map, narrow wall curtain, wall telephone, compact intercom utility box, switch plate, mail slot, key hook, coat hook, doorbell button, emergency tag, thermometer marker, room label, room number, paint-wear mark, maintenance decal, maintenance arrow, storage basket, radio cable coil, and shoe pair are VERIFIED after the latest cross-scene audit. Ambient readability was tuned slightly; next is targeted alternate player-eye validation. |
| P2 | Ceiling crawler | DEFERRED | Low profile, wall/ceiling locomotion, folded idle pose; gameplay creature is not implemented yet, so do not start it during the current visual mission. |

## Replacement Slots — Preserve Gameplay Roots

Keep each gameplay root, script, collision shape, trigger area, light, signal wiring, stable generated path, and server-owned logic. Replace only the listed visual children or add a visual wrapper.

| Role | Scene | Replace | Target size and pivot |
| --- | --- | --- | --- |
| Listener/chaser | `scenes/common/chaser_monster_basic.tscn` | `Body`, `EyeLeft`, `EyeRight` | 1.8-2.1 m tall, ground pivot, forward `-Z` |
| Watcher | `scenes/common/watcher_monster_basic.tscn` | `Body`, `Eye` | about 2.2 m tall, ground pivot in an added wrapper |
| The Unlit | `scenes/common/light_shy_monster_basic.tscn` | `Body/Silhouette`, four `FaceGlow*` markers or equivalent warning visual | about 2.2 m tall, ground pivot, separately controllable emissive/warning state |
| Survivor | `scenes/common/survivor_npc_basic.tscn` | `Body`, `Head` | 1.65-1.85 m tall, ground pivot, forward `-Z` |
| Real exit | `scenes/common/level_exit_basic.tscn` | `Door`, `Glow` | opening about 2.0 x 2.4 m, bottom-center pivot; preserve `DraftCue` |
| False Door | `scenes/common/mimic_door_basic.tscn` | `Door`, `Glow`, `FalseSeam` | same silhouette as real exit, separate pulse/seam materials |
| Work light | `scenes/common/pressure_powered_spotlight_basic.tscn` | `Housing` | ceiling/wall fixture around the existing `SpotLight3D` origin |
| Breaker | `scenes/common/breaker_outage_trigger_basic.tscn` | `Panel/Housing`, `Panel/Indicator` | wall pivot, separate ready/spent indicator material |
| Pressure plate | `scenes/common/pressure_plate_basic.tscn` | `Plate` | footprint no larger than the existing trigger |
| House modules | `scenes/endless_house/kit/*.tscn` | mesh/visual children only | 4 m cells, 3.2 m wall/ceiling height, cover below 1.2 m |

## Creature Roles

- Listener/chaser: elongated or partially obscured head, strong running silhouette.
- Watcher: mostly static figure whose face/eyes remain readable at medium distance.
- False Door: no bespoke creature model is required for the first pass; reuse the modular house doorway with an alternate inner surface, thin red threshold seam, and pulse-capable light material.
- The Unlit: the warning band must switch between cyan held and red moving states without swapping the whole material. Four-sided visibility is currently intentional unless a replacement provides equivalent readability.
- Ceiling crawler: low profile, wall/ceiling locomotion, folded idle pose; deferred because gameplay is not implemented.

## Environment Support / Builder Contract

- Builder dimensions: 4 m floor/ceiling modules, 3.2 m walls, approximately 2 m x 2.4 m door openings, and low cover below 1.2 m. Imported models can be wrapped and scaled inside prepared kit scenes.
- Floors should keep their top surface at local `Y=0`; wall modules should occupy `Y=0..3.2`; ceiling visuals should sit near local `Y=3.2`.
- Doors need bottom-center pivots. Character assets need ground pivots and forward `-Z`; wrapper nodes can handle source-model corrections.
- Environment modules should use a consistent metric grid, ideally **1 m or 0.5 m increments**.

Useful support assets:

- working and broken light fixtures;
- old intercom/radio and wall telephone;
- handwritten notes, photographs, maps, warning signs, specimen labels;
- beds, wardrobes, desks, chairs, lamps, curtains, rugs, bathroom fixtures;
- maintenance/utility props;
- door variants that visually communicate locked, unsafe, explored, and exit states.

## Import / Asset Requirements

- Prefer GLB/GLTF or Blender source files.
- Separate materials and sensible pivots are more important than high polygon count.
- Creature rigs should include named bones and root motion only when it can be disabled.
- Use wrapper `Node3D` scenes to correct scale, source rotation, pivot/origin, and forward axis instead of changing gameplay transforms.
- Avoid assets whose identity depends on copyrighted characters, logos, or branded props.
- Web target: use practical texture sizes, inspect compression, avoid excessive transparency/unique materials, and do not import a huge unused collection into `res://` merely because it came in one pack.

## Free Candidates To Review

The source list below is preserved from the project notes. **Re-verify the live page, current download availability, and license at the time of selection/download.**

Official pages were previously rechecked on 2026-07-29:

- Kenney Furniture Kit (CC0, 140 models): https://kenney.nl/assets/furniture-kit
- Quaternius Ultimate House Interior Pack (CC0, 123 models): https://quaternius.com/packs/ultimatehomeinterior.html
- Quaternius Ultimate Buildings Pack (CC0, 76 modular models): https://quaternius.com/packs/ultimatetexturedbuildings.html
- Kenney Modular Buildings (CC0, 100 models): https://kenney.nl/assets/modular-buildings
- Kenney Factory Kit (CC0, 140 utility/industrial models): https://kenney.nl/assets/factory-kit
- Poly Haven Worn Wooden Bookshelf (CC0, 10K triangles): https://polyhaven.com/a/wooden_bookshelf_worn
- Sketchfab Creature Rigged (previously listed; page must be manually checked because automated access is blocked): https://sketchfab.com/3d-models/creature-rigged-06d2b90a1e24471283f6aaac748db1c9
- Sketchfab 3D Alien Monster Character (previously listed; manually verify download, rig, and current license): https://sketchfab.com/3d-models/3d-alien-monster-character-adf038b90d8b4631923f0406e80f5194

The Quaternius House Interior pack remains the best first review for complete room dressing. Kenney Factory Kit remains the best first review for the Backrooms service wing, work-light area, and breaker props. Poly Haven's bookshelf is a useful higher-detail accent, not a modular kit.

Creature models still need manual inspection for animation quality, silhouette fit, texture import, forward axis, pivot, and whether their identity matches a specific inhabitant.

## Per-Asset Tracking

When an asset moves beyond `RESEARCHING`, update this file and `docs/asset_credits.md` with:

- role/status;
- exact asset name and author;
- source URL and current license;
- downloaded source/archive path if retained;
- final `res://` path and wrapper scene;
- import settings/texture reductions if important;
- production scene(s) where placed;
- verification result;
- rejection reason if rejected.
