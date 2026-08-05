# Environment Branch Research

Research checked on 2026-08-02 before the first branch batch.

## Godot Technical Baseline

- Jumping follows Godot's `CharacterBody3D` pattern: apply an upward velocity only while `is_on_floor()` and let `move_and_slide()` handle collision response. Reference: https://docs.godotengine.org/en/4.6/getting_started/first_3d_game/06.jump_and_squash.html
- The Web build uses the Compatibility renderer. Godot volumetric fog and screen-space reflections are unavailable there, while depth/height fog, ReflectionProbe, glow, adjustments, and transparent mist geometry are supported. References:
  - https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
  - https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html
- Branch scenes should own one `WorldEnvironment`; the current loaded level replacement keeps that contract straightforward. Reference: https://docs.godotengine.org/en/4.6/classes/class_worldenvironment.html

## First Asset Batch

- Kenney Furniture Kit: 140 CC0 3D models, selected GLBs only. https://kenney.nl/assets/furniture-kit
- Poly Haven Interior Tiles: CC0 ceramic tile material, reduced to 1K diffuse/OpenGL-normal maps for Web. https://polyhaven.com/a/interior_tiles
- Quaternius Ultimate House Interior remains a candidate for later residential branches: 123 CC0 models in FBX/OBJ/Blend. https://quaternius.com/packs/ultimatehomeinterior.html
- Quaternius Modular Sci-Fi Megakit is a later candidate for transit/service/boiler branches; the free portion provides grid-based GLTF modules under CC0. https://quaternius.com/packs/modularscifimegakit.html

## First Three Branch Identities

- Backrooms: retained as the reference for repetitive navigation, fluorescent sound, and sparse pursuit.
- Dreamcore schoolhouse: oversized familiar props, false daylight, pastel rooms, symbolic landmarks, and no mandatory chaser in the first study.
- Poolrooms: tiled geometry, shallow reflective water, depth fog, echoes, and one distant slow threat only after the traversal reads clearly.
- Empty mall: use the shared modular builder for a shuttered concourse study, existing selected CC0 furniture for kiosks/dressing, and a cold ambient/warm-wayfinding lighting split. Quaternius Downtown City MegaKit is the reference for later storefront/window modules (CC0): https://quaternius.com/packs/downtowncitymegakit.html. Poly Haven Floor Tiles 02 is the candidate 1K floor material (CC0): https://polyhaven.com/a/floor_tiles_02.
- Endless hotel: reuse selected Kenney Furniture Kit doors/radio and the project False Door rather than adding another chaser. Quaternius Ultimate House Interior is the later CC0 source for beds and richer door/window variants: https://quaternius.com/packs/ultimatehomeinterior.html. Poly Haven Dirty Carpet is the candidate reduced 1K floor material: https://polyhaven.com/a/dirty_carpet.

The first studies should compare atmosphere and navigation before adding more monsters. Visual inspection matters more than expanding task count.
