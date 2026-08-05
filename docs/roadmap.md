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

## Product Direction: The Endless House

The game is moving toward an almost endless house whose inhabitants can only be escaped by understanding them.

Core fantasy and progression:

- The opening forces the player to flee from the first creature before receiving a full explanation.
- A survivor NPC explains the encounter and gives the player a field journal.
- Each creature has distinct behavior, warning signs, weaknesses, and several discoverable facts.
- Journal facts can come from direct observation, NPC dialogue, found records, environmental evidence, or risky interaction.
- Rumors may be incomplete or wrong until corroborated.
- The main victory condition is completing the house bestiary, not defeating every creature.
- As the journal fills, the house becomes more dangerous and its inhabitants gain harder behavior variants.
- Additional survivors have their own histories, partial knowledge, and conflicting accounts.
- The hidden story explains why the house has no stable end, where its inhabitants came from, and what happened to earlier researchers.

Near-term implementation order:

1. Build a reusable branch-selection contract so short environment studies can coexist without forcing one linear route.
2. Create and compare the first Backrooms, dreamcore, and poolrooms branches before committing the whole game to one visual language.
3. Grow the branch catalog gradually to 20 distinct studies; each branch must differ in space, atmosphere, traversal, evidence, or threat rule rather than only color.
4. Add physical-key jumping and keep ordinary threats slightly slower than the player's sprint speed.
5. Replace primitive creature and environment placeholders incrementally with compatible existing assets, preserving stable gameplay roots and collisions.
6. Add fog, volumetrics, reflections, particles, and restrained post-processing only where they support a branch's identity and remain viable in Web builds.
7. Keep multiplayer authority, late-join sync, reset, reconnect, and physical-key controls covered as the branch catalog expands.

## Environment Branch Program

Target: 20 short playable branches used to decide the final style and feel of the Endless House.

Initial sequence:

1. Backrooms service maze - yellow offices, fluorescent hum, sparse pursuit.
2. Dreamcore schoolhouse - familiar oversized rooms, false daylight, symbolic navigation.
3. Poolrooms - tiled water halls, reflections, mist, sound-based tension.
4. Empty mall after closing - shuttered shops, escalators, distant announcements.
5. Endless hotel - repeating numbered doors, carpeted silence, room-copy clues.
6. Concrete liminal transit - platforms, tunnels, moving light, no trains.
7. Suburban night loop - repeated facades, fog, windows that change occupants.
8. Abandoned hospital - curtains, service corridors, unreliable intercom guidance.
9. Indoor playground - bright forms, soft obstacles, movement behind mesh.
10. Flooded basement - shallow water, breakers, reflected threat silhouettes.
11. Office after hours - cubicle sightlines, printers, copied workstations.
12. Archive stacks - movable shelves, catalog evidence, constrained visibility.
13. Greenhouse interior - condensation, overgrowth, light-sensitive routes.
14. Museum storage - covered exhibits, observation puzzles, shifting labels.
15. Brutalist stairwell - vertical traversal, landings that repeat incorrectly.
16. Synthetic apartment showrooms - staged domestic copies with missing details.
17. Boiler/service plant - pipes, steam, timed machinery and loud traversal.
18. Snowed-in atrium - cold haze, footprints, large quiet open space.
19. Theatre backstage - curtains, rigging, changing sets and false exits.
20. Impossible attic - low beams, stored memories, final House-lore branch.

Branch production rules:

- Start with short environment studies, not 20 long levels.
- Reuse native Godot scenes/resources and proven addons or open assets where practical.
- Keep a shared gameplay contract for spawn, exit, evidence, ambience, fog/effects profile, and optional threat slots.
- Limit early studies to zero or one ordinary chasing threat; environmental tension and observation mechanics should carry most branches.
- Finish and visually inspect one small branch batch before expanding the next batch.
- Record source, license, import settings, and replacement boundary for every external asset.

Completed Endless House concept foundation:

- Journal facts are independent discoveries rather than cumulative counters; finding fact 3 no longer grants facts 1 and 2.
- The journal stores unverified rumors separately and can visibly mark a rumor as disputed by a specific verified fact.
- NPC dialogue, found records, direct observation, and level survival each provide distinct fact sources.
- The opening chase now stages the Listener behind correctly oriented co-op spawns, places evidence along a forward route, and ends at a narrow readable threshold before Mara.
- The False Door is a third non-chasing creature: it copies an exit, has a learnable two-pulse tell, and kills only a locally controlled player who enters it.
- A hanging-thread threshold test gives the player an explicit interact-to-observe action instead of awarding every fact through automatic proximity.
- Room 2 currently uses two active purposeful records with different short puzzle modes plus a separate co-op floor switch; a third authored record remains disabled for faster testing.
- The shared editor builder now accepts swappable visual `PackedScene` kits, and an Endless House kit can generate residential rooms without duplicating layout/gameplay code.
- Listener knowledge now changes its decisions as well as its speed: it can fixate on the loudest runner, investigate the last heard position, and eventually lead a sprinting target.
- Elias is a second survivor in Backrooms who provides a plausible but false account of the False Door's light pattern; later verified evidence explicitly disputes his rumor.
- The generated House survey now has an authored evidence-to-threat-to-exit route, readable local lighting, and correctly oriented real and False Doors.
- World evidence now has minimal readable paper, survey-panel, and voice-recorder forms instead of presenting every record as the same yellow sphere.
- Watcher knowledge now adds lingering attention and one clear line-of-sight step toward the last observer; its lethal warning never drops below three seconds.
- False Door knowledge now lets it borrow a real exit's warm glow between pulses and eventually conceal its identifying pulse until a player reaches a safe observation range.
- Rumors in the journal now name their source; Mara and Elias have personal histories that explain their evidence rules and disagreement.

## Operating Instructions

Use this file as the source of truth before and during work to avoid context degradation.

