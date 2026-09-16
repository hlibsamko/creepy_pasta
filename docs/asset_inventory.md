# Production asset inventory

This ledger answers one practical question: where is each downloaded visual actually visible in the game?

## New bounded package — 2026-09-16

| Asset | Wrapper | Authored production placement | Preparation | Acceptance |
| --- | --- | --- | --- | --- |
| 3D Assets ceiling-mounted classroom projector | `scenes/props/dreamcore_classroom_projector.tscn` | `scenes/branches/dreamcore/dreamcore_schoolhouse.tscn`: `Environment/Props/DreamcoreClassroomProjector`, position `(24, 4.3, 24)`, yaw `180°`, above empty chairs | Blender 5.1.1, height 0.78m, centered bottom pivot, cosmetic trim mapped to housing/dark materials; glass lens and individual parts retained. Recipe: `tools/asset_pipeline/recipes/dreamcore_classroom_projector.json`. Source: https://3dassets.dev/assets/university-lecture-hall-and-campus-ceiling-projector-m-3875de72 | Authored placement only; Godot import, visual and performance QA not run. Visual-only suspended prop, no collision or light |
| Poly Haven Painted Wooden Bench, Kirill Sannikov | `scenes/props/poolrooms_painted_bench.tscn` | `scenes/branches/poolrooms/poolrooms_gallery.tscn`: `Environment/Props/PoolroomsPaintedBench`, position `(9, 0.06, 3)` beside the entry | Blender 5.1.1, self-contained GLB, textures capped at 512px, width 1.6m; the already small geometry was retained. Recipe/card: `tools/asset_pipeline/`. Source: https://polyhaven.com/a/painted_wooden_bench | Placed in scene; Godot import, visual, collision and performance QA not run |

The new package also includes poly.alchemist's open school locker from https://polyalchemist.itch.io/lockers-and-storage-rack-pack-1. Wrapper: `scenes/props/dreamcore_school_locker.tscn`; production placement: `scenes/branches/dreamcore/dreamcore_schoolhouse.tscn`, `Environment/Props/DreamcoreSchoolLocker`, position `(12, 0, 3.3)`, yaw `90°`. Blender 5.1.1 extracted only four named assembly parts from the source pack and normalized height to 2.7m with a ground pivot. Recipe: `tools/asset_pipeline/recipes/dreamcore_school_locker.json`. Collision is a separate sibling of `Visuals`. Godot import, visual, collision and performance QA were not run.

The downloaded locker pack was removed after processing and authored placement; the final GLB, source URL and recipe remain available for recovery.

The owned downloaded projector source was also removed after preparation and authored placement, freeing 45,792 bytes. The final production GLB, recipe and recorded CDN URL remain; recovery is by re-downloading and rerunning the recipe, subject to future source availability.

## Earlier placements

| Asset/pack | Wrapper | Production placement | Status | Next action |
| --- | --- | --- | --- | --- |
| Kenney bear | `scenes/props/kenney_bear_visual.tscn` | Dreamcore Schoolhouse: `Environment/Props/OversizedBear` | production | Replace only when a more distinctive dreamcore hero prop is integrated. |
| Kenney chair | `scenes/props/kenney_chair_visual.tscn` | Dreamcore Schoolhouse empty chairs; Empty Mall waiting chair; Endless Hotel luggage barrier | production | Keep transforms in owning scenes/kits. |
| Kenney plant | `scenes/props/kenney_plant_visual.tscn` | Dreamcore Schoolhouse plant; Empty Mall dead plants | production | Keep transforms in owning scenes. |
| Kenney radio | `scenes/props/kenney_radio_visual.tscn` | Dreamcore Schoolhouse silent radio; Endless Hotel night radio; Endless House sideboard | production | Shared wrapper owns model orientation and base scale. |
| Kenney doorway | `scenes/props/kenney_doorway_visual.tscn` | Poolrooms impossible doorway; Endless Hotel room doors | production | Keep route-specific transforms in owning scenes. |
| Kenney bathroom sink | `scenes/props/kenney_bathroom_sink_visual.tscn` | Poolrooms Gallery: `Environment/Props/Sink` | production | Replace only through this wrapper. |
| Kenney shower | `scenes/props/kenney_shower_visual.tscn` | Poolrooms Gallery: `Environment/Props/Shower` | production | Replace only through this wrapper. |
| Kenney desk | `scenes/props/kenney_desk_visual.tscn` | Empty Mall kiosk, Dreamcore barrier, Endless House sideboard | production | Shared wrapper; collision remains in each owning kit scene. |
| Kenney bathtub | `scenes/props/kenney_bathtub_visual.tscn` | Poolrooms low-barrier kit | production | Collision remains in the Poolrooms kit scene. |
| Poly Haven Gothic Cabinet 01 (1K glTF) | `scenes/props/polyhaven_gothic_cabinet_visual.tscn` | House Survey repeated sideboard: `HouseLowSideboard/Visuals/Furniture/GothicCabinetVisual` | production | The House kit owns the collision and fitted transform; replace only through the wrapper. |
| Poly Haven School Chair 01 (1K glTF) | `scenes/props/polyhaven_school_chair_visual.tscn` | Dreamcore Schoolhouse: `Environment/Props/EmptyChairA` and `EmptyChairB` | production | Dreamcore owns the deliberately oversized transforms. |
| Poly Haven Green Chair 01 (1K glTF) | `scenes/props/polyhaven_green_chair_visual.tscn` | Empty Mall: `Environment/Props/WaitingChair` | production | Empty Mall owns the placement transform. |
| Poly Haven Cassette Player (1K glTF) | `scenes/props/polyhaven_cassette_player_visual.tscn` | Dreamcore `SilentRadio`; Endless Hotel `NightRadio` | production | Shared wrapper keeps imported contents isolated from level scenes. |
| Quaternius monster | chaser visual child | Ordinary chaser production route | production-temporary | Replace or improve in a dedicated monster batch. |
| Poly Haven interior tiles | material imports | Selected interior surfaces | production-partial | Map exact scene/material consumers during level cleanup. |

Do not mark a future download complete until its wrapper and exact production scene/kit placement are listed here.
