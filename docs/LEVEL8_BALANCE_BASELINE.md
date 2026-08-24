# Level 8 Three-Class Balance Baseline

Status: **farming normalization automated and human gates complete**

Code baseline: commit `42e125e`

Measurement date: 2026-08-24

Balance changes made: **breakable-only Spinner and Rammer farming values; accepted PvP values unchanged**

This document began as a measurement-first snapshot of Striker, Spinner, and Rammer. Limited human observations judged the three sampled matchups fair, after which breakable-only farming values were added without changing accepted PvP damage, cooldown, knockback, movement, range, charge, spin, or class health. Values are labeled so configuration-derived expectations are not confused with server-observed combat results or human judgments.

## Evidence labels

- **Observed**: produced by an accepted server-authoritative action in a Studio playtest.
- **Route-observed**: produced by the same deterministic live-breakable route and legal client movement for all three classes.
- **Configured**: read from the shared configuration used by the server.
- **Modeled**: calculated from observed/configured values where a repeatable direct measurement was not obtained. Modeled values are not a substitute for playtest results.
- **Invalidated**: a run with a confirmed fixture or driver defect. Invalidated values are retained only as diagnostic history and are excluded from balance comparisons.
- **Pending human**: requires real players, matchup judgment, or genuine two-client observation.

## Test builds

All ordinary builds begin at Level 8 with exactly eight earned points. Class selection did not spend XP or points.

| Build | Speed | Attack Rate | Damage | Health | Health Regen |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline | 0 | 0 | 0 | 0 | 0 |
| Balanced | 2 | 2 | 2 | 1 | 1 |
| Striker focused | 0 | 3 | 4 | 1 | 0 |
| Spinner focused | 0 | 4 | 3 | 1 | 0 |
| Rammer focused | 3 | 2 | 3 | 0 | 0 |

Rank 30 checks exercised endpoints only. An all-Rank-30 state is impossible in a normal Level 8 run and must not be used as the expected balance case.

### Shared upgrade endpoints

| State | Horizontal speed | Max health | Health regen |
| --- | ---: | ---: | ---: |
| Rank 0 | 26.000 studs/s | 100.000 | 0.000/s |
| Balanced (Speed 2, Health 1, Regen 1) | 26.157 studs/s | 100.736 | 0.044/s |
| Rank 30 endpoint | 31.200 studs/s | 150.000 | 3.000/s |

The early exponential ranks are intentionally subtle. Rank 1 contributes an upgrade factor of `0.014726`, Rank 2 `0.030207`, Rank 3 `0.046482`, Rank 4 `0.063591`, and Rank 30 `1.0`.

## Striker baseline

### Server values by build

| Build | Damage per accepted hit | Server cooldown | Knockback speed | Evidence |
| --- | ---: | ---: | ---: | --- |
| Baseline | 30.000 | 0.980 s | 22.000 | Observed damage; configured/authority cooldown and shove |
| Balanced | 30.302 | 0.972 s | 22.000 | Observed damage; configured/authority cooldown and shove |
| Focused | 30.636 | 0.967 s | 22.000 | Observed damage; configured/authority cooldown and shove |
| Rank 30 endpoint | 40.000 | 0.710 s | 22.000 | Observed endpoint damage; configured/authority cooldown and shove |

At baseline, a retry at `0.94 s` was rejected and the later eligible request was accepted. A miss consumed the same cooldown as a hit.

### Range, displacement, and stationary targets

- Effective measured root-to-root range against the controlled chassis-sized target was up to `10.5 studs`; `10.6 studs` and farther missed. This depends on target size and the actual weapon transform.
- A baseline hit applied the authoritative `22` horizontal knockback speed. An unanchored dummy moved `1.40 studs` in the first sample and `4.10 studs` after `0.7 s`. Dummy physics are not a player-versus-player displacement result.
- The following stationary-target times are actual server-accepted baseline attacks. The timer begins with the first attack request and ends with lethal damage.

| Target health | Hits required | Actual time to eliminate |
| ---: | ---: | ---: |
| 100 | 4 | 3.449 s |
| 110 | 4 | 3.449 s |
| 125 | 5 | 4.449 s |
| 150 | 5 | 4.449 s |

