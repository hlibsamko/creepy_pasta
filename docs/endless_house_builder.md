# Endless House Builder

> **Visual-upgrade note:** this document's dimensions and root offsets are hard integration contracts. Adapt imported art with wrapper scenes instead of changing the builder/grid/gameplay layout to fit a model. Preserve the existing False Door fairness/readability rules and the continuous `S -> E` route while replacing art.


The Endless House kit reuses `BackroomsBuilder` rather than maintaining a second generation system. The builder owns layout parsing and gameplay placement; the scene supplies a different visual kit through exported `PackedScene` slots.

## Files

- Demo: `res://scenes/endless_house/endless_house_builder_demo.tscn`
- Shared builder: `res://scripts/backrooms_builder.gd`
- House kit: `res://scenes/endless_house/kit/`
- Builder smoke: `res://scenes/smoke/endless_house_builder_smoke.tscn`

## Kit Contract

- Grid cell: 4 m x 4 m.
- Wall height: 3.2 m.
- Floor tile: 4 m x 4 m, top surface at y = 0.
- Ceiling tile: 4 m x 4 m, centered near y = 3.12 m.
- Light origin: near y = 2.96 m.
- Low furniture/cover: no wider than 3 m and no taller than 1.2 m.
- Gameplay door opening: approximately 2 m wide x 2.4 m high.

Replacement art should preserve these dimensions or wrap the imported model in a compatible kit scene. This keeps layouts, spawn markers, line-of-sight cover, and monster spacing stable.

The kit scene root is also the authoritative local offset for the asset. `BackroomsBuilder` adds the grid cell translation to that root instead of replacing it. Keep the House floor root at y = -0.1 m, wall root at y = 1.6 m, ceiling root at y = 3.12 m, and sideboard root at y = 0.56 m unless a replacement wrapper deliberately changes the contract.

## Current House Kit

- `house_floor_tile.tscn`: neutral dark floor placeholder.
- `house_wall_block.tscn`: cool faded wall with contrasting base trim.
- `house_ceiling_tile.tscn`: low-contrast plaster ceiling.
- `house_ceiling_lamp.tscn`: warm fixture using the shared flicker component.
- `house_low_sideboard.tscn`: low cover and pursuit-breaking furniture placeholder.

The palette is deliberately varied and restrained so future residential assets can replace placeholders without forcing a full lighting rewrite.

## Workflow

1. Duplicate `endless_house_builder_demo.tscn`.
2. Edit the builder node's multiline `layout` in the inspector.
3. Use the same gameplay symbols documented in `docs/backrooms_builder.md`.
4. Use `M` only where a false exit has a fair record, environmental test, or visible pulse clue.
5. Keep at least one continuous route from `S` to `E`; generated chasers do not yet use navigation meshes.
6. Inspect generated floor, wall, ceiling, and furniture heights after assigning replacement kit scenes.
7. Run the builder smoke and the full local smoke suite before adding the room to `Main`.

Generated real and False Doors automatically face the more open corridor axis. Place important doors in short one-axis approaches or dead ends so their orientation and silhouette stay unambiguous.

The current survey layout deliberately presents its evidence record before the False Door and puts the real exit beyond the longer return route. It is a short production level between Backrooms and The Unlit. Its single puzzle record explains how physical details fail in a copy, while safely approaching the dead-end False Door can independently verify the creature's missing-draft behavior. An opened real exit carries animated pale floor-draft streaks and a quiet positional room tone; the False Door receives neither cue.

In a local debug run, physical `F9` still loads the level directly and faces the player down its first generated hall. This preview shortcut is disabled in release builds, dedicated servers, and multiplayer sessions.

## Local Check

```powershell
& 'D:\Soft\Godot_4.6\Godot_v4.6-stable_win64.exe' --headless --path . 'res://scenes/smoke/endless_house_builder_smoke.tscn'
```
