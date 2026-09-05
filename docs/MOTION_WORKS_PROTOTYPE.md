# Motion Works Level 20 Prototype

**Status:** Internal Studio prototype; unavailable to ordinary players

**Latest gate:** Directional authorization testing and measured results are recorded in [Motion Works directional validation](MOTION_WORKS_DIRECTIONAL_VALIDATION.md). Roblox Assistant updated during testing and required a Studio restart. The final coastdown adjustment and full regression remain unverified; no multiplayer approval or commit is authorized by the partial results below.

**Scope:** The second of three Level 20 family prototypes. Motion Works proves a server-owned energy drive, movement-aware contact damage, complete Level 8 kit replacement, and bounded movement authorization. It does not enable public Level 20 selection or implement Field Rig or any Level 35 node.

## Player-facing identity

Motion Works replaces the selected Level 8 weapon with a low powered front carriage. Two traction rollers, exposed drive rails, swept guards, and a restrained lime identification light make the silhouette distinct from Impact Foundry, Striker, Spinner, and Rammer. The accepted robot footprint, team panels, grounded clearance, and single gameplay collider remain unchanged.

The prototype uses one desktop attack:

> Hold LMB to spool and drive. Release LMB to coast down.

RMB remains camera orbit. Mobile and controller attack controls remain deferred with the rest of the current combat-control limitation.

## Authoritative state machine

The server owns five phases:

1. `Idle` — energy recharges and a new start may be accepted once enough energy is available.
2. `Spooling` — a server-timed vulnerable startup; releasing early causes no damage.
3. `Driven` — energy drains, forward output ramps, steering falls as output rises, and bounded frontal pulses may resolve.
4. `Coastdown` — damaging pulses stop immediately and the carriage visibly loses output.
5. `Recovery` — energy recharges, but a new attack remains unavailable until the rank-derived recovery ends.

The client sends only `Start`, low-frequency `KeepAlive`, `Stop`, or `Cancel` intent with a monotonically increasing sequence. It never sends time, energy, output, direction, position, speed, target, hit, damage, or pulse timing. A tolerant server lease ends spool or drive safely when keepalives stop. Death, respawn, route reset, extraction, lobby return, weapon loss, and disconnect clear the active state.

Energy is bounded from 0 to 100. A start requires at least 20 energy. Driven mode drains 28 energy per second, so a full uninterrupted drive lasts about 3.57 seconds before forced coastdown. Energy recharges at 24 per second only outside Driven. These values are provisional and deliberately prevent indefinite attack pressure.

## Movement and anti-abuse model

The client predicts smooth movement while the server grants short-lived phase-specific limits:

- Spooling allows 0.72 of the legal upgraded movement speed and 0.68 steering response.
- Driven output ramps over 1.10 seconds from the spool-speed envelope to at most 1.32 of the normal upgraded speed.
- Speed Rank 0 reaches at most 34.32 studs per second; Rank 30 reaches at most 41.18 studs per second.
- Steering falls from 0.85 to 0.40 as output rises.
- Coastdown is limited to 0.82 of normal upgraded speed before ordinary movement returns.

The server movement monitor recognizes Motion Works only while the authoritative route, character, weapon, phase, and run remain valid. It checks directional speed, ordinary upgraded acceleration, sample displacement, forward direction, turn rate, and vertical position/velocity. Reverse and sideways motion receive no forward-drive bonus. Physical velocity violations cancel immediately; directional displacement uses consecutive samples to tolerate delayed replication, and distance checks use bounded server elapsed time. A 5-stud forward obstacle probe exceeds the chassis's 3.6-stud half-length. See the latest validation report for the unverified final coastdown repair and required restart.

The vertical check assumes the current flat graybox floor and one-stud spawn platforms: the root must remain 0.2–3 studs above the floor surface, with at most 40 studs/second of vertical velocity while authorized. Future ramps or uneven terrain require an explicit revision; this is not a general terrain controller.

## Damage model

Damage uses the actual server-observed chassis and weapon transform. Each pulse performs one narrow frontal box query, checks range and line of sight, deduplicates targets, and affects at most two targets. A target must remain in the legal weapon lane.

Motion alone is mandatory. The server requires at least 8 studs per second of observed forward chassis movement and a forward-aligned velocity. Player target motion cannot inflate closing speed beyond the attacker's own forward speed. Stationary contact, reverse motion, side motion, walls, out-of-range targets, and lost line of sight deal no damage.

