# Scrapcore Class Evolution Design

**Status:** Provisional Phase 1 framework
**Design rule:** Every robot, weapon, silhouette, name, presentation, and balance value in this tree must remain original to Scrapcore.

## Purpose and run rules

Class evolution gives a temporary run a mutually exclusive playstyle decision without turning XP into a currency. Every life begins as **Scrap Runner**. Reaching Level 8 unlocks one Level 8 choice; choosing it does not spend XP, consume upgrade points, or reset existing stat upgrades. Death clears the chosen path along with the rest of the run and the next deployment begins as Scrap Runner again.

The checked-in Level 20 branches remain disabled configuration placeholders. The approved structural direction instead uses three unrestricted Level 20 families and moves the six concepts below to Level 35. No Level 20 gameplay is implemented, and every name, silhouette, mechanic, and balance choice still requires its scoped implementation and playtest gate.

## Current configured placeholder tree — disabled

```text
Level 1: Scrap Runner
├─ Level 8: Striker
│  ├─ Level 20: Pilebreaker
│  └─ Level 20: Twin Maul
├─ Level 8: Spinner
│  ├─ Level 20: Stormring
│  └─ Level 20: Ripsaw
└─ Level 8: Rammer
   ├─ Level 20: Ironclad
   └─ Level 20: Liftjack
```

## Long-run gate foundation

The ordered evolution gates are Levels **8, 20, 35, 75, 150, 250, and 300**. `EvolutionConfig` records the gates and the existing Scrap Runner → Level 8 → provisional Level 20 routes.

- Level 8 is implemented and server-selectable.
- The current Luau configuration still contains the disabled placeholder Level 20 names and parent relationships shown above.
- The approved design direction uses Impact Foundry, Motion Works, and Field Rig at Level 20, accessible from every Level 8 class. It is documentation-only and not yet configured.
- Levels 35, 75, 150, 250, and 300 are reserved route-data gates only. They have no class names, silhouettes, weapons, statistics, or UI choices yet.
- Level 300 is the final gate that may grant power. Levels above 300 continue only as run score.

After the Level 20 family commitment, later design work must extend the selected parent route rather than offering unrelated global choices. The current configured placeholder still links each Level 8 class to specific provisional Level 20 concepts; the master proposal below deliberately leaves the Level 20 family choice unrestricted. Defining a gate or a design proposal is not authorization to build its robot.

## Approved master-graph direction

`docs/EVOLUTION_TREE_MASTER_PLAN.md` contains the approved 37-node directed graph. It keeps the current Level 8 classes intact, makes Level 20 an unrestricted three-family commitment, and moves the six provisional concepts below to Level 35 so they can serve as focused or shared descendants. Level 20 replaces the Level 8 combat kit rather than stacking abilities, while restrained visual ancestry cues may remain. The approved graph does not change the checked-in `EvolutionConfig` or `ClassConfig`; the configured tree in this document remains the current disabled placeholder until a separate implementation milestone.

Initial ranged mechanics use server-authoritative raycasts with client-only cosmetic projectile visuals. Control effects cannot hard-stun, remove input, or disrupt the camera and require short bounds plus immunity or diminishing returns. Defensive mechanics remain damageable and cannot create long invulnerability, unlimited reflection, or unavoidable retaliation. The 37-node graph is the planning ceiling. Impact Foundry is the first internal prototype, but ordinary players cannot access Level 20 until all three families are implemented and validated.

## Class briefs

### Scrap Runner — implemented

- **Combat role:** Flexible close-range generalist and baseline for every run.
- **Main weapon concept:** A standard front-mounted industrial hammer.
- **Strengths:** Predictable timing, balanced recovery, and freedom to develop through any stat upgrades.
- **Weaknesses:** No specialized burst, reach, defense, or displacement advantage.
- **Intended silhouette:** Compact rectangular salvage robot with readable tracks, armored front, vulnerable rear, and a modest single hammer.
- **Counterplay:** Bait its swing, punish recovery, and exploit its lack of a specialized engagement tool.

### Striker — prototyped

- **Combat role:** Heavy close-range disruptor that converts a clean opening into burst damage and displacement.
- **Main weapon concept:** An enlarged single maul on a reinforced front mount.
- **Strengths:** Heavier hammer hits and a stronger shove make accurate impacts more decisive.
- **Weaknesses:** Slower recovery makes misses and rushed attacks easier to punish.
- **Intended silhouette:** The Scrap Runner chassis with a visibly heavier rectangular hammer head, reinforced mount, and a restrained amber identification accent.
- **Counterplay:** Stay outside the committed arc, force a miss, then close during recovery; do not contest the front at the impact frame.

