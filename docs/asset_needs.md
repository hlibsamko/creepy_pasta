# Endless House Asset Needs

This is a living list for the user to review after the local gameplay structure is stable. Placeholder geometry remains acceptable until each asset has a clear gameplay role.

## Current Priority

- P0 - Listener/chaser: readable humanoid silhouette, idle/search/run animations, no weapon.
- P0 - Survivor: tired indoor clothing, standing idle/talk animations, optional seated pose.
- P0 - Modular old-house interior: walls, frames, doors, ceilings, floors, stairs, railings, and trim.
- P1 - The Unlit: narrow matte silhouette, slow walk/freeze poses, one separately addressable emissive warning band.
- P1 - Watcher: mostly static figure with a readable face/eye region at 8-12 m.
- P1 - Field journal: closed/open book, page stack, and a simple page-turn animation.
- P1 - Maintenance props: work light, breaker panel, pressure plate, fuse boxes, pipes, lockers, carts, and shelves.
- P2 - Room dressing: beds, wardrobes, desks, chairs, lamps, curtains, rugs, and bathroom fixtures.
- P2 - Ceiling crawler: low profile, wall/ceiling locomotion, and folded idle pose. This creature is not implemented yet.

## Replacement Slots

Keep each gameplay root, script, collision shape, trigger area, light, and signal wiring. Replace only the listed visual children.

| Role | Scene | Replace | Target size and pivot |
| --- | --- | --- | --- |
| Listener/chaser | `scenes/common/chaser_monster_basic.tscn` | `Body`, `EyeLeft`, `EyeRight` | 1.8-2.1 m tall, ground pivot, forward `-Z` |
| Watcher | `scenes/common/watcher_monster_basic.tscn` | `Body`, `Eye` | about 2.2 m tall, ground pivot in an added wrapper |
| The Unlit | `scenes/common/light_shy_monster_basic.tscn` | `Body/Silhouette`, four `FaceGlow*` markers | about 2.2 m tall, ground pivot, separate emissive material slot |
| Survivor | `scenes/common/survivor_npc_basic.tscn` | `Body`, `Head` | 1.65-1.85 m tall, ground pivot, forward `-Z` |
| Real exit | `scenes/common/level_exit_basic.tscn` | `Door`, `Glow` | opening about 2.0 x 2.4 m, bottom-center pivot; preserve `DraftCue` |
| False Door | `scenes/common/mimic_door_basic.tscn` | `Door`, `Glow`, `FalseSeam` | same silhouette as real exit, separate pulse/seam materials |
| Work light | `scenes/common/pressure_powered_spotlight_basic.tscn` | `Housing` | ceiling/wall fixture around the existing `SpotLight3D` origin |
| Breaker | `scenes/common/breaker_outage_trigger_basic.tscn` | `Panel/Housing`, `Panel/Indicator` | wall pivot, separate ready/spent indicator material |
| Pressure plate | `scenes/common/pressure_plate_basic.tscn` | `Plate` | footprint no larger than the existing trigger |
| House modules | `scenes/endless_house/kit/*.tscn` | mesh children only | 4 m cells, 3.2 m wall/ceiling height, cover below 1.2 m |

## Creature Roles

- Listener/chaser: elongated or partially obscured head, strong running silhouette.
- Watcher: mostly static figure whose face/eyes remain readable at medium distance.
- False Door: no bespoke creature model is required for the first pass; reuse the modular house doorway with an alternate inner surface, thin red threshold seam, and pulse-capable light material.
- The Unlit: the warning band must switch between cyan held and red moving states without swapping the whole material. Four-sided visibility is currently intentional.
- Ceiling crawler: low profile, wall/ceiling locomotion, folded idle pose.

## Environment Support

- Builder dimensions: 4 m floor/ceiling modules, 3.2 m walls, approximately 2 m x 2.4 m door openings, and low cover below 1.2 m. Imported models can be wrapped and scaled inside the prepared kit scenes.
- Floors should keep their top surface at local `Y=0`; wall modules should occupy `Y=0..3.2`; ceiling visuals should sit near local `Y=3.2`.
- Doors need bottom-center pivots. Character assets need ground pivots and forward `-Z`; wrapper nodes can handle source-model corrections.

- Working and broken light fixtures.
- Old intercom/radio and wall telephone.
- Handwritten notes, photographs, maps, warning signs, and specimen labels.
- Beds, wardrobes, desks, chairs, lamps, curtains, rugs, and bathroom fixtures.
- Door variants that visually communicate locked, unsafe, explored, and exit states.

## Requirements

- Prefer GLB/GLTF or Blender source files.
- Separate materials and sensible pivots are more important than high polygon count.
- Creature rigs should include named bones and root motion only when it can be disabled.
- Environment modules should use a consistent metric grid, ideally 1 m or 0.5 m increments.
- Avoid assets whose identity depends on copyrighted characters, logos, or branded props.

## Free Candidates To Review

Official pages rechecked on 2026-07-29:

- Kenney Furniture Kit (CC0, 140 models): https://kenney.nl/assets/furniture-kit
- Quaternius Ultimate House Interior Pack (CC0, 123 models): https://quaternius.com/packs/ultimatehomeinterior.html
- Quaternius Ultimate Buildings Pack (CC0, 76 modular models): https://quaternius.com/packs/ultimatetexturedbuildings.html
- Kenney Modular Buildings (CC0, 100 models): https://kenney.nl/assets/modular-buildings
- Kenney Factory Kit (CC0, 140 utility/industrial models): https://kenney.nl/assets/factory-kit
- Poly Haven Worn Wooden Bookshelf (CC0, 10K triangles): https://polyhaven.com/a/wooden_bookshelf_worn
- Sketchfab Creature Rigged (previously listed; page must be manually checked because automated access is blocked): https://sketchfab.com/3d-models/creature-rigged-06d2b90a1e24471283f6aaac748db1c9
- Sketchfab 3D Alien Monster Character (previously listed; manually verify download, rig, and current license): https://sketchfab.com/3d-models/3d-alien-monster-character-adf038b90d8b4631923f0406e80f5194

The Quaternius House Interior pack is the best first review for complete room dressing. Kenney Factory Kit is the best first review for the Backrooms service wing, work-light area, and breaker props. Poly Haven's bookshelf is a useful higher-detail accent, not a modular kit.

Creature models still need manual inspection for animation quality, silhouette fit, texture import, forward axis, pivot, and whether their identity matches a specific inhabitant.