- Input requirement: movement and action bindings must stay on physical keys/scancodes, not layout-dependent letters, so non-English keyboard layouts keep working.
- Prefer local testing over server deployment. Deploy to the server only after a larger coherent chunk is done and local checks have passed.
- Push to GitHub no more than once every 4 hours.
- Once per calendar day, when the project has meaningful changes, run the release checkpoint and publish one coherent state: push it to GitHub and deploy the matching Web/server build to the site. Skip the daily publish when nothing changed or the local release checkpoint is red; never deploy a different revision from the one pushed.
- Continue autonomous local development until the user explicitly says `СТОП`; collect non-blocking questions and asset requests for the user instead of waiting.
- Research official documentation, established implementations, addons, and asset packs before implementing a new subsystem; record the chosen reference when it affects architecture.
- Use fewer intermediate test passes. Run only a parse/basic startup check while iterating, then run focused gameplay and visual checks at the end of a coherent branch or feature stage.
- Standard chasing monsters should remain slightly slower than the player's sprint speed. Reserve faster movement for clearly telegraphed short abilities, scripted moments, or difficulty variants.
- Player traversal includes a physical-key jump that works independently of keyboard layout.
- Replace primitive visual placeholders with suitable existing models and materials in staged batches; preserve gameplay roots, collision, signals, and server-owned paths.
- Use fog and other atmospheric effects selectively per environment branch, with Web performance and readability budgets.
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
- Layout symbols: `#` wall block, `.` walkable floor/ceiling, `L` floor/ceiling/light, `S` floor plus spawn `Marker3D`, `E` floor plus exit `Marker3D`, `N` generated note, `D` Match Dots note, `Q` Sequence Lock note, `K` Code Lock note, `O` Polarity Switch note, lowercase `n/d/q/k/o` inactive note placeholders, `W` generated watcher monster, `C` generated chaser monster, `A` late ambush chaser, `M` False Door, `U` The Unlit, `B` low barrier/cover, `P` latch-once pressure plate, `H` one-player hold switch, `G` two-player group hold switch, `R` powered work-light hold station, `T` breaker outage trigger.
- Current builder generates geometry, editor markers, `LevelExit` nodes, generated notes, watcher/chaser/ambush/False Door/Unlit monsters, barriers, pressure-plate variants, work lights, and breaker triggers directly from layout symbols.
- `N` uses the builder-wide generated note puzzle type; `D`, `Q`, `K`, and `O` force specific puzzle types per cell.
- `Main` now reads `SpawnMarker*` nodes from loaded levels before falling back to hardcoded spawn positions.
- `Main` finds generated `LevelExit` nodes recursively, so builder-created exits work inside generated level roots.

Recent local progress:

- Dreamcore and Poolrooms now use a shared native `BranchDefinition` resource and `BranchCatalog` lookup for scene, title, objective, and arrival copy. The main menu builds a minimal local Environment Studies browser from that catalog, and branch exits return to the browser without altering online sessions. Adding a study no longer requires branch-specific UI or objective logic in `Main`.
- The fourth catalog study, Empty Mall: Last Closing, reuses the shared builder with a taller cold-lit concourse kit, closed kiosk barriers, one sequence-log puzzle, sparse CC0 dressing, low fog, and a warm exit landmark. It deliberately has no chaser while the space and wayfinding are evaluated.
- The fifth catalog study, Endless Hotel: Room Zero, uses a carpeted warm corridor kit, repeated CC0 door/radio props, a descending-room-number code lock, and one non-chasing False Door. Its threat rule is observation and door comparison rather than another pursuit.
- The first Dreamcore schoolhouse and Poolrooms comparison studies now have reusable builder kits, distinct Web-compatible fog/lighting profiles, selected CC0 environment props, and tuned visual captures under `build/branch_capture_*_tuned/`. They remain local debug previews until the shared branch-selection contract is ready.
- Physical Space jumping is wired through the existing `CharacterBody3D` floor/gravity pattern, and ordinary chasers are capped below the player's sprint speed.
- Three selected animated CC0 Quaternius candidates replaced importing the complete monster archive. The ordinary chaser now uses the Demon model as a visual child while retaining project-owned AI, collision, warning light, and network paths; Alien and Orc Skull remain comparison candidates.