### Spinner — prototyped

- **Combat role:** Sustained close-range pressure that can threaten several nearby targets while it maintains contact.
- **Main weapon concept:** A low front-mounted scrap flywheel with three deliberately asymmetric striking teeth, a reinforced nose mount, and a visible spin-up cycle.
- **Strengths:** Repeated damage pulses, multi-target pressure, and control of close frontal approaches.
- **Weaknesses:** Low shove, less immediate burst than Striker, vulnerable spin-up and recovery, and a requirement to remain close.
- **Intended silhouette:** The compact Scrap Runner chassis with a low exposed front disc, uneven tooth lengths, reinforced front bracing, and a restrained purple identification accent.
- **Counterplay:** Leave its short weapon area during spin-up or active pressure, use walls to break contact, then punish spin-down and cooldown.

Prototype Spinner tuning is provisional: spin-up interpolates from 0.40 seconds at Attack Rate Rank 0 to 0.28 seconds at Rank 30; pulse interval interpolates from 0.32 to 0.24 seconds; pulse damage interpolates from 7 to 10 across Damage ranks. The flywheel remains active while primary attack is continuously held, then spins down into a 1.1-second cooldown after release. A low-frequency client hold keepalive renews a tolerant server lease so lost input or focus cannot leave an attack running. Each server pulse applies 2.5 knockback and can affect no more than six validated targets.

Spinner applies a provisional `1.50` server-owned damage multiplier only to active breakables. Player damage, timing, range, line of sight, shove, and the six-target cap are unchanged. This makes Spinner an efficient scrap shredder when it earns sustained contact; contribution credit uses only effective damage applied before the breakable reaches zero health.

Spinner's timing and damage interpolation use the same shared normalized exponential upgrade factor as every other temporary stat, with a provisional curve strength of 1.5. Early ranks make smaller but real changes, later ranks make progressively larger changes, and the Rank 0 and Rank 30 endpoints above remain unchanged. Hold LMB to spin; RMB remains camera orbit.

### Rammer — prototyped

- **Combat role:** Frontal burst initiator that converts deliberate alignment, charge timing, and real closing speed into one decisive impact.
- **Main weapon concept:** A low reinforced wedge with two asymmetric impact rails, front bracing, and a restrained orange charge indicator rather than a hammer.
- **Strengths:** Strong single-impact damage and shove, a committed gap-closing dash, and a full charge that remains ready while primary attack is held.
- **Weaknesses:** Reduced movement and steering while charging, very limited dash steering, one target per charge, and a readable punish window after a miss.
- **Intended silhouette:** The accepted compact chassis with a broad low nose wedge, mismatched ram rails, braced front armor, and a small orange identification accent; the chassis footprint and team panels remain unchanged.
- **Counterplay:** Move off its narrow frontal line, use solid walls to deny the approach, force an early release or miss, then attack during recovery and cooldown.

Prototype Rammer tuning is provisional. Minimum valid hold is 0.20 seconds. Full-charge time uses the shared exponential Attack Rate factor from 1.20 seconds at Rank 0 to 0.84 seconds at Rank 30; release cooldown uses the same factor from 1.35 to 0.95 seconds. Charging limits movement speed to 0.75 of its legal upgraded value and steering to 0.55; dash steering is limited to 0.20 for a 0.45-second authorized window. The dash adds 8 speed at minimum charge and 16 at full charge, reaching at most approximately 47.2 studs per second at Speed Rank 30.

A minimum valid impact begins at 15 damage. A legitimate full-charge impact reaches 35 damage at Damage Rank 0 or 45 at Rank 30 and up to 26 knockback. Partial impact strength depends on server-measured hold duration and server-observed forward closing speed, both clamped to legal bounds. Only one player or active breakable can be hit per charge. The client sends start, bounded hold keepalive, release, or cancellation intent only; the server owns charge time, facing, dash authorization, spatial query, line of sight, damage, knockback, reward contribution, cooldown, and cancellation. Hold LMB and release to charge; RMB remains camera orbit.

