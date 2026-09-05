# Motion Works directional validation — 2026-09-04

## Status and hard stop

**Partial validation; no multiplayer approval and no commit.** The directional gap was reproduced and repaired. Meaningful reverse/side abuse and normal curves were observed at zero and 150 ms incoming replication lag. A final bounded coastdown-envelope repair has **not** received its fresh-session runtime regression.

Roblox Assistant updated during the session from `c94bd68` to `7fe3701`. Studio explicitly warned that this can cause instability and requires a Studio restart. Later remote setup calls did not reach the server: the player remained Lobby / ScrapRunner with zero accepted developer actions. The final two nominal reverse/strafe trials therefore measured Idle lobby movement, not Motion Works, and are discarded. Do not use them to claim a pass.

Studio was stopped in Edit mode, incoming replication lag was verified zero, all three Script Sync roots were healthy, and runtime fixtures were absent from Edit. Gameplay errors were not observed in valid trials; the final console was **not clean** because of Roblox Assistant version/remote-service warnings. Those warnings must be cleared by restarting Studio, not hidden or called gameplay passes.

## Root causes and narrow repairs

1. The original scalar Driven allowance granted the same maximum speed and acceleration regardless of direction. Direction was checked separately, leaving an insufficiently explicit authorization envelope.
2. The original reverse probe fought the live LinearVelocity/Humanoid controller. Requesting 40 did not establish 40 server-observed studs/second. The bounded client fixture now temporarily disables its local movement actuator and Humanoid locomotion during forged-velocity probes, then restores them. Real keyboard tests retain the normal movement controller.
3. Reverse input originally still produced normalized forward drive. Reverse/side input now targets no more than ordinary upgraded movement speed. A 0.10 forward-input deadzone prevents floating-point noise from treating exactly sideways input as forward drive.
4. Server speed allowance is now directional: `min(drivenSpeed, normalSpeed + max(drivenSpeed-normalSpeed, 0) * clamp(forwardDot, 0, 1))`. At Rank 0/full output the forward limit is 34.32, but reverse/side limits are 26 before tolerance. The corresponding Rank 30 limits are 41.184 and 31.2. Acceleration never exceeds the ordinary upgraded server limit (600 at Rank 0; 720 at Rank 30).
5. The shared monitor passes its server-measured displacement velocity and elapsed time to Motion Works. Physical velocity violations cancel immediately; directional displacement uses the existing consecutive-sample guard. At 150 ms, a measured position update briefly implied 33.679 while physical reverse speed was only 25.090; immediately cancelling that single sample was a false positive.
6. A fixed 6.5-stud sample-distance limit also falsely corrected a 7.007-stud movement over a delayed 0.389-second sample. Its allowance now uses bounded server elapsed time, capped at 0.50 seconds, while retaining speed and acceleration checks. No client timestamp is accepted.
7. Damage requires forward velocity, the frontal weapon region, range, LOS, and at least 8 studs/second of closing speed projected toward the actual target. Target motion cannot increase damage beyond the attacker's forward speed. Side or reverse motion is insufficient even when closing positively toward a target behind the robot.
8. Final, still-unverified repair: bounded Coastdown retains a directional forward inertial envelope so delayed pre-release velocity does not cause false corrections. Reverse/side motion still receives no forward bonus. Coastdown corrections now increment the Motion Works correction counter too. Earlier counter values covered Spooling/Driven only; they did not prove absence of every coastdown correction. Temporary diagnostic attributes used to find the issue were removed from source.

No accepted Level 8 damage, cooldown, knockback, class configuration, camera tuning, or arena layout was changed.

## Method and limits

