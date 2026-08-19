# The Unlit

> **Visual replacement contract:** The Unlit is already a production/server-authoritative inhabitant. Visual work may replace/wrap `Body/Silhouette` and the warning presentation, but must preserve the gameplay root/path, server-owned position/illumination/contact behavior, light/occlusion rules, and readable cyan-held versus red-moving state. Do not simplify this feature to an experimental local-only creature.


`The Unlit` is the fourth production inhabitant. It advances slowly while outside a player's flashlight and stops when an unobstructed spotlight cone reaches it.

## Files

- Behavior: `res://scripts/light_shy_monster.gd`
- Minimal visual scene: `res://scenes/common/light_shy_monster_basic.tscn`
- Pressure-powered work light: `res://scenes/common/pressure_powered_spotlight_basic.tscn`
- One-shot breaker trigger: `res://scenes/common/breaker_outage_trigger_basic.tscn`
- Evidence chamber: `res://scenes/endless_house/unlit_evidence_demo.tscn`
- Behavior smoke: `res://scenes/smoke/light_shy_monster_smoke.tscn`
- Evidence-loop smoke: `res://scenes/smoke/unlit_evidence_demo_smoke.tscn`
- Deterministic visual capture: `res://scenes/smoke/unlit_evidence_visual_capture.tscn`

The cone test follows Godot's documented `SpotLight3D` contract: light travels along local `-Z`, `spot_angle` is the angular radius, and `spot_range` is the hard distance limit. A physics ray rejects flashlight holds through walls.

References:

- https://docs.godotengine.org/en/4.6/classes/class_spotlight3d.html
- https://docs.godotengine.org/en/4.6/tutorials/physics/ray-casting.html

## Counterplay

- One player can hold a focused beam on the creature while another moves or solves a short task.
- A reusable work spotlight can be wired to any existing pressure plate, allowing one player to hold power while another crosses the threatened space.
- In the evidence chamber the work light is mounted above player height, preventing the holder standing on the plate from occluding the light ray at its origin.
- The work light listens to local plate changes and also polls `is_active()`, so a server-applied `set_synced_active()` state powers it after late join/Restart without emitting a second plate RPC.
- `trigger_outage()` temporarily suppresses an otherwise active plate. `get_outage_state()` and `apply_outage_state()` preserve the remaining outage for future server snapshots, late join, and Restart restoration.
- Turning away, exceeding the spotlight range, or placing solid cover between the light and creature lets it advance.
- A short illumination hold prevents movement flicker at the edge of the cone.
- Multiple instances keep independent light and movement state.

This is intentionally different from the Watcher. The Watcher punishes sustained gaze; The Unlit rewards spending flashlight attention. Combining them later can create a readable conflict, but they should not share a first encounter.

## Evidence Chamber

The production chamber is a short builder-authored first encounter:

1. A Match Dots maintenance record states that a silhouette held its chalk mark while a work lamp faced it.
2. A one-player non-latching pressure plate powers a cold work spotlight across the threatened hall.
3. The powered cone holds one generated `U` creature while another player crosses toward the exit.
4. A one-shot passage trigger after the creature starts a timed breaker outage even though the first player still holds the plate.
5. The crossing player must use their own flashlight while the fixed lamp recovers, proving the same rule under pressure.

The complete route is now authored through the builder layout. `R` generates the hold plate and ceiling work light, `U` generates the creature, and `T` generates the breaker trigger. The builder aims each work light at its nearest `U` and links each trigger to its nearest work light, so duplicating the encounter no longer requires hand-maintained `NodePath` values.

The chamber follows House Survey and leads into Corridor in both offline and online level sequences. Its maintenance record carries optional Unlit fact 1, the first server-approved illumination carries optional fact 2, and the breaker carries optional fact 3. The journal section stays hidden until discovered and remains outside the required three-creature/nine-fact victory count for now.

The breaker trigger and lamp snapshot separately: one records whether the one-shot event was already spent, and the other records remaining outage time. Applying either snapshot is silent and never emits duplicate evidence.

Both expose the shared `get_sync_state()` / `apply_sync_state()` contract. `Main` collects those dictionaries by stable level-relative node path, and online session sync transports the resulting `level_mechanic_states` field through join, respawn, reset, and level transition.