The Balanced and focused builds retain the same hit counts at these health values. Their cooldown improvements are small at early ranks.

### Breakables

The identical Balanced-route run destroyed 28 live server-owned objects in `70.257 s` of recorded combat time, or `2.509 s per object` across the mixed route. All `68` attack attempts were accepted, none were rejected, and no measured hit missed.

## Spinner baseline

### Server values by build

| Build | Spin-up | Pulse interval | Pulse damage | Steady pulse DPS | Knockback/pulse | Evidence |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Baseline | 0.400 s | 0.320 s | 7.000 | 21.875 | 2.500 | Observed timing/damage, configured shove |
| Balanced | 0.396 s | 0.318 s | 7.091 | 22.327 | 2.500 | Observed damage, configured/authority timing |
| Focused | 0.392 s | 0.315 s | 7.139 | 22.671 | 2.500 | Observed damage, configured/authority timing |
| Rank 30 endpoint | 0.280 s | 0.240 s | 10.000 | 41.667 | 2.500 | Observed endpoint damage, configured/authority timing |

A `10.67 s` baseline hold stayed active without interruption. It produced `33` pulses and `231` damage. The whole-window observed DPS was `21.66`; after spin-up it was `22.54`. Sampled pulse gaps clustered around `0.316-0.334 s`. Releasing stopped additional pulses.

At the Balanced build, Spinner's stationary single-target sustained damage is `7.091 / 0.318 = 22.3 DPS`, excluding spin-up. Balanced Striker is `30.302 / 0.972 = 31.2 DPS`. Spinner therefore trails Striker by approximately `28.5%` in this stationary single-target comparison. This arithmetic is a measured throughput comparison, not a PvP outcome or tuning recommendation.

### Area, contact, and stationary targets

- The server query radius is `4.8 studs`, with a maximum target range of `5.8 studs` from the actual weapon origin, a vertical limit of `4 studs`, and a maximum of six deduplicated targets per pulse.
- Against the controlled chassis-sized target, damage was observed through `9.5 studs` of root-to-root separation and not at `10.0 studs`. Root range is larger than weapon-origin range because both models have physical extent.
- Breaking contact for roughly one second at baseline forfeits about three available pulse opportunities (`21` damage before reacquisition effects). Exact loss in a fight depends on when contact breaks relative to a pulse.
- Spinner shove is server-bounded at `2.5` per pulse. The primitive dummy produced unreliable accumulated physics displacement, so player-versus-player low-shove feel remains a human item.

The following are actual Balanced-build stationary-target results.

| Target health | Hits required | Actual contact time to damage threshold |
| ---: | ---: | ---: |
| 100 | 15 | 4.899 s |
| 110 | 16 | 5.217 s |
| 125 | 18 | 5.850 s |
| 150 | 22 | 7.132 s |

### Breakables

Before farming-only tuning, the identical Balanced-route run destroyed 28 live server-owned objects in `125.123 s` of recorded combat time, or `4.469 s per object` across the mixed route. All `28` spin cycles began successfully. Across start, keepalive, and stop traffic, `258` requests were accepted and none rejected.

The final server-owned `1.50` breakable multiplier changes Balanced breakable pulse damage from `7.091` to `10.6365` while leaving player pulse damage at exactly `7.091`. Effective single-breakable throughput is therefore approximately `33.45 DPS` after spin-up, provided contact remains legal. The breakable service clamps each pulse to remaining health and records only applied damage, so overkill does not increase contribution credit or XP.

Two fresh post-tuning route trials completed in `150.195 s` and `150.428 s`, yielding `319.585` and `319.090 XP/minute`. Median completion was `150.311 s`, median combat `99.790 s`, and median travel `46.030 s`. Both trials destroyed the exact route quota, accepted all 28 attack cycles, rejected no requests, and recorded no misses or unaffected pulses.

### Controlled clustered pressure

The ordinary deterministic route above is the single-target benchmark shared with Striker and Rammer. It deliberately approaches the same isolated target sequence and therefore does not measure Spinner's area-pressure ceiling.