Rank-derived pulse damage is multiplied by a server-owned strength based on both output ramp and clamped observed speed. Damage Rank 0 ranges up to 9 per pulse; Rank 30 ranges up to 13. Attack Rate changes pulse interval from 0.34 to 0.26 seconds. Player knockback is a fixed low 5. Active breakables receive a provisional 1.50 multiplier, while contribution XP still uses effective damage capped by remaining health, so overkill creates no XP.

## Upgrade endpoints

All upgrade interpolation uses the shared normalized exponential helper:

| Upgrade | Rank 0 | Rank 30 | Effect |
|---|---:|---:|---|
| Attack Rate | 0.62 s spool; 0.34 s pulse; 1.20 s recovery | 0.46 s spool; 0.26 s pulse; 0.92 s recovery | Faster startup, pulses, and recovery |
| Damage | 9 maximum pulse damage | 13 maximum pulse damage | Server-clamped per-pulse output |
| Speed | 34.32 maximum Driven speed | 41.18 maximum Driven speed | Normal and authorized Driven movement scale together |

Health and Health Regen remain the existing shared run upgrades. No Motion Works value changes Level 8 tuning.

## Visual and lifecycle contract

The equipped model contains one invisible weapon root plus twelve original primitive visual parts: a powered carriage, two rails, two swept guards, exposed belt, energy indicator, drive glow, two motor-driven traction rollers, and two accent plates. Every visual part is unanchored, massless, non-colliding, non-touching, and non-queryable. The rollers and carriage animate cosmetically from predicted or replicated state and never provide physics damage or shove.

Selecting Motion Works removes the standard, Striker, Spinner, Rammer, and Impact Foundry weapons and controllers for that life. A server-approved route transition is the only activation path. The previous Level 8 class remains ancestry data, but its combat kit does not stack. Death or a new run restores Scrap Runner with exactly one standard hammer. Impact Foundry cannot switch sideways into Motion Works during the same life.

## Testing boundary

The Studio-only developer action may activate Motion Works only for a living Arena player with a valid Level 8 class and Level 20 run eligibility. The outside-Studio developer switch remains disabled. Ordinary route requests remain rejected because `Level20PublicEnabled` is false and Motion Works is not publicly selectable.

Required final evidence includes fresh-session Script Sync health, server/client console cleanliness, rank endpoints, lease and malformed-request rejection, stationary/range/wall rejection, breakable contribution, movement correction, all lifecycle cancellations, Level 8 and Impact Foundry regression, 150 ms latency, desktop and phone HUD layout, and a genuine two-client human gate. Until that gate passes, this prototype remains uncommitted and must not be described as multiplayer-approved.

## Recorded Studio validation — 2026-09-04

This is **partial single-client validation, not a completed automated or human gate**. The connected place was `savefile.rbxl`. All three canonical Script Sync roots reported `SyncedAsRoot`, and the four new Motion Works scripts were present. Tests used the mock profile adapter. Nothing was published or committed.

### Observed results