Rammer applies a provisional `3.00` server-owned damage multiplier only to active breakables, still bounded by the shared per-hit breakable safety cap. Destroying a breakable shortens that charge's recovery to `0.35` seconds from release; non-destroying breakable impacts and all player impacts retain the normal rank-derived cooldown. This makes Rammer a high-impact scrap crusher that benefits from matching partial charge to the target while preserving its one-target limit and accepted PvP behavior.

### Pilebreaker — proposed Level 35 future work

- **Combat role:** Single-impact armor breaker descending from Impact Foundry.
- **Main weapon concept:** A vertical industrial pile-driver that stores force for one compact strike.
- **Strengths:** Exceptional payoff against slow or cornered targets.
- **Weaknesses:** Obvious preparation, narrow contact zone, and the longest punish window in its branch.
- **Intended silhouette:** Tall reinforced nose tower with one central downward-driving tool and heavy front bracing.
- **Counterplay:** Move laterally during its preparation and punish the tool's reset cycle.

### Twin Maul — proposed Level 35 future work

- **Combat role:** Sustained close-range Impact Foundry/Motion Works hybrid.
- **Main weapon concept:** Two compact offset mauls that alternate instead of landing one oversized blow.
- **Strengths:** Repeated pressure and better coverage during a close engagement.
- **Weaknesses:** Lower single-hit threat, wider commitment footprint, and difficulty disengaging safely.
- **Intended silhouette:** Broad reinforced shoulders with visibly staggered left and right hammer mechanisms.
- **Counterplay:** Create distance, attack through the timing gap, and avoid remaining between both swing lanes.

### Stormring — proposed Level 35 future work

- **Combat role:** Perimeter-control Motion Works/Field Rig hybrid.
- **Main weapon concept:** A segmented guard ring that delivers intermittent powered impact arcs.
- **Strengths:** Strong multi-directional denial and protection while holding contested space.
- **Weaknesses:** Telegraphs its powered arcs and gives up focused pursuit pressure.
- **Intended silhouette:** Wide circular guard broken by three distinctive powered segments around a compact central robot.
- **Counterplay:** Read the powered segment, enter through an inactive gap, or force it away from the space it wants to hold.

### Ripsaw — proposed Level 35 future work

- **Combat role:** Focused pursuit specialist descending from Motion Works.
- **Main weapon concept:** A low forward industrial cutter that must maintain alignment to build pressure.
- **Strengths:** Threatens retreating or pinned targets with sustained frontal contact.
- **Weaknesses:** Narrow threat direction, poor side coverage, and dependence on uninterrupted pursuit.
- **Intended silhouette:** Compact triangular nose framing one low exposed cutting assembly, with the original chassis still recognizable behind it.
- **Counterplay:** Break line, change direction sharply, and attack from the sides while it tries to realign.

### Ironclad — proposed Level 35 future work

- **Combat role:** Defensive Impact Foundry/Field Rig hybrid.
- **Main weapon concept:** A broad energy-absorbing plow that trades peak speed for reliable frontal control.
- **Strengths:** Stable frontal engagements and strong resistance to displacement while committed.
- **Weaknesses:** Wide turning radius, limited rear defense, and weak chase pressure.
- **Intended silhouette:** Broad armored prow, low roof, and clearly exposed rear machinery.
- **Counterplay:** Refuse the frontal contest, rotate around the wide chassis, and attack its exposed recovery path.

### Liftjack — proposed Level 35 future work

- **Combat role:** Positional-control specialist descending from Field Rig.
- **Main weapon concept:** Short front lifting forks powered by a visible central jack mechanism.
- **Strengths:** Reorients opponents and creates wall or teammate follow-up opportunities.
- **Weaknesses:** Low direct damage, precise alignment requirement, and limited threat when isolated.
- **Intended silhouette:** Narrow twin forks below a bright central hydraulic block, leaving the chassis sides visibly vulnerable.
- **Counterplay:** Approach off-axis, avoid walls, and punish failed lift alignment before the forks reset.

## Originality and authority constraints

- Other arena-evolution games are reference points only for per-life levels, threshold choices, exclusive branches, distinct roles, later specialization, and death resets.
- Do not reproduce another game's class names, tank geometry, weapon layout, numbers, icons, colors, sounds, map design, interface, wording, branding, or tree presentation.
- The server alone owns eligibility, selection, class combat modifiers, cooldown acceptance, damage, knockback, and reset behavior. Replicated attributes exist only for presentation.
- Disabled and future classes must not have a client- or server-accessible gameplay path until a scoped milestone explicitly enables them.