The separate cluster benchmark temporarily repositioned full-health PowerCores into an isolated clear area. Each fixture target remained anchored, non-colliding, inside the real `5.8-stud` server range, inside the configured weapon area, and in line of sight. The fixture used narrow `1.2-stud` query columns and non-query visual parts so the temporary targets did not invalidate one another through artificial self-occlusion. This geometry existed only during the playtest; no arena layout was changed on disk.

| Valid targets | Damage per target | Total damage | Active contact time | Active combined DPS | Whole window including spin-up | Targets on first pulse / max | XP earned |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | 150 | 300 | 4.484 s | 66.91 | 4.901 s / 61.21 DPS | 2 / 2 | 150 |
| 4 | 150 | 600 | 4.482 s | 133.86 | 4.900 s / 122.45 DPS | 4 / 4 | 300 |
| 6 | 150 | 900 | 4.498 s | 200.09 | 4.917 s / 183.05 DPS | 6 / 6 | 450 |
| 7 | 150 | 1,050 | 9.250 s | 113.52 | 9.666 s / 108.63 DPS | 6 / 6 | 525 |

The two-, four-, and six-target runs each used `15` server pulses. Every target received exactly `150` authoritative damage, all start/keepalive/stop requests were accepted, no request was rejected, and server XP matched the PowerCore rewards. The seven-target radial fixture placed all seven targets simultaneously inside legal range and line of sight. Exactly six received the first pulse and no pulse affected more than six; the seventh waited for capacity, extending the run to `30` pulses without creating XP.

This confirms Spinner's intended area-pressure strength and target cap. It also establishes a stronger map-layout risk after farming tuning: if normal routing lets six valuable targets remain continuously clustered and legal, approximately `200.1` combined active DPS and `450 XP` in about `4.5 s` could dominate farming. The normal deterministic route does not create that condition, so future maps must control dense high-value clusters rather than weakening Spinner's accepted player combat.

## Rammer baseline

### Server values by build

| Build | Full charge | Full impact damage | Cooldown after release | Full authorized dash speed | Full knockback | Evidence |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Baseline | 1.200 s | 35.000 | 1.350 s | 42.000 studs/s | 26.000 | Observed/configured endpoints |
| Balanced | 1.189 s | 35.302 | 1.338 s | 42.157 studs/s | 26.000 | Route-observed damage and configured/authority timing |
| Focused | 1.189 s | 35.465 | 1.338 s | 42.242 studs/s | 26.000 | Observed damage/knockback, configured/authority timing |
| Rank 30 endpoint | 0.840 s | 45.000 | 0.950 s | 47.200 studs/s | 26.000 | Observed endpoint damage/knockback, configured/authority timing |

Minimum valid hold is `0.20 s`. A measured approximately half-charge impact dealt `29.997` damage and applied `21.747` knockback; a clear-lane baseline full charge dealt exactly `35` and applied `26`. The partial sample is only about 14% below the full sample, so whether partial releases are too efficient is a confirmed measurement concern for human testing.

### Dash, range, and miss cost

- A clear-lane baseline miss reached `40.71 studs/s` against `42 studs/s` authorized speed and covered `10.41 studs` during the measured active window. The configured dash lasts `0.45 s`, has `23.5 studs` maximum displacement, and caps lateral displacement at `5 studs`.
- A clear full impact occurred at `11.67 studs` root separation, `5.79 studs` from the actual weapon origin, and `39.51 studs/s` observed closing speed.
- The frontal query is `5.8 x 3.2 x 4.6 studs`, requires a forward dot of at least `0.30`, line of sight, and at least `18 studs/s` closing speed. It can resolve one target once per charge.
- A miss commits the release cooldown. At baseline, another charge cannot begin until `1.35 s` after release; the visible miss-recovery phase is `0.22 s`. A full hold plus release therefore commits about `2.55 s` before another charge can begin.

### Observed stationary targets

The corrected driver returns to an actual saved lane using normal configured movement, faces and settles on the target before charging, verifies frontal alignment and LOS, and applies the same immediate authorized-dash transition as the validated player controller. It does not teleport, add steering, change charge timing, or bypass server speed and displacement limits.

The fixture used isolated anchored Humanoids with chassis-sized query roots. Timers begin immediately before the first full charge and end on authoritative lethal damage, including real cooldown and legal repositioning between impacts.

