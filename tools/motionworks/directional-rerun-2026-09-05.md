# Motion Works directional rerun — 2026-09-05

**Status:** Fresh-session automated rerun of the cases 11–19 directional matrix, coastdown-envelope verification, Rank 30 endpoints, positive damage control, and single-client regression checks on the **final working tree** (the previously unverified coastdown revision). Single-client Studio evidence via MCP; **not** multiplayer approval. Nothing committed or staged; `git diff --check` clean; HEAD `b951c16`.

## Session preconditions

- Studio fully restarted after the Assistant plugin update; console clean before testing (no Assistant/MCP warnings).
- All three Script Sync roots reconnected from the **disk** version; all six changed/new Motion Works sources verified byte-identical to the working tree by checksum (CRLF-normalized polynomial hash) before any test.
- **Anomaly found and repaired in the place file:** the stale baseline `savefile.rbxl` had all nine pre-existing `StarterPlayer.StarterPlayerScripts` LocalScripts saved with `Disabled=true` (only the freshly synced `MotionWorksController` was enabled). The synced `.luau` sources cannot carry the Disabled property, so this survived the disk re-sync and made the game unplayable (no robot controller, no HUDs, no movers). All nine were re-enabled in Edit mode as one Change History recording; nothing else in the place was modified. This anomaly is Studio place state only — no repository file was touched.
- Mock profile adapter confirmed (`ProfileDataAdapter=Mock`). Level 20 public selection remained disabled throughout.
- Probe fixtures were the repository `tools/motionworks/DirectionalProbe.*.luau` sources, copied verbatim into the running playtest per the documented procedure, reinstalled whenever their 15-minute watchdogs expired. Two extra minimal helpers were used: a temporary server setup script exposing only `PlayerSessionService.TeleportForStudioTest`, and a client watcher that invoked the probe's own Forge/Curve during the server-confirmed Driven phase (tool-call latency made manual timing impossible). All fixtures were runtime-only and were discarded when the playtest stopped; Edit mode verified clean afterward.
- Because MCP tool-call latency (2–10 s per call) burns runway at 26 studs/s, reverse and strafe trials ran on the arena diagonal (aim fixture yaw = π/4, ~505-stud lane) instead of a straight axis. Direction math (dot/closing, chassis-relative) is unaffected.

## Directional matrix — 0 ms (final code)

| Case | Result | Key server observations |
|---|---|---|
| 11 Idle reverse | PASS | Idle peak 25.997, dot −1.000, 0 damage/corrections |
| 12/13 Spool+Driven reverse | PASS | Full reverse held through Spooling (25.997) and Driven (25.997, dot −1); Coastdown reverse 25.997 dot −1; 0 corrections, 0 damage. Stronger than baseline (full pre-spool reverse momentum). |
| 14 Driven strafe | PASS | dot ≈ 0.000 through all phases, ≤25.997, 0 everything |
| 15 Reverse contact ×6 (humanoid rear + PowerCore, ReinforcedCrate, ScrapPile Common/Rare/Epic) | PASS ×6 | closing +18.7..+26.0 into trailing target, dot −1, **0 damage**, 0 invalid, 0 corrections, Y flat |
| 16 Strafe contact ×6 (humanoid + all five breakables — extended coverage) | PASS ×6 | dot ≤0.047, closing ≤1.2, **0 damage**, 0 corrections |
| 17 Forged reverse 80 | PASS | observed 80.11 reverse; drive cancelled; **corrections=2 (one counted during Coastdown — the new coastdown accounting working)**; invalid damage 0 |
| 17 Forged sideways 80 | PASS | observed 79.98 at dot≈0; corrections=2; invalid 0 |
| 17 Reverse boost-window 34 | PASS | peak 34.00 reverse; 1 correction; invalid 0 |
| 17 Sideways boost-window 34 | PASS | peak 33.99 dot≈0; 1 correction; invalid 0 |
| 18 Forged rapid heading reversal (0.3 s root flip mid-Driven) | PASS | dot swung +1 → −0.61; exactly 1 correction; drive cancelled; 0 damage |
| 18 Forward to reverse (legal) | PASS | Driven forward peaked **34.31** (Rank 0 ceiling 34.32); **Coastdown carried 34.32 forward inertia with 0 corrections — the final coastdown-envelope repair verified**; legal reverse after release drew no corrections |
| 19 Forward curve 90° | PASS | Driven dot 0.848..1.000 at ≤33.6, 0 corrections; turning coastdown (dot down to 0.073) also 0 corrections |