- All builds used Speed/Attack Rate/Damage Rank 0 unless explicitly stated otherwise. Endpoint limits above are configuration arithmetic, not measured Rank 30 runtime results in this pass.
- Tests used real Studio LMB and keyboard inputs for normal movement, with a temporary aim fixture setting the ordinary AlignOrientation target. Gradual curves commanded approximately 90 degrees over 1.2 seconds; forged heading reversal directly changed root orientation for a bounded 0.3 seconds.
- Registered breakables were temporarily placed relative to the moving robot to exercise queries repeatedly; collision was disabled only for those runtime fixtures and restored afterward. The isolated runtime lane was cleared of other breakables. This is directional query validation, not a physical-collision or farming-balance benchmark.
- Humanoid targets were temporary server humanoid fixtures, **not a genuine second Player**. Real-player authorization, replication, collision, and XP interactions remain in the human gate.
- “Forward dot” is horizontal velocity direction dotted with chassis forward. “Closing” is signed velocity toward the target; without a target it is forward speed. Rear contact can have positive closing while forward dot is −1, and must still do zero damage.
- Speed/angle/closing columns below cover the named phase; damage/correction/request totals cover the complete sampled case. Spooling peaks can include deceleration from an already-moving Idle state.
- Forged trials include a short legitimate forward interval before injection. Nonzero total damage there is **not reverse/side damage**. Health-change events recorded the direction and closing speed at each hit; all instrumented hits had legal forward motion and `invalidDirectionDamage = 0`.
- The lower-speed boost-window probes requested 34, not only an obviously extreme 80. They reached approximately 33.9–34.0 and were corrected. An attempted sideways probe that only reached 24.747 was discarded and repeated.
- Some tool calls stalled or began after energy exhaustion. A 65-second stalled trial, missing-Driven trials, earlier false-correction trials, and post-plugin-update lobby trials are not passes. Raw data intentionally preserves failed/intermediate observations.
- Rows are the latest usable observations for each case/lag. They span revisions before the final coastdown adjustment, so they **do not establish that the final working tree passes the complete matrix**.

## Server-observed matrix