| Target health | Accepted full impacts | Observed time to eliminate | Misses |
| ---: | ---: | ---: | ---: |
| 100 | 3 | 11.283 s | 0 |
| 110 | 4 | 16.650 s | 0 |
| 125 | 4 | 13.899 s | 0 |
| 150 | 5 | 18.766 s | 0 |

The 110-health run taking longer than the 125-health run is observed path and physics variance across different isolated fixture locations; both required four impacts. These are single trials per health value, so they should not be read as precise expected PvP kill times.

### Corrected breakable route

The original `379.468 s`, `126`-charge, `50`-miss Rammer route is **invalidated**. The harness attempted to move toward a target while using an `18-stud` stop radius; once already inside that radius it never returned to a usable lane. Its time and miss rate are excluded from every balance comparison.

The repaired harness stores a legal pre-charge lane, returns to that lane after every successful impact, selects a new legal post-dash approach after a miss, confirms frontal alignment before release, and records a bounded diagnostic reason for every miss. It also matches the production controller's immediate transition to the server-authorized dash speed; the earlier gradual harness acceleration could make replicated speed arrive after the weapon passed a target.

Two fresh identical Balanced-route trials completed without driver faults:

| Metric | Trial 1 | Trial 2 | Median | Population variance | Range |
| --- | ---: | ---: | ---: | ---: | ---: |
| Completion time | 300.638 s | 297.539 s | 299.088 s | 2.40 s² | 3.100 s / 1.04% |
| XP/minute | 159.660 | 161.324 | 160.492 | 0.69 | 1.663 / 1.04% |
| Combat time | 222.507 s | 223.171 s | 222.839 s | 0.11 s² | 0.664 s / 0.30% |
| Travel and legal lane reacquisition | 73.664 s | 69.977 s | 71.820 s | 3.40 s² | 3.687 s / 5.13% |
| Accepted charges | 68 | 68 | 68 | 0 | 0 |
| Intended-target misses | 0 | 0 | 0 | 0 | 0 |

Both trials earned exactly `800 XP`, destroyed the complete 28-object quota, rejected zero attack requests, and recorded zero Rammer movement violations. Median combat time was `7.959 s per object` across the mixed route. Because no misses occurred, the corrected miss-reason log is empty; the bounded driver would have classified wrong-target consumption, alignment, LOS, insufficient closing speed, out-of-range travel, early obstacle recovery, or an otherwise unexplained server rejection.

### Farming-only Rammer result

The final server-owned `3.00` breakable multiplier leaves player impact damage unchanged. Shared breakable safety still clamps one hit to `100`, so even a legitimate Rank-30 full impact cannot one-shot a 150-health PowerCore. Destroying a breakable uses `0.35 s` recovery measured from the release that began the dash; non-destroying breakable impacts retain the normal Balanced cooldown of `1.337917 s`.

The post-tuning driver uses only Rammer's existing hold mechanic: it chooses a legal server-timed partial charge from visible remaining breakable health, adds a small timing margin, faces and aligns normally, and sends only Start, KeepAlive, and Release intent. Common piles use a short valid charge, 75-health targets use a stronger partial charge, and 150-health targets still require two impacts. Damage, closing speed, target selection, hit acceptance, and cooldown remain server-owned.

| Metric | Trial 1 | Trial 2 | Median | Population variance | Range |
| --- | ---: | ---: | ---: | ---: | ---: |
| Completion time | 120.995 s | 122.994 s | 121.995 s | 1.00 s² | 2.000 s / 1.64% |
| XP/minute | 396.711 | 390.262 | 393.486 | 10.40 | 6.450 / 1.64% |
| Combat time | 64.227 s | 65.293 s | 64.760 s | 0.28 s² | 1.066 s / 1.65% |
| Travel and legal lane reacquisition | 52.220 s | 53.268 s | 52.744 s | 0.27 s² | 1.047 s / 1.99% |
| Accepted impacts | 34 | 34 | 34 | 0 | 0 |
| Intended-target misses | 0 | 0 | 0 | 0 | 0 |

