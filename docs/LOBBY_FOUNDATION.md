# Workshop Lobby Foundation

## Scope

This milestone adds a deterministic graybox workshop and a server-authoritative transition into the existing arena. It is a same-place prototype: lobby players and arena players share one Roblox server and one DataModel. The purpose is to validate a clear join-to-deploy flow without introducing matchmaking, persistence, commerce, or a production lobby.

The implemented flow is:

> Join server -> spawn in safe workshop -> explore -> use MAIN ARENA -> begin a fresh arena run

Arena death retains the existing behavior: the run resets and the player respawns in the arena as a Scrap Runner. A death-choice screen and normal player-facing return to the lobby are deferred.

## Authoritative session states

`PlayerSessionService` owns one of two states for each connected player:

- `Lobby`: safe, weaponless, and outside the per-life arena run.
- `Arena`: participating in the authoritative combat and progression loop.

`PlayerSessionState` is replicated as a player attribute only so client UI and cosmetics can respond. Server systems never use a client-written attribute as authority. Combat, breakable damage, XP, upgrades, class selection, movement exceptions, and deployment query `PlayerSessionService` directly.

The service initializes every connection in `Lobby`, preserves the authoritative state across character respawns, and removes its state when the player disconnects. Rejoining creates a new `Lobby` session. No DataStore is read or written.

## Lobby safety

While in `Lobby`:

- The player remains `ScrapRunner` at the canonical Level 1 run state.
- All standard, Striker, Spinner, and Rammer weapons and class visuals are removed.
- Hammer, Spinner, and Rammer readiness attributes are disabled.
- Combat, breakable damage, XP awards, upgrades, and evolution requests are rejected by their server owners.
- A hidden ForceField and server health restoration protect against ordinary damage paths.
- Smooth robot movement, grounding, camera orbit, bounded zoom, and non-colliding player chassis behavior remain active.
- Arena progression, upgrade, evolution, health/combat, and class-instruction UI is hidden.
- A small safe-zone objective points toward MAIN ARENA.
- The existing F2 developer menu remains available only under its Studio authorization rules.

Client-side input guards avoid unnecessary lobby traffic and predicted weapon visuals, but they are convenience only. The server gates remain the security boundary.

## Deterministic workshop layout

`LobbyLayoutService` creates `Workspace.WorkshopLobby` from version-controlled Luau primitives at runtime. The approximate footprint is 120 x 90 studs centered at `(0, 0, 700)`, outside the 380 x 380 arena and away from AssetLab. It contains a solid floor, four boundary walls, a marked arrival platform, an open social route, and these graybox zones:

- `MAIN ARENA`: active cyan portal with a `Deploy` proximity prompt.
- `DUELS — COMING SOON`: inactive placeholder.
- `TEAM BATTLE — COMING SOON`: inactive placeholder.
- `RANKED — COMING SOON`: inactive placeholder.
- `ROBOT CUSTOMIZATION — COMING SOON`: display platform and workshop frame only.
- `ARENA LEADERS — COMING SOON`: blank local board only.
- Two reserved wall panels for future first-party announcements or separately approved advertising work.

Inactive portals only display a brief Coming Soon message. They cannot teleport, queue matchmaking, award anything, or change session state. The customization and leaderboard areas contain no shop, inventory, purchase prompt, Robux flow, statistics service, or persistence.

## Main Arena deployment

The Main Arena prompt and `LobbyDeployRequest` share one server validation path. A deployment is accepted only when:

- The request belongs to the actual player and has the exact empty payload.
- The player has a living character in authoritative `Lobby` state.
- No deployment is already in progress.
- Cooldown and request-rate limits pass.
- The server-observed HumanoidRootPart is within the configured distance of the actual portal field.

The client never supplies a destination. On acceptance, the server:

1. Changes the authoritative state to `Arena`.
2. Resets the canonical run to Level 1, 0 XP, one unspent point, zero upgrade ranks, and `ScrapRunner`.
3. Selects among the existing cardinal arena spawns, preferring the best clearance from living arena players and rotating choices deterministically.
4. Moves the grounded character through an anti-cheat-recognized authorized teleport.
5. Removes lobby protection and restores normal health rules.
6. Equips exactly one standard Scrap Runner hammer through the existing loadout services.
7. Enables arena HUD, input, combat, progression, and class systems through replicated session presentation state.

Repeated, malformed, distant, stale, or spammed deployment requests are rejected and cannot change the destination or session. Simultaneous deployments are serialized by the server state and spawn selection.

## Character lifecycle

Character creation consults the existing authoritative session rather than assuming every spawn is an arena run:

- Lobby respawn: move to a lobby arrival slot, restore protection, strip all loadouts, and keep arena UI disabled.
- Arena respawn: choose an arena spawn, perform the existing per-life reset, restore one standard hammer, and keep arena UI enabled.

Session transitions increment a server teleport serial consumed by movement validation. This prevents the normal anti-teleport monitor from undoing an authorized cross-map move while leaving ordinary arena and lobby movement limits intact. The camera client detects the large displacement and resets its smoothing origin so deployment does not drag the view across the map.

The Studio-only developer action `ReturnToLobby` uses the same cleanup, run reset, protection, teleport, HUD, and loadout path. It is testing infrastructure, not a public return button.

## Deferred work

This foundation does not implement:

- Functional skins, customization inventory, shops, or purchases.
- Live or global leaderboards.
- Duels, team battles, ranked matchmaking, or fake queues.
- A player-facing Return to Lobby action.
- A death-choice screen, Robux revive, or paid power.
- External announcements or advertising content.
- DataStores, permanent progression, analytics, or multi-place teleports.
- Level 20 evolutions.

If the same-place prototype proves clear and enjoyable with real players, a future architecture decision may move the workshop and arena into separate places. That migration must preserve server authority, canonical run reset semantics, safe spawn selection, failure recovery, and non-pay-to-win rules.

## Validation gate

Before this milestone is committed, a real two-client Studio test must confirm the workshop layout is readable and enjoyable, both players deploy independently without overlap, lobby and arena players coexist safely, arena death stays in the arena, rejoining starts in the lobby, all relevant HUD and loadouts switch exactly once, and server plus both client consoles remain free of errors and warnings.