| Case | Lag ms | Phase | Peak speed | Forward dot min..max | Closing min..max | Damage total / invalid direction | Corrections | Rejected |
|---|---:|---|---:|---|---|---|---:|---:|
| 11 Idle reverse | 0 | Idle | 25.997 | -1.000..-1.000 | -25.997..0.000 | 0.000 / 0.000 | 0 | 0 |
| 12/13 Spooling and Driven reverse | 0 | Spooling | 17.181 | -1.000..-1.000 | -17.181..-0.933 | 0.000 / 0.000 | 0 | 0 |
| 12/13 Spooling and Driven reverse | 0 | Driven | 25.783 | -1.000..-1.000 | -25.783..-17.236 | 0.000 / 0.000 | 0 | 0 |
| 14 Driven strafe | 0 | Driven | 25.801 | 0.000..0.000 | 0.000..0.000 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse humanoid rear | 0 | Driven | 25.810 | -1.000..-1.000 | 16.739..25.810 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse PowerCore | 0 | Driven | 25.763 | -1.000..-1.000 | 17.472..25.763 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse ReinforcedCrate | 0 | Driven | 25.743 | -1.000..-1.000 | 12.376..25.743 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse ScrapPileCommon | 0 | Driven | 25.779 | -1.000..-1.000 | 17.832..25.779 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse ScrapPileEpic | 0 | Driven | 25.797 | -1.000..-1.000 | 17.134..25.797 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse ScrapPileRare | 0 | Driven | 25.814 | -1.000..-1.000 | 16.788..25.814 | 0.000 / 0.000 | 0 | 0 |
| 16 Strafe humanoid | 0 | Driven | 25.823 | 0.000..0.000 | 0.000..0.000 | 0.000 / 0.000 | 0 | 0 |
| 16 Strafe PowerCore | 0 | Driven | 25.772 | 0.000..0.000 | 0.000..0.000 | 0.000 / 0.000 | 0 | 0 |
| 17 Forged reverse | 0 | Driven | 79.977 | -1.000..1.000 | -79.977..32.390 | 26.359 / 0.000 | 1 | 0 |
| 17 Forged sideways | 0 | Driven | 79.977 | 0.000..1.000 | -0.001..27.665 | 7.714 / 0.000 | 1 | 0 |
| 17 Reverse boost-window abuse | 0 | Driven | 33.985 | -1.000..1.000 | -33.985..32.483 | 0.000 / 0.000 | 1 | 0 |
| 17 Sideways boost-window abuse | 0 | Driven | 33.985 | 0.000..1.000 | 0.000..27.822 | 0.000 / 0.000 | 1 | 0 |
| 18 Forged rapid heading reversal | 0 | Driven | 27.117 | -0.999..1.000 | -10.368..27.117 | 0.000 / 0.000 | 1 | 0 |
| 18 Forward to reverse | 0 | Driven | 32.515 | -1.000..1.000 | -23.830..32.515 | 0.000 / 0.000 | 0 | 0 |
| 19 Forward curve 90 degrees | 0 | Driven | 33.578 | 0.975..1.000 | 22.524..32.911 | 0.000 / 0.000 | 0 | 0 |
| 11 Idle reverse | 150 | Idle | 25.997 | -1.000..-1.000 | -25.997..0.000 | 0.000 / 0.000 | 0 | 0 |
| 12/13 Spooling and Driven reverse | 150 | Spooling | 23.522 | -1.000..-1.000 | -23.522..-5.624 | 0.000 / 0.000 | 0 | 1 |
| 12/13 Spooling and Driven reverse | 150 | Driven | 25.606 | -1.000..-1.000 | -25.606..-18.728 | 0.000 / 0.000 | 0 | 1 |
| 14 Driven strafe | 150 | Driven | 25.981 | 0.000..0.000 | 0.000..0.000 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse humanoid rear | 150 | Driven | 25.841 | -1.000..-1.000 | 0.000..25.841 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse PowerCore | 150 | Driven | 25.981 | -1.000..-1.000 | 17.654..25.981 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse ReinforcedCrate | 150 | Driven | 25.981 | -1.000..-1.000 | 16.736..25.981 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse ScrapPileCommon | 150 | Driven | 25.981 | -1.000..-1.000 | 16.145..25.981 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse ScrapPileEpic | 150 | Driven | 25.981 | -1.000..-1.000 | 17.872..25.981 | 0.000 / 0.000 | 0 | 0 |
| 15 Reverse ScrapPileRare | 150 | Driven | 25.981 | -1.000..-1.000 | 17.738..25.981 | 0.000 / 0.000 | 0 | 0 |
| 16 Strafe humanoid | 150 | Driven | 25.981 | 0.000..0.000 | 0.000..0.000 | 0.000 / 0.000 | 0 | 0 |
| 16 Strafe PowerCore | 150 | Driven | 25.889 | 0.000..0.000 | 0.000..0.000 | 0.000 / 0.000 | 0 | 0 |
| 17 Forged reverse | 150 | Driven | 79.977 | -1.000..1.000 | -79.977..30.181 | 7.694 / 0.000 | 1 | 1 |
| 17 Forged sideways | 150 | Driven | 79.977 | 0.000..1.000 | 0.000..28.279 | 13.468 / 0.000 | 1 | 0 |
| 17 Reverse boost-window abuse | 150 | Driven | 33.985 | -1.000..1.000 | -33.985..28.676 | 7.506 / 0.000 | 1 | 1 |
| 17 Sideways boost-window abuse | 150 | Driven | 33.891 | 0.002..1.000 | 0.000..24.430 | 0.000 / 0.000 | 1 | 1 |
| 18 Forged rapid heading reversal | 150 | Driven | 29.948 | -1.000..1.000 | -16.479..29.946 | 0.000 / 0.000 | 1 | 1 |
| 18 Forward to reverse | 150 | Driven | 28.709 | -1.000..1.000 | -23.655..28.709 | 0.000 / 0.000 | 0 | 0 |
| 19 Forward curve 90 degrees | 150 | Driven | 33.948 | 0.967..1.000 | 26.614..33.731 | 0.000 / 0.000 | 0 | 0 |