Both trials destroyed Common `14`, Rare `4`, Epic `2`, crates `4`, and cores `4`; earned exactly `800 XP`; and recorded zero rejected requests or movement violations. A separate 150 ms run also completed all 34 impacts with no misses or rejects and directly sampled `0.350000 s` destroy recovery versus `1.337917 s` after each non-destroying 150-health first impact.

## Identical farming route

### Method

- Fixed start: `(0, 0, 150)` with character ground height preserved.
- The route is deterministic: lexically ordered candidates, fixed type quotas, and nearest-next selection from the fixed start.
- Every class used the Balanced build and the exact same 28 object names in the same order.
- Route composition: 14 Common ScrapPiles, 4 Rare ScrapPiles, 2 Epic ScrapPiles, 4 ReinforcedCrates, and 4 PowerCores.
- Total award: exactly `800 XP`, taking each run from Level 8 through the next three levels to Level 11.
- Travel used the same delta-time movement implementation and legal movement configuration. Attacks used only normal public attack-intent remotes; damage, destruction, and XP remained server-owned.
- A short setup warmup before the fixed start was excluded from elapsed time.

### Automated baseline before farming-only values

| Metric | Striker | Spinner | Rammer |
| --- | ---: | ---: | ---: |
| Total time | 120.260 s | 175.625 s | 299.088 s median |
| XP per minute | 399.137 | 273.310 | 160.492 median |
| Time to Level 9 | 42.563 s | 64.879 s | 100.296 s median |
| Time to Level 10 | 77.811 s | 115.943 s | 185.934 s median |
| Time to Level 11 | 119.627 s | 174.458 s | 298.038 s median |
| Travel/reacquisition time | 45.563 s | 46.129 s | 71.820 s median |
| Combat time | 70.257 s | 125.123 s | 222.839 s median |
| Class attack attempts/cycles | 68 | 28 | 68 median |
| Rejected attack requests | 0 | 0 | 0 |
| Intended-target misses | 0 | 0 | 0 |

All routes destroyed the exact quota: Common `14`, Rare `4`, Epic `2`, crates `4`, and cores `4`.

### Post-tuning results

| Metric | Striker unchanged | Spinner median | Rammer median |
| --- | ---: | ---: | ---: |
| Total time | 120.260 s | 150.311 s | 121.995 s |
| XP per minute | 399.137 | 319.337 | 393.486 |
| Travel/reacquisition time | 45.563 s | 46.030 s | 52.744 s |
| Combat time | 70.257 s | 99.790 s | 64.760 s |
| Attack cycles/impacts | 68 | 28 | 34 |
| Accepted protocol requests | existing baseline | 195 median | 88 |
| Rejected attack/protocol requests | 0 | 0 | 0 |
| Intended-target misses | 0 | 0 | 0 |

All post-tuning routes again destroyed the exact quota and earned exactly `800 XP`. Spinner improved `16.84%` in XP/minute and reduced completion time `14.41%`. Rammer improved `145.18%` in XP/minute and reduced completion time `59.21%`; this large change combines the breakable-only values with efficient use of its already-approved partial-charge mechanic and is therefore documented separately from PvP.

### Farming comparison after tuning

- Striker remains fastest at `399.137 XP/minute`.
- Rammer is `1.42%` below Striker at `393.486 XP/minute`.
- Spinner is `19.99%` below Striker at `319.337 XP/minute`.

All classes are within approximately 20% of the fastest result without identical completion times. Striker remains reliable repeated burst; Spinner must maintain contact and gains area efficiency; Rammer rewards charge choice, facing, and one-target lane execution. No PvP value was changed to reach this result.

## Role evaluation after automated farming checks

| Intended role | Automated evidence | Current assessment |
| --- | --- | --- |
| Striker: reliable burst, strong shove, recovery after every swing | Exact hits, no route misses, 22 shove, unchanged 0.97-0.98 s PvP cooldown | Role remains mechanically present and was reported fair in the limited human observations. |
| Spinner: highest sustained pressure while contact is maintained, low shove, spacing vulnerability | Player DPS remains 22.3; breakable throughput is 33.45; legal cluster pressure reaches 200.1 combined DPS at six targets | PvP identity remains unchanged. Scrap-shredding identity is present; six-target map layouts remain a confirmed future risk. |
| Rammer: strongest committed impact/mobility burst, alignment-dependent, punished for misses | Player damage/cooldown unchanged; one-target breakable route rewards legal partial charges and destroy recovery | PvP identity remains unchanged. High-impact scrap-crusher identity is present without multi-target damage. |