- Builder symbols `R` and `T` now generate The Unlit's powered work-light station and one-shot breaker directly from the layout. Work lights bind to their own generated hold plate and aim at the nearest `U`; breaker triggers bind to the nearest generated work light.
- The isolated Unlit evidence chamber no longer contains manually placed work-light or breaker nodes. Its complete record-to-power-to-creature-to-outage-to-exit route is builder-authored, while stable generated paths continue to participate in `Main` mechanic snapshots.
- Builder variants smoke now protects generated count, plate/light/trigger binding, inspector range propagation, and nearest-creature aiming. The full local gameplay, UI, monster, dedicated-network, and two-session suite passed after the conversion; no deploy or GitHub push followed.
- A two-encounter builder smoke now creates separate `R/U/T` clusters and proves their plate power, creature hold, breaker outage, and timed recovery remain independent. This protects layouts that contain several simultaneous Unlit creatures instead of only the single chamber.
- `BackroomsBuilder` now exposes native Godot Inspector warnings for empty/uneven grids, unsupported symbols, missing spawn/exit markers, incomplete `R/T/U` mechanics, and equal-distance automatic bindings. A dedicated smoke protects both clean layouts and each warning class.
- The full local suite passed with the paired-mechanic and Inspector-authoring checks, including dedicated networking and two isolated online sessions; no deploy or GitHub push followed.
- Main-state smoke now snapshots the active Unlit plate, work-light outage, spent breaker, and exit, destroys the complete generated level, rebuilds fresh node instances, and restores state in the same plate-to-mechanic-to-exit order used by Restart and late join. Stable generated paths survive the reload.
- Online pressure-state RPCs now accept only level-relative plate paths explicitly whitelisted for the session's current level. Exit evaluation independently counts only those paths, so invented IDs or stale Room 2 IDs cannot satisfy the Backrooms gate.
- Network smoke sends one invalid plate ID in Room 2 and one stale path in Backrooms before the valid requests. The dedicated server logs both rejections, keeps each exit closed, then completes the normal route.
- The PowerShell smoke harness now launches foreground network clients with redirected `Start-Process` streams instead of `cmd` under stop-on-stderr semantics. Diagnostics retain complete stdout/stderr and explicit exit codes without treating a warning line as a PowerShell invocation failure.
- The complete local gameplay, builder, UI, monster, dedicated-network, and two-session suite passed after the pressure whitelist and harness changes; no deploy or GitHub push followed.
- A fresh deterministic render under `build/unlit_evidence_capture_builder/` visually rechecked the fully builder-generated chamber. The record remains flashlight-readable, `R` auto-aim produces the cyan held state, `T` restores the red moving state, and the spent breaker panel/corridor floor remain legible.
- Client-originated journal discoveries are now whitelisted by the session's current level and exact unlock/entry/fact/rumor tuple. A Room 1 client can no longer grant itself Mara's handoff or combine a valid rumor with an unrelated fact.
- Dedicated network smoke now proves a forged Room 1 combined discovery is ignored, the separate radio rumor is accepted without unlocking the journal, and Mara's journal/fact handoff becomes valid only after entering Room 2.
- The longer authority scenario raised the emergency network-client frame cap from 1800 to 3600 while retaining its 20-second real-time watchdog. The full local suite passed after this authority change; no deploy or GitHub push followed.
- Main-state smoke now derives client-driven discovery tuples from every production scene's Dialogue NPCs, Listeners, Watchers, and False Doors, then requires an exact match with the server whitelist. This immediately exposed and fixed a missing Backrooms Watcher observation permission.
- The compact HUD now calls purposeful pickups `Records` instead of the generic internal `Notes`; physical-key control copy and responsive long-message layout remain unchanged and smoke-covered.
- The complete local gameplay, UI, builder, monster, dedicated-network, Restart, and two-session suite passed after the scene-derived discovery contract and HUD copy change; no deploy or GitHub push followed.
- Remote player synchronization now rejects packets from the wrong peer, non-finite transforms, and movement outside a bounded horizontal/vertical token budget. Respawn and level-transition moves reset the accepted baseline so legitimate server teleports do not poison the next client update.
- A dedicated remote-sync smoke protects sender ownership, sustained legal sprinting, delayed packets, horizontal/vertical teleport rejection, NaN rejection, and respawn-baseline recovery.
- Production pressure plates now have server-owned path, position, and activation-radius definitions. A client may release its plate state from anywhere, but activation is ignored unless the session's accepted player position is physically near the matching plate.
- Main-state smoke requires the server pressure definitions to match the exact generated or authored scene paths and positions. Dedicated network smoke proves both Room 2 and Backrooms reject valid plate IDs from spawn, then accept them only after bounded movement reaches the real plate.
- The complete local gameplay, UI, builder, monster, dedicated-network, Restart, and two-session suite passed after movement-budget and pressure-proximity authority changes; no deploy or GitHub push followed.
- Every client-originated journal request now identifies the exact level-relative scene source. The whitelist distinguishes separate monsters that award the same fact, so a valid tuple cannot be replayed under an unrelated radio, NPC, or creature path.
- Explicit dialogue evidence has server-owned positions and interaction radii. Radio, Mara, Elias, Final Intercom, and Hanging Thread discoveries are rejected when the reporting player's bounded position has not reached the matching scene object.
- Main-state smoke now compares source-aware discovery definitions against every production DialogueNpc, Listener, Watcher, and False Door node, including generated names and authored positions. Dedicated network smoke rejects the correct Room 1 radio and Mara handoff from out of range, then accepts each after bounded movement reaches its source.
- The complete local gameplay, UI, builder, monster, dedicated-network, Restart, and two-session suite passed after source-aware journal validation; no deploy or GitHub push followed.
- Note-gated Listener activation is now derived from server-owned record progress. The server stores and broadcasts each exact monster activation path, and grants the Listener fact itself at the authored thresholds instead of accepting activation reports from clients.
- Main-state smoke compares server thresholds against every note-gated Listener in production scenes. Dedicated network and two-session checks confirm the first Room 1 record grants the fact independently and remains isolated/reset correctly.
- The complete local suite passed after moving Listener activation to server-owned progress rules; no deploy or GitHub push followed.
- Watcher observations now require the reporting peer's accepted camera to be within the authored trigger range and facing the exact scene source. False Door observations require the peer to reach its own shorter authored range.
- Dedicated network smoke rejects the Backrooms Watcher from afar and while faced away, accepts it after a bounded move and turn, and rejects the House False Door from spawn. Main-state smoke keeps every observation position/range/facing rule aligned with the actual generated and authored monster nodes.
- Every active production record now has a server-owned position and collection radius. Valid note IDs requested from outside their real Area3D are ignored, while ordinary body-entry and puzzle-completion requests still succeed near the record.
- Main-state smoke compares all record positions with Room 1, Room 2, Backrooms, House Survey, and final-room scene transforms. The dedicated route now physically moves through each evidence source, and the two-session clients do the same while retaining reset/isolation coverage.
- The longer authority route raised only its emergency frame cap from 7200 to 12000; its independent 90-second scenario watchdog remains active.
- The complete local gameplay, UI, builder, monster, dedicated-network, Restart, and two-session suite passed after observation and record-proximity authority changes; no deploy or GitHub push followed.
- Every production exit now has a server-owned position and activation radius. An open gate no longer accepts a transition or final-victory request from a peer elsewhere in the level.
- Main-state smoke keeps all six authored/generated exit positions aligned with their scene nodes. Dedicated network smoke proves an open Room 1 exit rejects a remote transition, then traverses Room 1, Room 2, Backrooms, and House only after bounded movement reaches each real doorway.
- The complete local suite passed after exit-proximity authority, including Restart and two-session isolation; no deploy or GitHub push followed.
- Remaining authority boundary: Watcher line of sight is still evaluated in the local scene because the multiplexed server has no collision world per session. Puzzle completion is proximity-gated but not independently recomputed by the server.
- Runtime copy now consistently calls purposeful pickups records/evidence: the puzzle fallback title, monster wake cue, Backrooms objective, and victory summary no longer expose the old generic fragment wording. Internal `Fragment1/3` IDs remain stable for session compatibility.
- Room 1's radio now names the two active paper records instead of the old three-fragment count, and both records use in-world maintenance/route evidence copy.
- The server-authoritative note whitelist now carries the authored recovered text for every active production record. Online clients receive the same text as offline scene notes instead of a generic `Evidence recovered.` message.
- Main-state smoke compares every active scene record with its server definition across Room 1, Room 2, Backrooms, House Survey, and the final room; network smoke confirms the server-delivered Room 1 and House messages reach the HUD.
- The lower objective and HUD rows now use responsive bottom anchors, word wrapping, a bounded long-message tail, and a tested non-overlap gap at the base `1152x648` viewport. A deterministic local frame confirmed the two rows remain readable and inside the screen with the longest House survey message.
- Main-state sequence smoke now restores `current_level_scene` after inspecting the route, so later assertions and server-event labels reflect the physically loaded Room 1 rather than stale Corridor metadata.
- The fourth inhabitant, `The Unlit`, advances outside flashlight coverage and freezes only inside an unobstructed `SpotLight3D` cone.
- Builder symbol `U` generates The Unlit in editor layouts, including its short production maintenance-wing encounter, with smoke coverage for the scene contract.
- A reusable pressure-powered work spotlight can also hold The Unlit. It reuses the existing pressure-plate contract, responds to both local signals and silent server-synced state, and provides a future one-player-holds-power/two-player-crosses co-op encounter without adding another switch system.
- A non-production Endless House evidence chamber now connects one authored Match Dots maintenance record, a one-player non-latching plate, the pressure-powered work light, one generated `U`, and an exit in the intended record-to-power-to-crossing order.
- The chamber smoke verifies the generated counts, reachable route order, exact light-rule wording, generated plate resolution, server-style silent plate updates, illuminated hold, and release. The complete local gameplay/UI/monster/network/two-session suite passed afterward; no deploy or GitHub push followed.
- Pressure-powered work lights now support timed breaker outages while their plate remains held. The remaining outage can be captured and restored as a small state dictionary for future server snapshots, late join, and Restart.
- Chamber smoke verifies that an outage releases The Unlit, clearing it restores held power, applying the saved outage suppresses power again, and the lamp automatically resumes after the restored timer. The existing flashlight/work-light behavior smoke also remains green.
- The journal defines a hidden optional `The Unlit` section without adding it to the required three creatures or nine victory facts. It renders only after an Unlit discovery and persists through the normal snapshot format.
- The chamber maintenance record maps to optional Unlit fact 1, while the first unobstructed beam hold maps to fact 2 through the existing monster `observed` signal and generic `Main` discovery path. Journal and chamber smoke protect hidden-until-found rendering, snapshot restoration, metadata, and unchanged victory progress.
- A reusable one-shot breaker passage trigger now starts the timed work-light outage after the creature crossing. It has a minimal wall indicator plus separate spent-state snapshot, while the lamp retains its own remaining-outage snapshot.
- `Main` now accepts generic `evidence_observed` signals from environmental devices. The breaker uses that path for optional Unlit fact 3, and restoration remains silent so late state application cannot duplicate the discovery.
- Chamber and Main-state smoke protect record-to-power-to-creature-to-outage-to-exit order, one-shot emission, independent trigger/light restoration, automatic lamp recovery, optional fact 3 routing, and unchanged required victory progress.
- Physical local debug `F8` opens the production Unlit chamber directly through the normal `Main` player/UI path for fast desktop iteration. The shortcut remains disabled for Web, release, dedicated, and multiplayer use; ordinary play reaches the same scene through the production route.
- Main-state smoke rejects layout-dependent `F8`, verifies the physical-key preview, spawn yaw, mechanic-specific objective, generated gameplay counts, and breaker presence. The preview also exposed and fixed a missing root `Notes` container required by the common level loader.
- The local smoke gate now fails on any Godot line beginning with `ERROR:` instead of only selected error phrases, preventing zero-exit-code load errors from being reported as passing.
- A deterministic 1152x648 capture exposed that the Unlit chamber was too dark to teach its mechanic. Cold ambient fill and sparse warm ceiling fixtures now reveal the route while the focused work light remains the only environmental light that freezes the creature.
- The same visual pass moved the crossing camera to a realistic inspection distance and fixed the breaker panel's thin mesh axis, making its red spent indicator legible on the wall.
- Visual inspection also caught a missing floor/ceiling cell under the manual breaker: a temporary `T` layout character was not a builder walkable symbol. The layout now uses a real floor cell, and route smoke derives the outage step from the trigger node's actual grid position.
- Verified frames in `build/unlit_evidence_capture_verified/` show the flashlight-readable record, cyan held silhouette, red released silhouette, and intact breaker corridor. Targeted chamber smoke passed after the visual fixes.
- First-observation HUD feedback now reinforces The Unlit's rule without a modal: illumination says to keep the beam on it, and breaker evidence says to use the player's own beam. Main-state smoke verifies both messages and their corresponding optional facts.
- WorkLight and BreakerTrigger now expose a shared dictionary `get_sync_state`/`apply_sync_state` contract. `Main` gathers and restores environmental mechanics by stable paths relative to the loaded level.
- Online session state now transports `level_mechanic_states` through initial join, Restart respawn, full reset, and level transition. The full dedicated network and two-session isolation suite passed with the new RPC signature.
- Client-originated mechanic mutation is deliberately not accepted yet: The Unlit chamber is not in `SESSION_LEVEL_PATHS`, so there is no production level/mechanic whitelist against which the server could safely validate such a request.
- Chamber smoke now uses two real `CharacterBody3D` player probes instead of directly toggling its gameplay interactions. It verifies the record's `body_entered` puzzle request, non-latching plate hold/release, automatic passage-trigger outage, and one-shot evidence signal.
- The physical test highlighted that a holder could occlude a work light mounted at chest height directly above the plate. The chamber lamp is now ceiling-mounted at `2.65 m`; a player body can hold the plate while its unobstructed beam still freezes The Unlit.
- The physical `F8` preview is now solo-completable without weakening the co-op scene: after the tester solves its single record, a debug-only assist holds the floor plate and the normal exit gate opens.
- Entering the preview exit returns to a playable Room 1, restores the production record count from before preview entry, and keeps optional Unlit journal observations for inspection. Main-state smoke covers assist activation, work-light power, exit opening, return spawn, and counter restoration.
- The full local gameplay/UI/monster/dedicated-network/two-session suite passed after the solo preview flow; no deploy or GitHub push followed.
- `docs/asset_needs.md` now maps each current placeholder to its exact scene and visual children, with target dimensions, pivots, forward axis, and material requirements. Gameplay roots, collisions, triggers, and scripts remain stable replacement boundaries.
- Free environment candidates were rechecked against their official pages. The list now prioritizes Quaternius House Interior for residential dressing and Kenney Factory Kit for the Backrooms service wing, while unverified Sketchfab creature links are explicitly marked for manual review.
- The outdated question about whether House Survey remains debug-only was removed; it is already production. User follow-up now asks for an `F8` Unlit readability playtest and a decision on fixed versus variable outage timing.
- Deterministic visual frames now distinguish The Unlit's cold frozen band from its red moving band from any approach direction; the four-sided marker remains a placeholder for a proper creature material/model.
- Its implementation follows Godot 4.6's documented `-Z` spotlight direction, angular radius/range, and physics ray-query pattern. A dedicated smoke protects cone direction, wall occlusion, illumination hold, movement, first observation, and independent state across two instances.
- The Unlit remains outside the required journal count and victory condition, but now participates in the production sequence and server session definitions. Its three optional evidence sources, trigger, outage, movement, death contact, Restart, and late-join state are integrated and smoke-covered.
- Optional House Records stay hidden until the first related discovery, keeping the early journal focused on its three creature entries.
- The tuned House survey now follows Backrooms in both offline and server-authoritative production sequences instead of remaining an `F9`-only preview. Backrooms remains a distinct swallowed service wing rather than being replaced.
- House Survey stays short: one Match Dots record documents that copied rooms lose air movement and room tone before shape, while the separate False Door dead end can verify the creature's missing-draft fact through proximity observation.
- A third optional House Record captures that physical-copy rule. Session path lookup, titles, spawn positions/yaw, note authority, late state sync, and transition to Corridor now include the House level.
- Main-state and dedicated network smoke protect `Backrooms -> House Survey -> Corridor`, the one-record task limit, server synchronization of House fact 3, and unchanged bestiary victory progress.
- Backrooms regular and late chasers now have separate editor-tunable speeds. Their early sprint speeds were reduced from roughly `5.5`/`7.8` to `3.84`/`4.29`, while journal scaling preserves a smaller late-game escalation.
- Builder smoke protects both the lower playtest speed ceiling and the readable speed difference between the two simultaneous Backrooms chaser roles. Main-state smoke additionally verifies their effective journal-scaled speeds remain below the player's `5.1` sprint speed at the actual Backrooms point in the route.
- Generated puzzle records can now receive editor-assigned `EvidenceProfile` resources with distinct recovered text and journal facts/rumors instead of sharing one generic fragment string.
- The two active Backrooms records now document fixed survey marks and descending maintenance indices through different Match Dots and Code Lock tasks. Inactive placeholders remain disabled for short playtests.
- The journal now has an optional `House Records` section for hidden environmental lore. These records persist and synchronize online but do not change the `3 creatures / 9 verified facts` victory requirement.
- Main-state, journal, builder, and dedicated-server smoke cover the two House records, their stable generated IDs, snapshot/Restart persistence, and server whitelist mappings.
- Network smoke clients now have an emergency frame limit, preventing a future script parse failure from leaving an idle headless process. The full local gameplay, UI, monster, Restart, two-session isolation, and server-authority gate passed after the change; no deploy or GitHub push followed.
- Journal rumor rows now identify the prior radio log, Room 2 survey, or Elias as their source, so players can compare testimony instead of seeing anonymous claims.
- Mara's journal belonged to her missing brother Tomas, whose trust in the bright-light rumor motivates her insistence on verified observations.
- Elias is now a former maintenance surveyor whose partner disappeared through a blinking doorway. His conclusion is wrong, but his advice to watch a full light cycle from several steps away is valid counterplay for the advanced False Door.
- Journal and main-state smoke protect both histories, the source labels, and Elias's actionable method. Deterministic UI frames at 1152x648 confirmed source wrapping, disputed styling, scrolling, and button separation.
- Watcher entry progress now controls two stateful variants: a short warning hold after gaze breaks, then one obstacle-checked step toward the last observer after the hold expires.
- Watcher behavior smoke protects immediate baseline calming, learned attention memory, one-step-only movement, and the minimum three-second kill buffer.
- The Watcher line-of-sight test no longer calls nonexistent `Camera3D.get_rid`; only the player's physical body is excluded from the ray query.
- False Door entry progress now changes its visual strategy: tier 1 alternates a warm exit disguise with the known violet pulse, while tier 2 suppresses the pulse at long range and restores it before the lethal trigger.
- False Door smoke protects color alternation, safe reveal distance, pulse contrast, controlled-player filtering, and one-shot trap behavior. Deterministic House frames visually confirmed the warm disguise, violet reveal, and separate real-door appearance.
- Watcher and False Door smoke scenes now have emergency frame limits so a future parse failure reports cleanly instead of leaving an idle Godot process.
- The shared collectible scene now supports glow-orb, paper-note, survey-panel, and voice-recorder visuals while retaining one collection, puzzle, reset, and multiplayer contract.
- Hand-authored Listener warnings use paper, Room 2 distinguishes its floor-plan survey from its False Door voice recording, and builder-generated evidence defaults to a diagonally readable survey panel.
- Room 2's first active gate is now a purposeful reconstruction of fixed survey points and records the unverified theory that False Doors grow where a floor plan repeats.
- Pattern-lock copy now describes reconstructing evidence rather than collecting an abstract fragment.
- New evidence-visual smoke verifies one visible variant at a time and keeps disabled placeholders invisible and non-interactive. Project, journal, main-state, puzzle UI, and builder variant checks passed.
- Deterministic Room 2 capture exposed and fixed edge-on and floating props; the final survey panel and recorder have distinct cyan/amber and red silhouettes from diagonal approaches.
- The dedicated server's Room 2 note whitelist now awards the survey theory for `Fragment1` instead of silently discarding the scene-authored rumor online.
- The network smoke now requires the authoritative server to synchronize both the survey rumor and the separate voice-recorder fact before leaving Room 2. The full local gameplay, dedicated-server, reset, and two-session isolation gate passed with the expected `replicated_room` server event; no deploy or GitHub push followed.
- The reusable builder now rotates generated real and False Doors toward their more open corridor axis, avoiding edge-on door silhouettes in side approaches.
- The House survey route now requires an early record, offers a later one-axis False Door dead end, and puts the real exit beyond the longer return route; its smoke verifies reachability and presentation order.
- A deterministic local visual-capture scene checks the House from the spawn, False Door approach, and real-exit approach using the player's flashlight settings. Fresh frames confirmed readable warm route lighting, a distinct violet false exit, and a clearly different real door.
- The tuned House builder smoke and fresh local Web export passed. The public server and GitHub were not touched.
- Listener behavior progression now uses the exact Listener journal completion ratio, with independent per-monster state for noisy-target fixation, last-noise search, and movement interception.
- A dedicated Listener behavior smoke verifies baseline target release, learned noise memory, advanced interception, and isolation between two simultaneous monster instances.
- Backrooms now contains Elias, a second survivor who does not grant the journal and records an unverified `double_pulse_safe` False Door rumor that verified fact 3 later disputes.
- Journal and main-state smoke coverage now protects Elias's dialogue contract, his conflicting rumor, snapshot persistence, and the later disputed state. Targeted project, journal, Listener, main-state, and Backrooms startup checks passed locally; no deploy or GitHub push followed.
- Production `v0.3.0` was deployed to `https://creepy-pasta.duckdns.org` on 2026-07-22 after the full local gameplay, UI, multiplayer, Linux-server export, and Web export gate passed.
- The deployed `.pck` SHA-256 matched the fresh local export, the public WSS endpoint returned `101 Switching Protocols`, and a public browser client created `Session 001` without console warnings; the dedicated service and Caddy remained active.
- Windows smoke/export helpers now launch Godot through `Start-Process -Wait`, capture stdout/stderr, and reject parse/load errors reliably instead of reporting success while the GUI executable still runs asynchronously.
- The main-state smoke now gives its generated wall list an explicit type and uses a 600-frame emergency timeout, so the raised Backrooms wall assertion both parses and finishes without orphaning headless Godot processes.
- Online entry now opens an active-session browser. Players can join an existing session or create a clean isolated session instead of inheriting one global server state.
- Dedicated-server session state isolates level path, collected records, journal discoveries, pressure switches, exit state, players, reset, respawn, and transitions.
- Local network smoke now runs two simultaneous clients in separate sessions and verifies that collecting/resetting one session cannot change the other.
- Signal and code locks now both use a visible `0-5` keypad and identify their puzzle type with distinct titles.
- Backrooms walls and ceiling are one meter taller, keeping the maze above the player's eye line.
- Watcher gaze now gives a visible three-second look-away countdown before it can kill the local player.
- Online `Restart` respawns into the current shared state without disconnecting; offline restart rebuilds Room 1 and restores a player.
- Code locks now use a visible `0-5` keypad; a clue such as `3 4 1` resolves directly to `230` without hidden wraparound.
- Production rooms currently expose no more than two required records for faster playtesting. Extra authored/generated records stay as inactive placeholders and can be re-enabled later.
- Keyboard actions now use physical key bindings in `project.godot`.
- Local smoke now verifies gameplay input actions use physical key bindings, so non-English keyboard layouts stay protected from regression.
- HUD control text no longer depends on English letter labels for movement keys.
- Dialogue interaction hint no longer names the `Q` letter, keeping non-English keyboard layouts from seeing misleading control text.
- HUD/dialogue hints now avoid hardcoded `Ctrl`, `Shift`, and `Esc` labels and describe actions instead.
- `DayNightCycle` is attached to `Main` and rebinds to each loaded level.
- Local desktop testing can adjust day/night cycle length with physical `F6`/`F7` keys.
- Local smoke now verifies day/night cycle length clamping, lighting application, and level rebinding.
- The level sequence now includes the Backrooms builder demo before the corridor.
- Fragment puzzles now support matching dots, sequence locks, and code locks.
- Fragment puzzles now also support a short polarity-switch puzzle where six linked circuits must all be turned on.
- Level 2 now includes a latch-once floor pressure plate that must be activated after collecting fragments to stabilize the exit.
- Pressure plates now depress and brighten when active.
- Pressure plates refresh their occupied-body state after peer disconnects, preventing stale non-latching switches.
- Exits now close again when required non-latching pressure plates are released, so hold-switch co-op gates behave as actual hold gates.
- Exit close events now have a distinct status/audio cue so hold-switch gates read clearly when they destabilize.
- Corridor contains two monster instances, and monster targeting/collision setup is prepared for multiple monsters.
- Fourth room has an open final exit and a victory screen.
- Victory screen now includes a short session summary with recovered fragment count.
- Build version is exposed through `GameVersion`, shown in menu/HUD, and printed by the dedicated server on startup.
- Menu now has reconnect and fullscreen actions; Web builds keep the simplified `Play Online` flow.
- Death and victory screens now have explicit `Retry` and `Menu` actions.
- End-state retry buttons are labeled as `Restart` to make the session reset behavior clear.
- Default death copy now avoids prototype-style monster labels and uses in-world wording.
- `deploy/local_smoke.ps1` now includes a UI end-state smoke scene for death/victory panels and their retry/menu signals.
- Web play now shows a pointer-lock hint until the player clicks to control the camera.
- Web menu now recommends desktop browsers without exposing server setup controls.
- Join/reconnect/offline buttons are disabled during active connection attempts and restored on timeout/failure/disconnect.
- `deploy/local_smoke.ps1` now includes a UI menu smoke scene for menu signals, connecting disabled state, and menu show/hide behavior.
- Late join now receives a server session snapshot with the current level scene path and collected note IDs.
- Late-join session snapshots now also include session collected-note count, pressure plate states, and note-gated monster activation states.
- Late-join pressure plate sync now preserves non-latching hold-switch behavior instead of accidentally latching active `H`/`G` plates on clients.
- Note collection now goes through a server-approved request/broadcast flow instead of client-side collection broadcast.
- `Main` state-discovery smoke now verifies missing and duplicate note collection requests do not change counters.
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
- Backrooms objective text now reflects its generated notes, pressure switch, and escalating chaser threat instead of only saying to find the exit.
- Starting and entering levels now shows a short level banner so scene changes read as progress.
- `AudioCues` now provides lightweight procedural sounds for note pickup, exit opening, and victory.
- Backrooms builder `N` cells now create notes, and `Main` discovers notes recursively so builder-generated notes count and sync.
- Backrooms builder generated content is now grouped into `Geometry`, `Markers`, `Mechanics`, `Notes`, and `Monsters` under `GeneratedBackrooms`.
- Fourth room now includes a watcher monster that punishes prolonged direct staring, adding a non-chase threat variant.
- Fourth-room objective and warning note now teach the watcher rule before the player commits to the final exit.
- Fourth room now has a final intercom dialogue near the exit for a short reveal before victory.
- Watcher gaze checks require line of sight, so walls and obstacles can break the stare.
- Watcher line-of-sight checks now ignore the viewer's own body collision.
- Local controlled players now have lightweight procedural footstep sounds with different walk/sprint cadence.
- `AudioCues` now plays a quiet procedural ambience bed that changes per loaded level.
- Code-lock puzzles are available for notes and Backrooms-generated notes.
- Code-lock puzzles now show a short numeric clue instead of directly exposing the answer.
- Backrooms-generated notes now default to polarity-switch puzzles, adding another puzzle shape without expanding the UI panel.
- Backrooms builder `W` cells now create reusable watcher monsters, and `Main` discovers monster signals recursively.
- Backrooms builder `C` cells now create reusable chaser monsters with sprint-hearing behavior.
- Backrooms builder `C` chasers start dormant and activate after note progress by default.
- Backrooms builder `A` cells now create a faster late-activating ambush chaser with longer sprint hearing.
- Chaser monsters now support optional idle patrol radius; the reusable Backrooms chaser patrols when it has no target.
- Backrooms builder `B` cells now create low barriers/cover for navigation and watcher line-of-sight breaks.
- Backrooms builder `P` cells now create reusable pressure plates.
- Backrooms builder note cells now support forced puzzle types with `D`, `Q`, `K`, and `O`, and the demo level uses all four puzzle modes.
- Backrooms builder `H` and `G` cells now create non-latching hold-switch pressure plates for one-player and two-player co-op gates.
- `AudioCues` and player footsteps now skip playback in headless/dedicated runs and release procedural audio streams/players cleanly during local smoke exits.
- Web deploy Caddy config now serves `index.html` uncached and forces revalidation of fixed-name Godot runtime files, preventing stale `.pck`/`.wasm` builds after deployment.
- Oracle deploy scripts now keep one previous-version rollback point, and `deploy/rollback_oracle.ps1` can rollback server, web, or both.
- `deploy/local_smoke.ps1` now runs the standard local smoke suite, with optional `-Exports` for Linux dedicated and Web exports.
- `deploy/local_smoke.ps1` now fails on Godot script/load error output even when Godot exits with code `0`.
- `deploy/local_smoke.ps1` now includes a UI puzzle-mode smoke scene that solves Match Dots, Sequence Lock, Code Lock, and Polarity Switch through the real puzzle buttons.
- `deploy/local_smoke.ps1` now includes a `Main` state-discovery smoke scene for notes, monsters, pressure plates, spawns, exits, and sync-state helper calls across hand-authored and Backrooms-builder levels.
- `Main` state-discovery smoke now verifies the intended level sequence: first room, copied room, Backrooms, corridor, fourth room.
- `Main` state-discovery smoke now verifies the fourth room keeps its final dialogue hook.
- `Main` state-discovery smoke now verifies final-room dialogue hooks contain actual dialogue pages, not only empty nodes.
- `Main` state-discovery smoke now verifies that releasing required pressure-plate state closes an already opened exit.
- `deploy/local_smoke.ps1` now includes a Backrooms builder variants smoke scene for forced puzzle-note symbols and pressure-plate variants.
- Backrooms builder variants smoke now verifies synced non-latching pressure plates do not become latched.
- `deploy/local_smoke.ps1` now includes a physical input bindings smoke scene for movement, sprint, interact, and dialogue controls.
- Fragment puzzles now explicitly disable player controls while open, then re-enable controls, release deferred GUI focus, and restore mouse capture after completion or cancellation.
- Plain world fragments no longer touch player controls or mouse capture when their server-approved collection arrives, avoiding browser input freezes after yellow pickups.
- Gameplay clicks and physical key events now self-heal a stale player-controls flag whenever no blocking UI is open; fragment collection also rechecks controls and Web pointer guidance without forcing pointer lock outside a user gesture.
- The start menu now includes `Reset Online`; it can connect and request a server-authoritative shared-session reset back to Room 1, clearing progress and respawning all connected players.
- Local network smoke covers collecting `Note1`, resetting the shared session, restoring Room 1 with zero notes, and keeping the connection alive.
- The primary Windows test machine had UAC disabled (`EnableLUA=0`), leaving Explorer High while Firefox content remained sandboxed; UAC defaults were restored and will take effect after reboot, resolving UIPI drag/drop mismatches without weakening Firefox sandboxing.
- A minimal shared field journal now tracks the Listener and Watcher with three facts each, a physical-key action, and a compact on-screen button after the journal is granted.
- Mara now appears in the second room, explains the Listener, grants the journal, and provides its first verified fact.
- The first room now starts a delayed Listener chase, giving the opening an immediate threat before Mara's explanation.
- Listener activation, corridor survival, the Watcher warning record, direct Watcher observation, and the final intercom all contribute journal progress through server-approved updates.
- Journal state is included in late-join snapshots and cleared by the shared online reset.
- Creature speed, hearing, and Watcher stare tolerance scale conservatively with journal completion, implementing the first knowledge-driven difficulty progression.
- Final victory now requires the server to confirm an unlocked, complete journal; the final objective explains missing knowledge instead of allowing an early exit.
- `local_smoke.ps1` now launches an actual temporary dedicated server and client to test note collection, journal synchronization, reset, disconnect cleanup, and server survival.
- The network harness exposed and fixed a disconnect race where a removed player could run one last state-sync callback after losing its multiplayer API.
- Local Web visual checks confirmed the compact reset menu, Room 1 objective, pointer guidance, and non-overlapping bottom HUD at 1280x720; no server deploy or GitHub push followed this local concept block.
- `DayNightCycle` now removes freed dynamic lights before casting or updating them; collecting a glowing fragment no longer crashes WebAssembly or the dedicated server through its freed `OmniLight3D`.
- Cached lights unregister on `tree_exiting`, and dedicated servers skip visual day/night binding entirely, keeping render-only state out of authoritative headless sessions.
- `deploy/local_smoke.ps1` now includes a day/night cycle smoke scene for cycle length clamping, lighting changes, and level rebinding.
- `deploy/local_smoke.ps1` now includes a UI control-text smoke scene to keep layout-dependent key labels out of runtime hints.
- Full Oracle deploy now runs the local smoke/export gate before uploading, and server deploy fails if fresh Godot logs contain script/load parse errors or native crash signals.
- Latest checks ran the full local smoke suite plus Linux dedicated/Web exports, then deployed the freed-light crash fix to Oracle. A public `Play Online` test collected `Note1` and moved away afterward; the dedicated service stayed on the same PID with `NRestarts=0` and no crash signals. Local/remote `.pck` SHA-256 matched, and revalidation headers remain active; no GitHub push.
- Journal progress now stores exact 1-based fact indices per creature, so later clues cannot silently unlock skipped evidence or satisfy the final victory gate.
- Journal snapshots now synchronize independent facts and rumors, while retaining a migration path for older cumulative-count snapshots.
- The first-room radio records an unverified bright-light rumor; surviving the Listener provides contradictory evidence and changes that rumor to `DISPUTED` after the journal is unlocked.
- Watcher warning, direct gaze observation, and final intercom now each grant one exact fact instead of cumulative progress.
- Room 1 now has explicit co-op spawn markers, route-facing player yaw, forward-spaced evidence, route lighting, pursuit-breaking furniture, and a narrow threshold before the transition to Mara.
- Spawn orientation is synchronized for new, moved, and late-joined players; the opening and long corridor face players toward their intended routes.
- Main-state smoke now guards opening spawn direction, evidence ordering, threshold geometry, independent final-journal requirements, and the rumor source.
- The full local suite passed after these changes, including the temporary dedicated server/client scenario for exact fact + rumor sync, reset, and disconnect cleanup. A fresh local Web export also completed; no server deploy or GitHub push followed this block.
- The journal now includes a third three-fact entry, `The False Door`, bringing the current victory requirement to 9 independent verified facts across 3 creatures.
- A reusable `mimic_door_basic.tscn` provides a static disguised-exit threat with a subtle red seam, two close purple light pulses, safe observation range, and lethal entry trigger.
- False Door knowledge is split across a found voice record in Room 2, an explicit hanging-thread inspection in the final room, and a final record explaining its double-pulse tell.
- The final room now runs the Watcher and False Door simultaneously without sharing movement, targeting, or activation state.
- The dedicated False Door smoke verifies its observation signal, double-pulse contrast, multiplayer body filtering, and one-shot trap behavior.
- Room 2 was reduced from seven repeated fragment pickups to three evidence records using Match Dots, Sequence Lock, and Polarity Switch, followed by the existing pressure-plate stabilization step.
- Main-state smoke now verifies all three False Door clue sources, exact observation interaction, two simultaneous final-room threats, and the 3-creature victory gate.
- The full local suite and temporary dedicated server/client scenario passed after the third creature and Room 2 evidence changes; no deploy or GitHub push was performed.
- `BackroomsBuilder` now exposes floor, wall, ceiling, light, and low-barrier scenes as inspector-editable `PackedScene` slots while retaining the Backrooms scenes as defaults.
- Builder symbol `M` now creates a reusable False Door, and the existing variant smoke protects that generation path alongside chasers, Watchers, notes, and pressure switches.
- A native Endless House kit now provides 4 m floor/ceiling modules, 3.2 m trimmed walls, a warm flickering ceiling fixture, and low sideboard cover under `scenes/endless_house/kit/`.
- `endless_house_builder_demo.tscn` assembles a generated residential hall with a spawn, evidence record, cover, two lights, real exit, and False Door using the shared builder.
- The new House builder smoke verifies visual-kit resource overrides, generated geometry, gameplay markers, False Door behavior contract, and rebuild idempotence.
- Physical local debug `F9` opens the generated House survey without changing the production level sequence; it is disabled for release, dedicated, and multiplayer sessions.
- Local Web debug screenshots confirmed readable cold wall/floor separation, warm route lighting, a visible distant doorway, coherent HUD, and no game-script console errors. Automated pointer lock remained unavailable inside the test browser only.
- The preview test exposed unguarded `multiplayer.is_server()` calls after `Play Offline` clears the peer; server checks now short-circuit through `_is_network_server()` and offline monster/journal events run without engine errors.
- Full local smoke passed after the builder and offline guard work, including Backrooms regressions and the temporary dedicated WebSocket server/client scenario; no deploy or GitHub push was performed.
- A deterministic House Survey render exposed that the shared builder replaced every kit root position with the grid coordinate. Authored floor, wall, ceiling, light, and cover heights were therefore lost in every generated visual kit, including the low Backrooms walls reported during playtesting.
- `BackroomsBuilder` now adds the cell translation to each instantiated kit root, preserving the Backrooms 4.2 m walls/ceiling and the House 3.2 m walls/ceiling as well as floor, barrier, sideboard, and fixture offsets.
- Both builder smokes now assert exact floor, wall, ceiling, and cover root heights. Fresh House and Backrooms captures under `build/house_survey_capture_offsets_fixed/` and `build/backrooms_capture_offsets_fixed/` visually confirm full-height corridors, mounted lights, readable threats, and distinct opened exits.
- The complete local gameplay, UI, builder, monster, dedicated-network, Restart, and two-session suite passed after the transform fix; no deploy or GitHub push followed.
- Real exits now reveal a small animated floor-draft cue only while open. False Doors never receive it, turning the House Survey's missing-draft record into a directly checkable environmental rule instead of text-only lore.
- The House record explicitly identifies moving floor dust and absent room tone as physical-copy tests. House smoke protects cue visibility, motion, closed-state cleanup, and the False Door's missing cue; a tuned deterministic frame lives under `build/house_survey_capture_draft_cue_tuned/`.
- The shared `LevelExit` script treats the draft child as an optional capability, preserving older hand-authored exits while reusable builder exits expose the cue. The complete local gameplay, UI, builder, monster, dedicated-network, House transition, Restart, and two-session suite passed after this compatibility fix; no deploy or GitHub push followed.
- The Unlit breaker now has a staged server-authoritative request path. Online clients defer local mutation; the server accepts only the exact generated source while the session's bounded player position is at the panel, marks it spent, grants optional fact 3, and broadcasts the approved mechanic snapshot.
- The server stores an absolute outage deadline instead of a client countdown. Restart snapshots derive the remaining outage, late joins after expiry receive zero, and both retain the one-shot spent breaker. The staged exit requires its single record plus that spent state rather than a permanently held plate.
- The physical F8 preview now keeps the exit closed after solving the record, advances the objective to the breaker crossing, and opens only after the actual breaker fires. Its solo plate assist remains limited to local debug.
- Main-state smoke aligns the staged record, plate, creature observation, breaker, work-light, and exit definitions with generated paths; it covers out-of-range rejection, accepted proximity, duplicate rejection, journal evidence, deadline math, Restart restore, and late-join expiry. Dedicated smoke proves Room 1 cannot replay the staged breaker path.
- The complete local gameplay, UI, builder, monster, dedicated-network, Restart, and two-session suite passed after the Unlit authority staging; no deploy or GitHub push followed.
- The Unlit now has per-session server-owned position, target selection, grid navigation, player/work-light illumination, wall occlusion, and 10 Hz client snapshots. Authoritative clients stop local AI and apply the approved state silently, while the first server-approved illumination grants direct-observation fact 2.
- Main-state smoke covers authored 2.2 m/s movement, clear flashlight hold, wall occlusion, work-light hold, active outage, deadline recovery, Restart/late-join restoration, and cross-session target isolation. The existing dedicated create/Restart/full-route smoke and two-session isolation smoke pass with the expanded session snapshot.
- The Unlit contact/death decision is now server-owned. A per-session latch sends one reliable death RPC on contact, ignores sustained duplicates, and clears after separation or Restart; authoritative clients ignore their local kill `Area3D`.
- The Unlit chamber now follows House Survey and precedes Corridor in both offline and `SESSION_LEVEL_PATHS` routes. It remains a short one-record plus one-breaker task, and its three facts remain optional for the current victory count.
- Dedicated smoke enters the room alive, verifies authoritative creature state, receives a real `session_monster_contact`, Restarts in the same room with the threat reset, rejects the breaker from range, accepts it at the panel, restores the spent trigger/outage state, and reaches Corridor.
- The extended route also exposed a smoke-only failure mode where a Backrooms chaser killed a client while long RPC assertions left it standing still. Network traversal now recovers and stops local chasers only after their separate behavior and Restart checks; `Main` also rejects a queued death signal whose source no longer belongs to the current level.
- The complete local parse, physical-input, gameplay, UI, journal, builder, monster, dedicated full-route, Restart, and two-session isolation gate passed after production integration in 192 seconds. No export, deployment, or GitHub push was performed.
- Production-facing copy no longer labels The Unlit as a prototype: the room banner is `The Unlit: Maintenance Wing`, the hidden optional journal entry is `The Unlit`, and targeted journal/Main smoke rejects a returning prototype label.
- The shared survey-panel evidence visual now has a lighter metal finish, subtle emission, and a slightly wider local cyan pool, keeping The Unlit's first record readable against its dark floor without turning it into a generic quest marker. Fresh deterministic frames under `build/unlit_evidence_capture_readability/` and targeted evidence/chamber smokes passed.
- Procedural room ambience now loops continuously instead of ending after its first 24-second buffer. Loop-period modulation keeps the generated seam quiet, while House Survey and The Unlit have distinct restrained profiles; synchronized work-light outage/recovery changes add short non-modal power cues. A dedicated ambience smoke protects profiles, sample length, loop boundaries, and seam continuity.
- Online session reassignment now deletes the previous room once its last member moves, preventing invisible empty rooms from consuming the server's session limit. Empty and completed rooms are omitted from the join browser, rejoining the same room preserves it, and `Retry` after online victory resets the shared run to Room 1 while death `Restart` still respawns in the current room. Main-state and UI end-state smoke cover these lifecycle distinctions.
- The complete local parse, physical-input, gameplay, ambience, UI, builder, monster, dedicated full-route, Restart, and two-session isolation gate passed after the ambience and session-lifecycle block in 194 seconds. No export, deployment, or GitHub push was performed.
- Live reassignment now updates an existing Player node's session identity, spawn transform, sync baseline, and visibility on every client instead of leaving it attached to its old room. The server rejects stale direct joins to completed rooms, and the expanded two-client smoke proves `S002 -> S003` reassignment while the independent owner session retains its progress.
- Open real exits now emit a quiet looping positional room tone alongside their animated floor draft. False Doors copy neither cue, making the House Survey's air-and-sound evidence physically testable; headless stream checks and a rendered audio-driver smoke cover loop boundaries plus `open()`/`close()` playback.
- Online gameplay now shows one restrained top-left status line with the active session ID and synchronized player count. It stays hidden offline and behind the connection menu, follows live reassignment/removal, and passed UI/Main smoke plus a `1152x648` frame under `build/hud_session_capture/`.
- A deterministic first-room capture now covers the route view and the post-record Listener reveal. It exposed that chasers kept their authored rotation while moving: the opening Listener faced the wall and patrol/search/chase motion could slide sideways. Listener instances now face their horizontal movement in every mode, the opening instance initially faces the co-op spawn center, and behavior/Main smoke protect both rules.
- The first Listener activation now leaves a concise visible HUD warning after the recovered-record text instead of writing only to the hidden menu status. The entry radio also establishes that the copied front room leads into a house with no reliable outside, strengthening the opening without another modal or cutscene. Verified reveal frames live under `build/opening_capture_listener_activated/`.
- Rapid server session-list updates now remove old UI rows from the container immediately and keep the authoritative session ID as row metadata instead of deriving it from collision-prone Node names. A back-to-back list smoke protects stale-row replacement, and rejected direct joins now leave a diagnostic server event.
- Client session selection and loaded world state now use separate IDs. Switching from an in-progress room to a clean session on the same `level_path` rebuilds the scene, restoring evidence nodes removed in the previous room; Main-state smoke and a live owner/guest flow prove join-with-progress, `2 players`, two clean reassignments, fresh Note1 collection, isolated reset, and retained owner progress.
- The complete local parse, physical-input, gameplay, ambience, UI, builder, monster, dedicated full-route, death/Restart, rapid session reassignment, and two-session isolation gate passed after the opening and loaded-session fixes in 177 seconds. The run was captured in `build/final_local_smoke_2026-08-01.log`; no export, deployment, or GitHub push was performed.

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