All reverse and sideways normal-contact rows dealt zero damage. All completed high-speed/window abuse and rapid-heading rows received a correction. Legitimate forward turns and forward-to-reverse switching received no Spooling/Driven correction in their usable trials. The later-discovered coastdown counter limitation is described above.

A positive-control frontal moving humanoid trial before the latency pass affected seven targets/pulses cumulatively (one fixture hit seven times), dealing 51.859 total health damage; it verified that the fixture could actually receive Motion Works damage. It is not a PvP DPS benchmark.

## Required restart and remaining automated work

1. Restart Roblox Studio, reopen the existing `savefile.rbxl`, and allow all three existing Script Sync roots to settle. Do not rebuild or discard uncommitted source.
2. Verify the Assistant/MCP version warning is gone and every setup action reaches the server before sampling.
3. Re-run the complete directional matrix on the **final** coastdown code, including release/coast corrections, at 0 and 150 ms. Add Rank 30 directional/acceleration endpoint runtime checks.
4. Re-run physical wall-lift/grounding, camera, standard hammer, Striker, Spinner, Rammer, and Impact Foundry regressions after these movement changes. Prior unchanged-source or spot-check evidence is not a fresh regression pass.
5. Exercise sideways contact across additional breakable categories and an actual second player where supported. The current side fixture covered PowerCore plus a humanoid, while reverse covered all five registered categories.
6. Restore latency to zero, stop Studio, inspect both contexts' consoles, and repeat whitespace checks. Do not request approval until the remaining automatic gates pass.

## Genuine two-client gate — instructions only, not ready for approval

After the restart and remaining automated checks pass:

1. Start a real two-client Studio test. Deploy both players. On A, use authorized F2 controls to reach Level 8, choose a class, then activate Motion Works. B retains a normal accepted Level 8 kit.
2. At zero latency, verify both clients see exactly one carriage and matching spool, Driven, coast, recovery, and energy states. Keep the player list expanded; confirm HUD readability.
3. With A aiming away from B, hold reverse through Idle, Spooling, and Driven, then back into B. Repeat sideways and with each ScrapPile rarity, a crate, and a PowerCore. There must be no Motion Works damage while backing or strafing.
4. Perform frontal moving passes: damage must require real forward closing motion and stop when stationary, separated, outside the frontal region, or blocked by a wall.
5. Make smooth curves and roughly 90-degree turns, then switch from forward to reverse and release. Watch for rubber-banding, unintended extra speed, wall lift, loss of grounding, or camera disruption. Do not inject exploit commands during human play.
6. Share a PowerCore and record effective damage and proportional XP; the total reward must be 75. Confirm other accepted kits still work.
7. Kill A during spool and drive; check Scrap Runner/one-hammer reset and B's preserved run. Test extraction/lobby cleanup and redeployment.
8. Repeat the directional, release, and synchronization checks at 150 ms. Restore latency to zero, inspect server and both client consoles, stop Studio, and record exact damage/speed surprises, visual desynchronization, and fairness.

## Files for reproduction

The two `tools/motionworks/DirectionalProbe.*.luau` helpers are inert, non-synchronized files and explicitly reject non-Studio execution. Copy them only into temporary **running-playtest** ServerScriptService and PlayerScripts instances through MCP, never into the synchronized roots. Their BindableFunctions are local measurement controls, not public remotes. The server `Prepare` action now asserts Motion Works setup succeeded before sampling. Stop discards the runtime fixtures.

The raw results are in `tools/motionworks/directional-results-2026-09-04.json`. They include intermediate failures for auditability. No permanent gameplay fixtures, production DataStore settings, commits, or publications were created. `art/` remains untouched.