## Concerns to test, not tune yet

### Confirmed automated concerns

1. Spinner combined breakable pressure scales almost linearly through the six-target cap, reaching `200.1` active DPS and `450 XP` in about `4.5 s` under an intentionally dense legal fixture.
2. The seven-target fixture correctly excludes one target per full pulse, but it confirms that layout—not extra server target capacity—is the primary clustered-farming risk.
3. The measured half-charge Rammer PvP hit retained roughly 86% of full-charge damage and 84% of full shove; that accepted PvP behavior was not changed here.
4. Early focused builds move class-specific output only modestly because ranks 1-4 occupy the shallow end of the exponential curve. Focused-build identity may be hard to perceive at Level 8.

### Theoretical or human-dependent concerns

- Striker may shove an opponent far enough to deny retaliation; dummy displacement cannot settle this.
- Normal arena layouts may or may not create six-target contact often enough for Spinner's measured cluster ceiling to matter.
- Spinner may be unable to maintain contact against Striker shove or Rammer burst despite its nominal sustained role.
- Corrected Rammer automation recorded no misses or movement violations, but cover-heavy human fights may still produce legitimate alignment and wall punishment.
- Balanced-build regeneration (`0.044/s` after the damage delay) is too small to suggest a stalemate in the measured window. Rank 30 reaches `3/s`, so long disengagement at endpoint stress still warrants observation.
- No stationary automated result eliminated an equal-progression target in under `2.5 s`. Striker's perfect-hit target times are below the desired typical `5-12 s` fight window, but target tests contain no evasion, counterattack, walls, or recovery decisions.

## Regression and security evidence

The reusable measurement runner now lives only under `tools/balance/` and is not synchronized into StarterPlayerScripts. It cannot run for normal players, creates no remote, and grants no gameplay authority. During measurement it used developer tools only for Reset Run and To Level 8, then used normal server-validated upgrade, class, movement, and attack requests.

Observed regression/security checks:

- Level 1 class request rejected; Level 8 Striker accepted exactly once; duplicate and cross-class requests rejected while class remained Striker.
- Extra-field and malformed class requests, NaN and extra-field upgrade requests, malformed hammer requests, and wrong-class Spinner/Rammer intents incremented server rejection counters without changing authoritative state.
- A locally forged `RunClass = Spinner` appeared only on that client; the server retained `Striker` and rejected Spinner intent.
- A client attempt to jump 60 studs and apply `1000 studs/s` horizontal velocity was corrected to `0.53 studs` residual displacement and effectively zero speed. The movement controller was restored.
- At simulated `150 ms` incoming replication lag, the post-tuning Rammer route completed all 34 legal impacts, exact XP, zero rejects, zero misses, and zero movement violations after the harness matched the production controller's immediate cosmetic/movement prediction. A two-PowerCore Spinner fixture applied exactly 150 damage per target, awarded exactly 150 XP, and accepted all requests. Lag was reset to `0`.
- Player-target branches were unchanged: Scrap Runner and Striker still use the existing hammer damage path, Spinner still applies its unmultiplied `7.091` Balanced pulse to Humanoids, and Rammer still applies its unmultiplied rank/charge/closing-speed damage plus the normal rank-derived player cooldown. Git diff confirms the new multipliers exist only in active-breakable branches.
- Spinner cluster XP was exactly `150`, `300`, `450`, and `525` for two, four, six, and seven PowerCores. Each target recorded exactly its remaining `150` damage; the seventh-target cap run created no overkill XP. Rammer routes likewise earned exactly the unchanged `800 XP` quota.
- A real death during the test restored Level 1, `0 XP`, one unspent point, Scrap Runner, exactly one standard hammer, no Spinner, and no Rammer.
- Developer tools reported authorized in Studio and unauthorized in a non-Studio/public context for both the test user and an unrelated user ID.
- Live arena population remained 140 active server-owned objects: Common `60`, Rare `16`, Epic `4`, crates `40`, and cores `20`.
- The respawned chassis remained grounded at approximately `Y = 1.95`, `AutoRotate = false`, with gameplay parts in `ScrapcorePlayers` and visual ghosts in `ScrapcoreCharacterGhosts`.
- Scriptable camera and all three existing HUD layers remained present. Normal Level 8-to-11 XP awards, upgrade ranks, breakable destruction/respawn state, and class reset paths remained healthy during the routes.
- Final Studio output contained only expected local developer-tool audit messages, with no errors or warnings. Studio was stopped.