| Check | Observed evidence |
|---|---|
| Rank 0 phases | Real LMB input produced approximately 0.634 s spool, 3.599 s Driven time from full energy, then coastdown and recovery. Energy reached zero and did not permit indefinite attack. |
| Rank 30 Attack Rate | Server phase/pulse observations: approximately 0.484 s spool, 0.25–0.27 s pulse spacing, and 0.916 s recovery. Configured endpoints are 0.46 / 0.26 / 0.92 s; observations include server frame scheduling. |
| Early release | No new pulses. Repeated with real mouse input after the final client cleanup change. |
| Normal release and lease | Release stopped new pulses. Withheld keepalives caused coastdown. |
| Request rejection | NaN, infinity, negative/stale sequence, extra argument, idle keepalive, duplicate start, premature keepalive, and spam were rejected in the exercised cases. This is not an exhaustive protocol fuzz test. |
| Route authorization | Early/public Motion Works requests were rejected. A public Level 20 request left Striker intact, and a hammer request was accepted. A stale route serial was exercised. Motion Works could not switch sideways to Impact Foundry. |
| All Level 8 parents | Separate fresh Striker, Spinner, and Rammer lives entered Motion Works through the existing Studio-authorized developer action. |
| Loadout and visuals | Exactly one `EquippedMotionWorks`, with 13 BaseParts; all were unanchored, massless, non-colliding, non-touching, and non-querying. Previous weapon readiness flags were false. |
| Moving contact | A corrected natural approach dealt two observed damage events to a resettable humanoid fixture. Earlier mispositioned/misaligned trials were discarded, not counted as passes. |
| Target cap/dedup | A synthetic moving-contact fixture kept three small humanoid targets in legal frontal contact while the actual character moved normally. Four observed pulses each affected two distinct targets, never three or the same target twice. This verifies query behavior, not PvP feel. |
| Stationary rejection | With the test character temporarily anchored at zero speed and a frontal target in range, four pulses left the target at 100 health. The test anchor was removed immediately afterward. |
| Geometry probes | Synthetic side, rear, distant, and ray-obstructed fixtures recorded no damage. These do not replace real-wall collision, lift, or multiplayer counterplay tests. |
| Breakable damage/overkill | A registered 150-health PowerCore was temporarily kept in legal contact. At Damage/Attack Rate rank 30, damage ramped to 19.5 per breakable pulse; the last 8.798 remaining health was capped correctly. Run XP increased from 1,115 to 1,190: exactly 75. Its original placement was restored. This is an endpoint fixture, not a normal build or farming benchmark. |
| Teleport correction | A forged 100-stud client displacement was corrected. The initial test exposed missing immediate drive cancellation for shared-monitor corrections; the integration was fixed. A fresh-session retest incremented the Motion Works violation counter and entered recovery, ending within approximately 1.74 studs of the pre-test position. |
| Death in every phase | Idle, Spooling, Driven, Coastdown, and Recovery deaths each returned the attack state to Idle with no additional pulses after the sampled death. Respawn restored Level 1 Scrap Runner and one standard hammer. |
| Weapon loss/lobby forgery | Removing the runtime weapon cancelled Driven. Restart without a valid weapon failed. Forged client route/session/energy attributes did not authorize a lobby attack; server state remained Lobby/Scrap Runner. |
| Extraction/redeployment | At 150 ms simulated incoming replication lag, 1,115 run XP banked exactly once in the mock profile. Lobby return removed the weapon and route. Redeployment restored Level 1, zero unbanked XP, and one standard hammer. |
| Latency input | Held input remained Driven and release entered Coastdown/Recovery at 150 ms. The final real-input trial had one safely rejected request; the release still stopped the attack. No gameplay warning/error accompanied it. |
| Repeated respawns | Fresh-session retests produced one hammer after reset and one Motion Works assembly after evolution. Client animation-cache entries now clear on each character removal instead of retaining old characters. |
| HUD screenshots | Average Laptop (1366×768), iPhone 17 Pro landscape, and portrait were inspected. Phase/energy text was readable and separated from health and run/banked XP. The expanded upgrade menu occupies substantial portrait combat space. Captures did not establish expanded CoreGui player-list behavior. |
| Existing tuning | CombatConfig, SpinnerConfig, RammerConfig, ImpactFoundryConfig, MovementConfig, ProgressionConfig, the existing Spinner/Rammer/Impact Foundry services, and developer authorization configuration had no diff from the accepted Impact Foundry baseline. This is source evidence, not full runtime regression proof. |

### Repairs during validation

- The shared movement monitor now cancels an active Motion Works drive whenever it corrects movement under that authorization, including displacement and acceleration corrections, rather than only Motion Works-specific direction/speed violations.
- The client removes old characters from its roller-angle and visual caches on `CharacterRemoving`. No tuning values changed in these repairs.

### Remaining validation before approval

- Genuine two-client damage, replication, survivor preservation, and proportional contribution XP.
- Broader corner/wall and sustained acceleration/turn abuse stress cases; repeat the lower-speed reverse probe with measured server velocity (see retry evidence below).
- Exhaustive timing/replay cases and disconnect during every active phase; actual operating-system focus-loss input behavior.
- Full fresh runtime regression of all five existing combat kits, all upgrades/regeneration, rarity population, camera/collision behavior, and evolution-ready menu states. Unchanged source alone is not a pass.
- Expanded Roblox player-list/CoreGui bounds in a genuine two-client desktop session and subjective portrait usability.
- Dedicated mobile/controller attack input remains explicitly deferred.

### Fresh visible-viewport retry — 2026-09-04

The retry used a fresh playtest after Studio was maximized; the client viewport was 895×433 rather than the earlier unusable viewport. These results extend the partial evidence above, not multiplayer approval.

