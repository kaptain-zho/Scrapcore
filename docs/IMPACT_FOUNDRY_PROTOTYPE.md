# Impact Foundry Internal Prototype

**Status:** Studio-only Level 20 prototype
**Public availability:** Disabled until Impact Foundry, Motion Works, and Field Rig are all implemented and validated

## Scope and purpose

Impact Foundry is the first playable test of Scrapcore's generic evolution-route foundation. It answers two bounded questions:

1. Can every Level 8 class enter one common Level 20 family without retaining or stacking its old weapon and ability kit?
2. Does a readable automatic forge strike create distinct close-range counterplay while preserving server authority and the accepted movement foundation?

The prototype does not enable public Level 20 selection, Motion Works, Field Rig, any Level 35 descendant, permanent combat power, or a new progression gate.

## Route and lifecycle contract

- `EvolutionConfig` contains the approved 37 stable node IDs and explicit parent-to-child edges.
- `EvolutionRouteService` owns the current node, committed Level 20 family, Level 8 ancestry, reached gates, selected gate nodes, and canonical run serial.
- Replicated route attributes support visuals and HUD only. Rewriting them cannot authorize a route.
- A future public request carries only choice intent and a displayed run serial. The server rechecks the canonical level, run, session, life, graph edge, availability, payload, and rate.
- The internal `StudioTestActivateImpactFoundry` developer action is the only enabled path. It uses the same route validation after establishing Level 20 and requires an existing Level 8 choice.
- Death, respawn, extraction, lobby return, disconnect, and a fresh run clear every route field and restore the ordinary Scrap Runner lifecycle.

## Complete kit replacement

Impact Foundry removes the standard hammer, Striker heavy hammer and reinforcement, Spinner flywheel, or Rammer wedge before attaching its own loadout. The preserved Level 8 class ID remains only as server-owned ancestry data for the current run; its combat controllers and ready attributes are disabled. At most one class weapon model and one weapon motor may remain.

The prototype loadout contains ten BaseParts: one invisible weapon root plus nine original primitive visual parts. The striking face, housing, braces, clamp, accent, windup glow, and recovery vents are unanchored, massless, non-colliding, non-touching, non-querying, and welded to the Motor6D-driven weapon root. The accepted chassis collider, footprint, grounding, team panels, and source robot model are unchanged.

## Server-owned forge strike

LMB sends one sequenced attack intent. The client may immediately predict the windup animation, but it never reports a target, position, direction, timestamp, timing result, damage, knockback, or hit.

The server owns these phases:

1. **Idle:** accept an exact, rate-limited request only from a living Arena player whose current route is Impact Foundry and whose weapon state is valid.
2. **Windup:** use server time, reduce the legal movement envelope, and apply bounded resistance only to frontal horizontal displacement.
3. **Impact:** automatically query from the actual weapon attachment, require frontal placement and line of sight, deduplicate targets, cap the strike at two targets, and apply authoritative damage and knockback once.
4. **Recovery:** reject additional attacks until the rank-derived cooldown ends.

One server Heartbeat updates every active Impact Foundry state. Character loss, death, route reset, lobby transition, extraction, disconnect, or missing weapon state cancels the attack immediately. Repeated respawns do not create per-life update loops.

## Provisional tuning

| Value | Rank 0 | Rank 30 / limit |
|---|---:|---:|
| Windup | 0.55 s | 0.42 s |
| Accepted-attack cooldown | 1.50 s | 1.20 s |
| Player damage | 38 | 50 |
| Horizontal knockback | 25 | 25 |
| Targets per strike | — | 2 |
| Breakable-only damage multiplier | — | 1.75 |
| Query box | — | 5.8 × 3.2 × 4.6 studs |
| Maximum target range | — | 7.2 studs |
| Windup movement multiplier | — | 0.65 |
| Windup steering multiplier | — | 0.60 |
| Frontal knockback multiplier | — | 0.45 |
| Protected front half-angle | — | 55 degrees |

Damage, windup, and cooldown use the shared rank curve. Breakable contribution records only effective applied damage and cannot create XP through overkill. Impact Foundry does not change Level 8 player damage, farming modifiers, cooldowns, range, knockback, movement, or controls.

## Counterplay and safety boundaries

- The windup cannot be held, manually cancelled for advantage, or converted into an invulnerability state.
- The robot remains damageable. No damage reduction, hard stun, input removal, camera disruption, anchoring, wall bypass, vertical-motion resistance, or unlimited reflection is added.
- Frontal displacement resistance exists only during the commitment window and only when the attack source is within the protected front arc. Side and rear shove remain unchanged.
- The strike cannot hit through walls, behind the chassis, outside its bounded range, or more than once per target.
- Misses enter the same recovery as hits.
- Ordinary Level 20 HUD messaging remains **LEVEL 20 ROUTES — UNDER CONSTRUCTION**.

## Studio test procedure

1. Deploy to the Arena through the normal lobby portal.
2. Use the Studio-only developer menu to reach Level 8, then select Striker, Spinner, or Rammer normally.
3. Use **Activate Impact Foundry**. The action establishes Level 20 and invokes the server route validator; it must fail without a valid Level 8 choice.
4. Verify the old kit is gone, one Impact Foundry loadout is present, the HUD shows `IMPACT FOUNDRY — LMB Forge Strike`, and LMB performs one automatic windup-impact-recovery cycle.
5. Repeat from all three Level 8 parents, then test death, extraction, lobby return, redeployment, malformed requests, walls, rear and out-of-range targets, breakables, latency, and two clients.

Impact Foundry remains an internal prototype after these checks. Public Level 20 access requires separate implementation and validation of Motion Works and Field Rig plus a three-family multiplayer balance gate.