## Directional matrix — 150 ms incoming replication lag (final code)

| Case | Result | Notes |
|---|---|---|
| 11 Idle reverse | PASS | dot −1, ≤26.00, clean |
| 12/13 Spool+Driven reverse | PASS | reverse ≤25.85 dot −1 all phases; 0 corrections, 0 rejected |
| 14 Driven strafe | PASS | dot ≤0.041, clean |
| 15 Reverse contact ×6 | PASS ×6 | 0 damage / 0 invalid / 0 corrections in every category |
| 16 Strafe contact ×6 | PASS ×6 | 0 damage / 0 corrections in every category |
| 17 Forged reverse 80 | PASS | 1 correction + 1 rejected (matches baseline shape), invalid 0 |
| 17 Forged sideways 80 | PASS | 1 correction + 1 rejected, invalid 0 |
| 17 Reverse boost 34 | PASS | 1 correction + 1 rejected, invalid 0 |
| 17 Sideways boost 34 | PASS | 1 correction + 1 rejected, invalid 0 |
| 18 Forged heading reversal | PASS | 1 correction + 1 rejected, 0 damage |
| 18 Forward to reverse | PASS | **Coastdown 34.32 forward inertia, 0 corrections at 150 ms — delayed pre-release velocity produced no false correction (the exact repair target)**; 1 benign rejected request |
| 19 Forward curve 90° | PASS | Driven ≤33.23; turning coastdown dot 0.42..0.87 at 33.28 with 0 corrections |

## Positive damage control (0 ms)

Trailing frontal humanoid at root-relative −7 (inside the query box, which spans ≈4.9–8.7 studs ahead of the root given the ~5.7-stud hit-origin offset): **8/8 pulses landed**, damage ramped 2.87 → 9.00 (exact Rank 0 per-pulse cap) as speed rose 19 → 34.2, every event dot 1.000 with legal closing, invalid 0, 0 corrections. Earlier zero-damage placements at −4/−5 were geometry misses (behind the box), not a damage regression; the pulse's direction/speed gate runs before the box query, so contact-case conclusions are unaffected.

## Rank 30 endpoints (0 ms, Speed Rank 30 via unlimited-points dev toggle)

- Forward Driven ceiling: straight-lane peak **41.125** vs configured 41.184; 0 corrections; Coastdown carried 41.136 forward inertia with 0 corrections.
- Reverse/side cap: misaligned-drive trial clamped at **31.194** vs configured 31.2 with 0 corrections (server grants no forward bonus off-axis).
- Forged sideways 40 during Driven: **1 correction**, drive cancelled.
- Straight-wall press at Rank 30: spool at wall, Driven cancelled by the 5-stud obstruction probe after one sample, root Y never exceeded 2.89 (pre-repair failure was 5.2+), final Y 1.95 grounded at z≈−186.4, 0 corrections.

## Regression checks (single client, after directional pass, latency 0)

- Canonical reset (unlimited-points off → run reset): respawn to Level 1 Scrap Runner, rank attributes 0, exactly one `EquippedHammer`, arena respawn. PASS
- Standard hammer: 1 accepted attack. Striker (fresh L8): accepted hammer attack. Impact Foundry (Studio activation from Striker): 1 accepted request, 1 strike, 0 rejections. Spinner (fresh L8): 6 accepted requests through an LMB hold, clean return to Idle. Rammer (fresh L8): 6 accepted requests through a charge hold, 0 movement violations. PASS
- Motion Works death: authoritative-damage kill with Motion Works active → respawn restored Level 1 Scrap Runner, one hammer, Motion Works phase Idle, energy 100. PASS
- Extraction: +100 XP, extraction-zone prompt (real E hold), 10 undamaged seconds → banked exactly 100 once (BankedProfileXP 0→100, SuccessfulExtractions 1, LifetimeExtractedXP 100), weaponless lobby return; redeploy through the main portal produced a canonical Level 1 run with unbanked 0 and banked preserved. PASS
- Wall/obstruction: covered above (corner obstruction cancel at 0 ms during case 18 setup: Driven ended in 0.47 s with 0 lift and 0 false corrections; straight-wall Rank 30 press clean).

