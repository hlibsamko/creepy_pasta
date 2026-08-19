# Questions And Local Follow-Up

This file collects decisions that can wait for the user. **During the current visual-upgrade mission, none of the items below is a blocker unless explicitly marked `BLOCKING`.** Development should continue around them using safe reversible choices.

## Blocking Decisions

- None currently recorded.

## Visual Direction — Non-Blocking

- Pick a visual direction for the house kit: realistic worn residential, low-poly stylized, or PSX/retro. Current geometry remains deliberately neutral.
- Until the user decides, do not stop visual work. Respect each existing branch identity, prefer reversible wrapper/material replacements, and avoid a project-wide irreversible art-style conversion.

## Design Decisions — Non-Blocking

- Should the bestiary be shared by the co-op session, or should every player maintain personal observations that must be compared? The current implementation uses one shared server-authoritative journal. **Do not change this during visual-upgrade work.**
- Should incorrect rumors remain visibly crossed out after correction, or disappear once disproven? Keep current behavior until the user decides.
- Should a completed journal end the run immediately, or only make the final door usable? The current implementation uses the final door. **Do not change this during visual-upgrade work.**
- Playtest The Unlit in its normal production position after House Survey (physical `F8` remains a fast desktop shortcut). Check whether the record-to-work-light-to-breaker rule is readable for one and two players without extra UI. Visual readability work may help without changing the mechanic.
- Should The Unlit's current fixed breaker outage become variable between runs after the production pacing playtest, or remain predictable as a learnable rule? Keep the current behavior until that playtest/decision.

## Asset Review — Current Visual Mission

- Review the candidates and requirements in `docs/asset_needs.md`.
- Prioritize the live status/order in `docs/asset_needs.md`; current high-value slots include the modular house interior, Mara/survivor, Listener final visual quality, The Unlit silhouette/material solution, and Watcher.
- Use the replacement-slot table to reject assets with unusable pivots, forward axes, inseparable required emissive parts, unsuitable rigs, unclear licenses, or poor Web practicality before spending time integrating them.
- Do not ask the user to choose between near-equivalent reversible free assets unless the choice changes global art direction, requires payment, has unclear licensing, or is difficult to reverse.
- If the official itch download remains rate-limited, a non-blocking handoff option is to place `Universal Base Characters[Standard].zip` (122 MB) in `D:\Downloads` or the project `assets\third_party` folder. No payment, account data, or Source archive is required; work can then continue with the selected Regular female Mara candidate.

## Machine Follow-Up — Not a Game Task

Do **not** work on these during the visual-upgrade mission unless the user explicitly asks:

- Reboot Windows once convenient. UAC was restored from disabled to the standard configuration, and the integrity-level fix only becomes active after reboot.
- After reboot, verify dragging a Firefox download to Desktop and into the usual target applications. Explorer and normal file handlers should run at Medium integrity rather than High.
- Retest camera capture and movement in Firefox Developer Edition after the reboot. The browser profile showed no custom Pointer Lock, WebGL, acceleration, or restrictive tracking preference that explains the machine-specific input behavior.
- Firefox Developer Edition is version 150.0 and `browser.launcherProcess.enabled` is at its default `true`; uBlock was present but there was no evidence that it caused the control issue.
