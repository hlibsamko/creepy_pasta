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

