# Creepy Pasta Roadmap

This is the high-level project plan for moving the game from a working prototype toward a polished browser-based co-op horror game.

## Current State

The project already has the technical foundation:

- Godot 4.6 browser client
- Oracle dedicated WebSocket server
- HTTPS site at `https://creepy-pasta.duckdns.org`
- WSS multiplayer through `wss://creepy-pasta.duckdns.org`
- Level scenes, notes, portals, player spawning, and basic multiplayer
- Deployment workflow for Web client plus dedicated server

The next goal is not simply "more content". The priority is a small, stable, clear co-op horror session that feels complete.

## Operating Instructions

Use this file as the source of truth before and during work to avoid context degradation.

- Input requirement: movement and action bindings must stay on physical keys/scancodes, not layout-dependent letters, so non-English keyboard layouts keep working.
- Prefer local testing over server deployment. Deploy to the server only after a larger coherent chunk is done and local checks have passed.
- Push to GitHub no more than once every 4 hours.
- UI should be polished, convenient, and not overloaded.
- Prefer existing Godot addons, proven open-source implementations, or well-known patterns for complex features instead of inventing everything from scratch.
- Add multiple different puzzle types, not repeated variations of a single puzzle.
- Build a map/level builder so new levels can be assembled conveniently. Prefer native Godot editor tooling: prepared assets, scenes, nodes, and editor-friendly workflows.
- Start the builder with a Backrooms-style level kit.
- Add several monster mechanics, abilities, and visual variants.
- Support multiple monsters existing at the same time without blocking or interfering with each other.
- Add a continuous day/night system where cycle length is adjustable.

Backrooms builder baseline:

- Builder script: `res://scripts/backrooms_builder.gd`.
- Builder docs: `docs/backrooms_builder.md`.
- Demo scene: `res://scenes/backrooms/backrooms_builder_demo.tscn`.
- Kit scenes live under `res://scenes/backrooms/kit/`.
- Layout symbols: `#` wall block, `.` walkable floor/ceiling, `L` floor/ceiling/light, `S` floor plus spawn `Marker3D`, `E` floor plus exit `Marker3D`, `N` generated note, `W` generated watcher monster, `C` generated chaser monster, `B` low barrier/cover, `P` pressure plate.
- Current builder generates geometry, editor markers, and a basic `LevelExit` from `E`. Designers still place gameplay nodes such as notes and monsters explicitly until the builder grows more gameplay node spawning.
- The builder also supports `N` cells for generated notes with configurable text/puzzle requirements.
- `Main` now reads `SpawnMarker*` nodes from loaded levels before falling back to hardcoded spawn positions.
- `Main` finds generated `LevelExit` nodes recursively, so builder-created exits work inside generated level roots.

Recent local progress:

- Keyboard actions now use physical key bindings in `project.godot`.
- HUD control text no longer depends on English letter labels for movement keys.
- `DayNightCycle` is attached to `Main` and rebinds to each loaded level.
- Local desktop testing can adjust day/night cycle length with physical `F6`/`F7` keys.
- The level sequence now includes the Backrooms builder demo before the corridor.
- Fragment puzzles now support matching dots, sequence locks, and code locks.
- Level 2 now includes a latch-once floor pressure plate that must be activated after collecting fragments to stabilize the exit.
- Pressure plates now depress and brighten when active.
- Pressure plates refresh their occupied-body state after peer disconnects, preventing stale non-latching switches.
- Corridor contains two monster instances, and monster targeting/collision setup is prepared for multiple monsters.
- Fourth room has an open final exit and a victory screen.
- Victory screen now includes a short session summary with recovered fragment count.
- Build version is exposed through `GameVersion`, shown in menu/HUD, and printed by the dedicated server on startup.
- Menu now has reconnect and fullscreen actions; Web builds keep the simplified `Play Online` flow.
- Death and victory screens now have explicit `Retry` and `Menu` actions.
- End-state retry buttons are labeled as `Restart` to make the session reset behavior clear.
- Web play now shows a pointer-lock hint until the player clicks to control the camera.
- Web menu now recommends desktop browsers without exposing server setup controls.
- Join/reconnect/offline buttons are disabled during active connection attempts and restored on timeout/failure/disconnect.
- Late join now receives a server session snapshot with the current level scene path and collected note IDs.
- Late-join session snapshots now also include session collected-note count, pressure plate states, and note-gated monster activation states.
- Note collection now goes through a server-approved request/broadcast flow instead of client-side collection broadcast.
- Corridor and Backrooms kit lights now use a reusable flicker component for atmosphere.
- Corridor monster startup delay now uses an owned `Timer`, so standalone scene smoke checks exit cleanly.
- Backrooms builder `E` cells now create a reusable gameplay `LevelExit` from `res://scenes/common/level_exit_basic.tscn`.
- Server-side event logs now cover startup, peer connect/disconnect, spawn requests, note collection, duplicate/missing note ignores, session sync, and level transitions.
- Players expose sprinting state, and corridor monsters prefer/accelerate toward sprinting targets within hearing range.
- Chaser monsters can now stay dormant until a configured number of notes is collected; the reusable Backrooms chaser activates after the first note.
- Progress-gated monster activation now gives a short UI/audio threat cue.
- Progress-gated monster activation is logged server-side without trying to drive UI on dedicated servers.
- First level now has an entry radio dialogue that gives the opening premise and objective.
- Reconnect reuses the last join address, and connection attempts time out with a useful status instead of hanging forever.
- Manual reconnect/retry/menu/timeout closes now suppress their expected disconnect callback briefly, preventing stale disconnect UI from overwriting the active flow.
- Final victory now uses a server-approved request/broadcast flow so all peers receive the end state.
- Server ignores transition/victory requests when the exit is closed or a transition is already running.
- Late-join session snapshots now include explicit exit-open state, not only collected note IDs.
- Corridor monster behavior is more editor-tunable, and the second corridor monster now has a distinct speed/hearing/death-text/tint variant.
- HUD now includes a compact level objective that changes per level and updates when the exit opens.
- Starting and entering levels now shows a short level banner so scene changes read as progress.
- `AudioCues` now provides lightweight procedural sounds for note pickup, exit opening, and victory.
- Backrooms builder `N` cells now create notes, and `Main` discovers notes recursively so builder-generated notes count and sync.
- Backrooms builder generated content is now grouped into `Geometry`, `Markers`, `Mechanics`, `Notes`, and `Monsters` under `GeneratedBackrooms`.
- Fourth room now includes a watcher monster that punishes prolonged direct staring, adding a non-chase threat variant.
- Fourth-room objective and warning note now teach the watcher rule before the player commits to the final exit.
- Watcher gaze checks require line of sight, so walls and obstacles can break the stare.
- Watcher line-of-sight checks now ignore the viewer's own body collision.
- Local controlled players now have lightweight procedural footstep sounds with different walk/sprint cadence.
- `AudioCues` now plays a quiet procedural ambience bed that changes per loaded level.
- Code-lock puzzles are available for notes and Backrooms-generated notes.
- Code-lock puzzles now show a short numeric clue instead of directly exposing the answer.
- Backrooms builder `W` cells now create reusable watcher monsters, and `Main` discovers monster signals recursively.
- Backrooms builder `C` cells now create reusable chaser monsters with sprint-hearing behavior.
- Backrooms builder `C` chasers start dormant and activate after note progress by default.
- Chaser monsters now support optional idle patrol radius; the reusable Backrooms chaser patrols when it has no target.
- Backrooms builder `B` cells now create low barriers/cover for navigation and watcher line-of-sight breaks.
- Backrooms builder `P` cells now create reusable pressure plates.
- `AudioCues` and player footsteps now skip playback in headless/dedicated runs and release procedural audio streams/players cleanly during local smoke exits.
- Web deploy Caddy config now serves `index.html` uncached and Godot asset files with long immutable caching.
- Oracle deploy scripts now keep one previous-version rollback point, and `deploy/rollback_oracle.ps1` can rollback server, web, or both.
- `deploy/local_smoke.ps1` now runs the standard local smoke suite, with optional `-Exports` for Linux dedicated and Web exports.
- `deploy/local_smoke.ps1` now fails on Godot script/load error output even when Godot exits with code `0`.
- Latest checks used `deploy/local_smoke.ps1 -Exports`, including local Godot headless startup, scene smoke checks, local dedicated-server startup, local Linux dedicated export, local Web export, and deploy-script syntax checks only; no server deploy and no GitHub push.

## 1. Game Loop

Make the player's objective clear and satisfying:

- Add a stronger opening: where the player is and why they are there.
- Make each level objective obvious: collect fragments, solve the local problem, open the exit.
- Make level completion feel like progress, not just a scene swap.
- Add an ending: win screen, final reveal, or multiple endings.

The target is a complete 5-10 minute playable session before expanding scope.

## 2. Multiplayer Stability

The server should be the authority for the session.

Needed work:

- Stable join and reconnect behavior.
- Late-joining players receive the current level state.
- Disconnected players are removed cleanly.
- Collected notes sync correctly.
- Opened doors and portals sync correctly.
- Level transitions are initiated and approved by the server.
- Duplicate RPC calls are ignored safely.
- Game state lives on the server instead of being scattered across clients.

Rule of thumb: clients request actions; the server decides and broadcasts the result.

## 3. Web Entry UX

The browser version should be almost frictionless:

- Show one primary button: `Play Online`.
- Hide manual server address input in Web builds.
- Hide or remove `Host` in Web builds.
- Show a loading/connecting state.
- Show useful connection errors.
- Add a reconnect button.
- Add fullscreen support.
- Add a clear "click to control mouse" hint after joining.
- Keep desktop browser as the intended platform.

The player should not need to understand `wss://`, ports, or hosting.

## 4. Atmosphere

Raise the horror quality with sound and environmental detail:

- Footstep sounds.
- Ambient loops.
- Note pickup sounds.
- Portal and door sounds.
- Light changes based on player progress.
- More room detail and silhouettes.
- Carefully paced scares, not constant jumpscares.
- Unique mood for every level.

The goal is tension and anticipation before direct danger.

## 5. Monster And Threat Design

Define what the danger actually is.

Possible directions:

- Monster patrols.
- Monster hears sprinting.
- Monster appears after notes are collected.
- Monster reacts to being looked at.
- Monster targets the nearest or loudest player.
- One player can accidentally endanger both players.

For co-op horror, the strongest design is often asymmetric information: one player notices something the other does not.

## 6. Puzzles

Keep puzzles short and cooperative:

- Code doors.
- Symbol sequences.
- Split clues between players.
- Carry or place items.
- One player holds a switch while another moves.
- Environmental clues tied to notes.

Avoid long puzzle pauses that kill horror pacing.

## 7. Level Structure

Give each level a distinct purpose:

- Level 1: onboarding and basic fear.
- Level 2: first real co-op interaction.
- Corridor: tension and pursuit.
- Fourth room: escalation or twist.
- Final level: payoff and ending.

Each level should introduce either a new mechanic, a new threat behavior, or a new narrative beat.

## 8. UI And Onboarding

Minimum polish needed:

- Clear start menu.
- `Play Online` for Web.
- Loading/connecting UI.
- Connection failed UI.
- Reconnect option.
- Death screen.
- Victory/end screen.
- Control hints.
- Small player/session status display.
- Build version visible somewhere unobtrusive.

## 9. Technical Reliability

Before wider playtesting:

- Add build version to client and server.
- Add server event logs.
- Keep Web client and dedicated server built from the same commit.
- Keep deploy as close to one command as possible.
- Add smoke checks after deploy.
- Add rollback notes or rollback script.
- Improve browser cache handling.
- Document known failure signals and fixes.

Existing workflow source of truth: `docs/workflow.md`.

## 10. Browser Polish

Needed for a smoother public build:

- Fullscreen button.
- Better pointer-lock UX.
- Cache-control headers in Caddy.
- Desktop browser recommendation.
- Autoconnect or one-click connect in Web.
- No exposed host/server setup controls for normal players.

## Recommended Order

1. Make Web entry one-click: `Play Online`, hidden address field, no Host button, clear connection states.
2. Add build version and improve deploy confidence.
3. Strengthen server-authoritative multiplayer state.
4. Run a full two-player browser playtest and list all desyncs.
5. Build one complete 5-10 minute game loop with a start, middle, and ending.
6. Add sound and stronger atmosphere.
7. Add one memorable co-op puzzle.
8. Prepare a public playtest build.

## Definition Of "Close To Ideal"

The game is close to ideal when:

- A player opens the website and starts without technical knowledge.
- Two players can finish a full session without reconnecting or desyncing.
- Every level has a clear purpose.
- The horror comes from pacing, sound, space, and uncertainty.
- The server and browser build are always in sync.
- Bugs can be reproduced, fixed, deployed, and verified quickly.