The chamber has complete server authority definitions and is part of `SESSION_LEVEL_PATHS`. In online authoritative mode, entering the breaker area emits a request instead of mutating the local trigger or lamp. The server accepts only the exact generated breaker path while the session's bounded player position is inside its activation radius, marks the breaker spent, grants optional fact 3, and stores an absolute outage deadline. Restart and late-join snapshots derive their own remaining seconds from that deadline, so an old snapshot cannot restart a finished outage. The exit requires both the record and spent breaker; the hold plate powers the crossing light but is deliberately not a permanent exit requirement.

Main-state smoke compares the staged record, plate, creature observation, breaker, work-light, and exit paths with the generated scene. It rejects the breaker from spawn, accepts it at the panel, verifies the one-shot deadline and journal fact, restores an active Restart snapshot, and expires a later join snapshot while retaining the spent breaker. Dedicated smoke additionally proves a production Room 1 session cannot replay the staged Unlit breaker path.

The staged online creature state is now server-owned as well. Each online session stores an independent position and illuminated flag for the exact generated creature path. The server chooses only players belonging to that session, follows the chamber's authored walkable grid at the scene's 2.2 m/s speed, and broadcasts snapshots at 10 Hz. Clients that receive one of those snapshots disable local targeting and physics, apply the approved position, and update the cyan/red tell without emitting a duplicate observation.

Player flashlight cones use the server's bounded player transform, the player scene's range and angle, and a grid line test that rejects beams crossing solid layout cells. The fixed work light uses its authored origin, aim, range, pressure source, and the server's absolute outage deadline. The first approved illuminated transition grants fact 2 from server state rather than trusting a client event. Late join receives the current creature snapshot; Restart resets the creature and contact latch to the authored spawn while preserving records and mechanic state; full session reset and level transition clear it.

Main-state smoke protects clear-beam hold, wall occlusion, authored movement speed, work-light hold, active outage movement, deadline recovery, per-session target isolation, journal evidence, and client snapshot restoration. The normal dedicated route smoke passes the expanded session RPC through create, Restart, Room 1, Room 2, Backrooms, House Survey, and Corridor; the two-session smoke still preserves isolated progress.

Its smoke test protects record wording and metadata, direct-observation metadata, record-to-power-to-creature-to-outage-to-exit route order, generated-node counts, source resolution, one-shot evidence emission, silent synchronized state, light release, timed suppression, and automatic recovery. Two physical controlled-player probes additionally enter the record, hold switch, and breaker areas through their actual physics signals. Main-state smoke also destroys and regenerates the full chamber before applying its plate, light, breaker, and exit snapshot, matching Restart/late-join restoration order instead of reusing the original nodes.

## Evidence Loop Before Production

1. Environmental record: a maintenance silhouette remains in the same survey mark only while a work lamp faces it. Implemented as optional fact 1 in the production chamber.
2. Direct observation: the creature visibly changes its face light and stops when the player's beam reaches it. Implemented as optional fact 2 on first valid illumination.
3. Survival proof: a short breaker outage forces players to alternate movement and flashlight coverage. Implemented as optional fact 3 through the chamber's one-shot passage trigger.

All three evidence sources are now in the production chamber. Breaker, outage, exit, Restart, late-join state, position, targeting, illumination, movement, and contact/death are server-owned and smoke-covered. Sustained contact is latched so one collision cannot emit duplicate death RPCs, and separation or Restart clears the latch.

In a local debug build, start an offline game and press physical `F8` to load the chamber with the normal player, HUD, journal, and input path. After the record puzzle is solved, a debug-only assist holds the co-op plate so one tester can cross. The exit remains closed until the tester reaches and spends the breaker, then the normal exit returns to a playable Room 1 and restores the pre-preview production record count while retaining optional journal observations.

The `F8` shortcut is rejected in Web, dedicated-server, release, and multiplayer contexts; it remains only as a fast desktop debug entry, while the same chamber is reached normally in production sequencing.

The chamber uses sparse warm ceiling fixtures for spatial readability, while only the cold focused work light belongs to `unlit_stopping_lights`. Deterministic frames under `build/unlit_evidence_capture_builder/` recheck the fully generated `R/U/T` version: the survey record under a player-like flashlight, the cyan held state from automatic work-light aiming, the red outage state, and the spent breaker panel.