| Check | Measured result |
|---|---|
| Wall-lift baseline | Standard Scrap Runner pushing the north wall at x=70: root Y 1.968–2.023; closest Z −186.456. |
| Motion Works wall failure and repair | Before repair, root Y reached 5.205. The 3.2-stud probe was shorter than the chassis half-length. With the Motion Works-only probe increased to 5 studs, Y stayed 1.984–2.037 and closest Z was −186.476, with zero Motion Works movement violations. This straight-wall comparison does not cover every corner. |
| Vertical spoof | A +15-stud client displacement initially left Driven active. After adding vertical validation to start, pulse, and movement authorization, the same probe returned Y from 2.001 to 1.993 within the sampled 0.8 seconds, incremented the violation count once, and entered Recovery. |
| Legitimate turning | A normal hold initially triggered a false correction: observed speed 32.902 was below 34.32, and turn 15.153 degrees was below the 28.8-degree allowance, but sideways momentum exceeded a separate tighter lateral cap. That conflicting cap was removed; the forward cone, speed, acceleration, displacement, and turn checks remain. The client angular-velocity cap now follows the same Driven steering envelope as the server and restores its ordinary cap afterward. |
| Normal hold after repair | Rank 0 completed ten pulses and energy-exhaustion recovery with zero additional movement violations. |
| Speed Rank 30 at 150 ms | Clear-lane hold peaked at 38.284 studs/second, root Y at 2.011, and zero additional movement violations. The configured ceiling is 41.184; this curved observed run did not establish that the ceiling was reached. Latency was then restored to zero. |
| Movement abuse | Forward, sideways, and reverse 120-stud/second spoof probes each caused a correction/cancellation. After the lateral-cap repair, a 40-stud/second sideways probe at Speed Rank 30 also incremented the counter and entered Recovery. Lower-speed reverse probes did not increment it; the final bounded probe displaced only 4.625 studs over 1.3 seconds, so requested client velocity is not evidence that the server actually observed 40 studs/second. These reverse probes are inconclusive, not passes. |
| Existing-kit input smoke | On separate lives at Level 20 readiness: Striker accepted one hammer attack; Spinner entered SpinUp; Rammer entered Charging. Impact Foundry accepted one attack and recorded one strike. This does not re-prove exact damage, balance, or every regression case. |
| Upgrade/configuration checks | All 31 ranks produced positive finite, monotonic spool, pulse, recovery, damage, and movement values. Ordinary Level 20 access remained disabled. |

Only Motion Works-specific wall clearance and validation were adjusted; accepted Level 8 damage/cooldown tuning was not changed. Temporary diagnostic prints and runtime probes are not production features. Genuine two-client replication/contribution/feel, operating-system focus loss, and the outstanding regression/UI cases remain unverified in this retry.

### Eventual two-client human gate

Run this only after the remaining automated checks above are resolved or explicitly accepted as manual checks:

1. Start a real two-client Studio server, deploy both players, and keep the player list expanded. Confirm health, XP, extraction, upgrades, and evolution controls remain readable.
2. On client A, use F2 to reach Level 8, select a Level 8 class, and use **Activate Motion Works**. Client B must see one original lime-accent drive carriage and no previous weapon. Repeat ancestry checks on fresh lives for the other two Level 8 classes.
3. Hold LMB: observe spool, increasing forward output, reduced steering, energy drain, exhaustion, coastdown, and recovery on both clients. Try early release, normal release, and alt-tab/focus loss. RMB orbit must remain available.
4. Fight client B with controlled frontal passes. Compare moving contact with being stationary/blocked; test side/rear passes, spacing, cover, and walls. Observe narrow pressure and bounded shove, not unavoidable stationary damage.
5. Share a PowerCore, record each player's effective damage and XP, and confirm the total reward is exactly 75 with no overkill reward. Try nearby multiple targets without treating the synthetic fixture as balance evidence.
6. Die during spool and drive, then redeploy; confirm Scrap Runner and one hammer return while the survivor keeps their run. Separately extract successfully and confirm weaponless lobby cleanup and fresh redeployment.
7. Repeat a short interaction at 150 ms, restore latency to zero, inspect server and both client consoles, and stop Studio. Record fairness, wall lift, visible desynchronization, and any warnings/errors.

### Repository and Studio end state

Studio was stopped in Edit mode with incoming replication lag restored to zero, the device simulator returned to its default viewport, healthy sync roots, and no gameplay warnings/errors in the final session. Temporary runtime fixtures were absent from Edit mode. `git diff --check` passed; all milestone work remained unstaged and uncommitted. `art/` was untouched. The accidental, untracked `src/server/ServerScriptService/` directory created during the earlier incorrect mapping was preserved rather than deleted; it is not the active Server sync root.