## End state and hygiene

Playtest stopped; latency confirmed 0; no QA fixtures remain in Edit; console contained only expected DevTools action logs plus two errors from the test tooling itself (a blocked `VirtualInputManager` capability probe and one double-`Finish` invocation of the QA fixture) — no gameplay warnings or errors. Working tree unchanged: 28 status entries, nothing staged, `git diff --check` clean, HEAD `b951c16`. `art/` untouched; legacy `src/server/ServerScriptService/` untouched.

## Continuation session — same day, second playtest (latency 0 throughout)

- **Death during active Driven:** robot pre-damaged to 10 HP, fatal authoritative damage confirmed fired at phase `Driven` (client watcher flag). Result: no pulses after death (pulse counter stable), respawn to Level 1 Scrap Runner with exactly one `EquippedHammer`, Motion Works phase Idle, energy 100. PASS
- **Extraction damage-reset:** first attempt banked before the injected damage could land (tool latency exceeded the 10 s window) — recorded as a second clean one-time banking (exactly +100, lobby return). Proper retest with a pre-armed client watcher: authoritative damage ~3 s into the countdown incremented `ExtractionTimerResetCount` 0→1, nothing banked at that moment, the countdown then completed undamaged and banked exactly +100 once (BankedProfileXP 100→200, SuccessfulExtractions 2), lobby return. PASS
- **Protocol fuzz (final code):** 43 hostile requests to `MotionWorksAttackIntent` — NaN/±inf/negative/stale/non-integer/excessive-advance sequences, non-string intent, missing/extra arguments, unknown intent, premature KeepAlive, orphan Stop, and a 30-request premature-KeepAlive burst — produced exactly 43 rejections, 0 accepted, phase Idle, energy untouched, no server errors. PASS
- **Keepalive-lease loss:** a legitimate raw `Start` (accepted, +1) with keepalives withheld: Spooling 0.11 s → Driven 0.77 s → lease ended the drive at 1.41 s → Coastdown → Recovery → Idle at 3.0 s; no rejections, no errors, energy recovered. PASS
- **RMB camera orbit: INCONCLUSIVE — tooling limitation, not a regression.** Instrumented `UserInputService` capture proved the MCP mouse tool's synthetic moves reach the client (26 MouseMovement events, RMB/LMB registered) but every event carries `Delta = 0`, so a delta-driven orbit receives nothing. Orbit feel remains deferred to the human gate (already in the two-client script).
- **HUD screenshot (desktop viewport):** health bar, RUN XP (UNBANKED) / BANKED PROFILE XP panel, RUN GROWTH LV 20 panel with "MOTION WORKS — Hold/Release LMB" control line and "MOTION — READY · E 100" phase/energy line all readable and separated. Device-simulator layouts remain deferred.
- **31-rank monotonicity sweep (final tree):** GetSpoolDuration 0.62→0.46, GetPulseInterval 0.34→0.26, GetRecoveryDuration 1.20→0.92, GetPulseDamage 9→13, GetNormalMaxSpeed 26→31.2, GetDrivenSteeringMultiplier 0.85→0.40 — all positive, finite, monotonic across ranks 0–30. ALL PASS. (The two multi-argument limit functions were runtime-verified in the directional pass: 34.32/41.184 forward, 26/31.2 reverse-side.)
- **End state:** playtest stopped; console contained only expected DevTools logs with zero warnings/errors; no fixtures left in Edit; latency 0; working tree unchanged (28 entries, nothing staged, `git diff --check` clean, HEAD `b951c16`).

## Explicitly not covered in this pass

- Genuine two-client human gate (deliberately not started, per instruction).
- Camera-orbit feel (tooling cannot synthesize mouse deltas — see above), device-simulator/phone HUD layouts, OS-level focus-loss input behavior, disconnect during each active phase.
- Real second-player damage/replication/XP interactions (humanoid fixtures only).
- The **place-file Disabled-scripts anomaly**: the fix lives only in the unsaved Studio DataModel. Whether to save `savefile.rbxl` (and whether the stale save indicates the wrong .rbxl was reopened) is a user decision.
