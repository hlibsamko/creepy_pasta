# Questions And Local Follow-Up

This file collects decisions that can wait for the user. Development should continue around them instead of blocking.

## Machine Follow-Up

- Reboot Windows once convenient. UAC was restored from disabled to the standard configuration, and the integrity-level fix only becomes active after reboot.
- After reboot, verify dragging a Firefox download to Desktop and into the usual target applications. Explorer and normal file handlers should run at Medium integrity rather than High.
- Retest camera capture and movement in Firefox Developer Edition after the reboot. The browser profile showed no custom Pointer Lock, WebGL, acceleration, or restrictive tracking preference that explains the machine-specific input behavior.
- Firefox Developer Edition is version 150.0 and `browser.launcherProcess.enabled` is at its default `true`; uBlock was present but there was no evidence that it caused the control issue.

## Design Decisions

- Should the bestiary be shared by the co-op session, or should every player maintain personal observations that must be compared? The current implementation uses one shared server-authoritative journal.
- Should incorrect rumors remain visibly crossed out after correction, or disappear once disproven?
- Should a completed journal end the run immediately, or only make the final door usable? The current implementation uses the final door.
- Pick a visual direction for the house kit: realistic worn residential, low-poly stylized, or PSX/retro. Current geometry remains deliberately neutral.
- Playtest The Unlit in its normal production position after House Survey (physical `F8` remains a fast desktop shortcut). Check whether the record-to-work-light-to-breaker rule is readable for one and two players without extra UI.
- Should The Unlit's current fixed breaker outage become variable between runs after the production pacing playtest, or remain predictable as a learnable rule?

## Asset Review

- Review the candidates and requirements in `docs/asset_needs.md`.
- Prioritize choosing the Listener silhouette, Mara/survivor model, modular house interior kit, and The Unlit silhouette.
- Use the replacement-slot table to reject assets with unusable pivots, forward axes, or inseparable emissive parts before spending time integrating them.
