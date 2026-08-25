# Level 300 Progression Foundation

**Status:** Provisional per-life progression foundation
**Scope:** Progression data, route data, server authority, HUD, and Studio test controls only. Later evolution robots are not implemented here.

## Run model

Every arena deployment still begins at Level 1 with zero run XP, one unspent upgrade point, zero upgrade ranks, and `ScrapRunner`. Run level, run XP, unbanked XP, upgrade points, upgrade ranks, and the selected evolution route remain temporary. Successful extraction banks the exact current unbanked XP as cosmetic-only profile XP; death, environmental destruction, disconnect, or leaving the server destroys the unfinished run.

Level 300 is the final power-progression level. Levels above 300 continue as a visible per-life score with a fixed 50-XP requirement, but they grant no upgrade points, evolution power, stat increases, or permanent advantage. The defensive `MaximumTrackedLevel` is an implementation safety boundary, not a player-facing progression target.

## Evolution gates and route data

The ordered per-life evolution gates are:

`8 → 20 → 35 → 75 → 150 → 250 → 300`

- Level 8 remains the only implemented selection gate. Its enabled, mutually exclusive choices are Striker, Spinner, and Rammer.
- Level 20 retains the provisional branch data: Striker routes to Pilebreaker or Twin Maul, Spinner routes to Stormring or Ripsaw, and Rammer routes to Ironclad or Liftjack.
- Levels 35, 75, 150, 250, and 300 are reserved data-only gates. They deliberately contain no robot names, visuals, weapons, statistics, or selectable gameplay.
- Death and canonical run reset still return the player to Scrap Runner and clear the selected route.

`ReplicatedStorage.Shared.EvolutionConfig` is the shared presentation and route-data source. `ClassService` validates that its Level 8 and Level 20 data agree with the server-owned class definitions before accepting class requests. Replicated attributes remain display-only and cannot grant a class.

## XP curve

The first seven requirements remain `40, 55, 70, 90, 115, 145, 180`, preserving the validated Level 8 total of 695 XP. Requirements from Level 8 through Level 299 increase smoothly from 35 to 50 XP. Level 300 and later score-only levels use 50 XP.

| Level reached | Cumulative run XP | Earned upgrade points |
|---:|---:|---:|
| 8 | 695 | 8 |
| 20 | 1,115 | 20 |
| 35 | 1,645 | 31 |
| 75 | 3,102 | 39 |
| 150 | 6,025 | 53 |
| 250 | 10,400 | 71 |
| 300 | 12,820 | 80 |

The 12,820-XP Level 300 target is provisional. The previously measured normalized Level 8 farming rates imply roughly 32–40 minutes of uninterrupted deterministic farming, which sits inside the broader 20–45 minute active-play target once PvP transfers and route variation are included. Human pacing, encounter downtime, extraction pressure, and later evolution power still require measurement before balance is locked.

## Upgrade schedule

Five statistics retain their accepted 30-rank exponential curves and endpoints: Speed, Attack Rate, Damage, Health, and Health Regen. A run can earn exactly 80 upgrade points through Level 300, so it cannot maximize every statistic.

- Levels 1–30 grant one point at every level, preserving existing Level 8 and Level 30 builds.
- Later grants occur at Levels 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 86, 91, 97, 102, 108, 113, 118, 124, 129, 134, 140, 145, 150, 156, 161, 167, 172, 178, 183, 189, 194, 200, 206, 211, 217, 222, 228, 233, 239, 244, 250, 256, 262, 268, 274, 280, 286, 292, 296, and 300.
- Level 301 and later grant no additional points.

Upgrade requests still pass through the existing server rate, payload, earned-point, rank-cap, derived-stat, alive-state, and arena-state validation. Client-written level, rank, point, or route attributes are not authoritative.

## Elimination transfer

A valid player elimination transfers the victim's exact server-owned unbanked run XP to the eliminator once. The former fixed elimination award is removed.

- Only the authoritative combat services can call the transfer path after confirmed lethal player damage.
- The victim humanoid and server run snapshot identify the destroyed run across Roblox's death-signal ordering.
- The humanoid is marked as rewarded and the snapshot is marked claimed, preventing duplicate Hammer, Spinner, Rammer, or stale-hit calls from transferring XP twice.
- A victim with zero unbanked XP transfers zero.
- Environmental death has no attacker and therefore transfers nothing.
- Death still resets the victim's run; disconnect removes the server cache and never banks or transfers XP.
- The eliminator receives ordinary run-level advancement and adds the transferred amount to their own extractable unbanked total.

All values remain bounded by the existing server unbanked-XP and tracked-level safety limits. No client sends XP amounts, victim state, damage, hit confirmation, or transfer receipts.

## HUD and Studio tools

The progression HUD continues to show level, current XP progress, available points, class state, and upgrade controls. Level 301 and later are labeled `SCORE` while retaining a normal score-level progress bar. Level 300 is not presented as a hard level cap.

The F2 Studio developer menu adds canonical `To Level 35`, `75`, `150`, `250`, and `300` actions alongside the existing Level 8, 20, and 30 checks. Each action calculates only the XP still needed and awards it through the normal server progression path. Authorization remains Studio-only by default; no public remote accepts a target level or XP amount.

## Deferred work

This foundation does not implement Level 20 selection, later evolution robots, later weapons, later combat statistics, a branching-tree interface, permanent power, a store, skins, monetization, matchmaking, additional modes, or production persistence rollout. The next class milestone may build the Level 20 route selection on this reviewed data model after the progression foundation passes multiplayer and pacing validation.