### Measurement-tool invocation

The source of record is `tools/balance/Level8BalanceMeasurementRunner.luau`. It is intentionally outside all three Script Sync roots.

1. Confirm Studio is stopped and the intended local place is open.
2. For an explicit Studio-only measurement session, temporarily copy the module into `src/client/StarterPlayerScripts/Level8BalanceMeasurementRunner.luau` and let Script Sync create `StarterPlayerScripts.Level8BalanceMeasurementRunner` as a ModuleScript.
3. Start a one-client Studio playtest and require it from `LocalPlayer.PlayerScripts`.
4. Call `RunAsync("Striker" | "Spinner" | "Rammer")` for the deterministic route, `RunRammerTargetFixtureAsync()` for an isolated four-target fixture, or `RunSpinnerClusterAsync()` after creating the documented runtime-only fixture folder.
5. Poll `GetStatus()`, then read `GetResult()` or `GetSpinnerClusterResult()`.
6. Stop Studio, remove the temporary synchronized copy, and verify the ModuleScript is absent from StarterPlayerScripts before committing or publishing.

`RunRammerTargetFixtureAsync()` expects a runtime-only `Workspace.Level8RammerTargetFixture` folder containing four anchored Humanoid models. Each needs a `PrimaryPart`, numeric `TargetHealth` and `BreakableHealth` attributes, and a boolean `BreakableActive` attribute mirrored to Humanoid health. `RunSpinnerClusterAsync()` expects `Workspace.Level8SpinnerClusterFixture` with `ClusterSize` set to `2`, `4`, `6`, or `7`, Vector3 `StagingPosition` and `TargetPosition` attributes, plus one `ObjectValue` per referenced active server-owned breakable. The runner records exact first-pulse and maximum-per-pulse target counts. Create and remove these fixtures only through the local Studio MCP test session; never add them to the saved arena.

The final Studio tree was checked after removal and contained no `Level8BalanceMeasurementRunner` under StarterPlayerScripts.

## Limited human matchup observations

The supplied human observations recorded one outcome per pairing:

- Spinner defeated Striker.
- Striker defeated Rammer.
- Spinner defeated Rammer.
- Despite those outcomes, the tester reported that the matchups felt fair.
- Server and client consoles remained clean.

Fight durations, remaining health, terrain, pilot swaps, major hits/misses, and focused-build outcomes were not recorded. These three results are limited qualitative evidence only: they do not establish win rates, dominance, hard counters, or compliance with the provisional `5-12 s` fight-duration target. They support preserving accepted PvP behavior while addressing the separately measured farming disparity.

## Human farming gate

The completed human gate confirmed:

1. Spinner farming feels faster while still requiring sustained contact.
2. Rammer farming feels intentionally faster.
3. Rammer receives short recovery only after destroying a breakable; non-destroying impacts retain the normal cooldown.
4. Spinner player damage remains unchanged.
5. Rammer player damage remains unchanged.
6. A jointly damaged PowerCore awarded exactly `75 XP`, divided proportionally by effective damage.
7. Overkill granted no extra XP.
8. Server and client consoles remained clean.

## Files in this balance milestone

- `docs/LEVEL8_BALANCE_BASELINE.md` — evidence record, limited human observations, before/after farming results, and completed human farming gate.
- `tools/balance/Level8BalanceMeasurementRunner.luau` — non-synchronized Studio-only route, stationary-target, cooldown-sampling, and 2/4/6/7-target cluster measurement source. It contains no gameplay authority and must be invoked only in an explicit Studio session.
