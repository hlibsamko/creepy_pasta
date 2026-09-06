# Production asset inventory

This ledger answers one practical question: where is each downloaded visual actually visible in the game?

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
| Quaternius monster | chaser visual child | Ordinary chaser production route | production-temporary | Replace or improve in a dedicated monster batch. |
| Poly Haven interior tiles | material imports | Selected interior surfaces | production-partial | Map exact scene/material consumers during level cleanup. |

Do not mark a future download complete until its wrapper and exact production scene/kit placement are listed here.
