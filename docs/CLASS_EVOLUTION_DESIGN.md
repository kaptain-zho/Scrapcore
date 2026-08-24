# Scrapcore Class Evolution Design

**Status:** Provisional Phase 1 framework
**Design rule:** Every robot, weapon, silhouette, name, presentation, and balance value in this tree must remain original to Scrapcore.

## Purpose and run rules

Class evolution gives a temporary run a mutually exclusive playstyle decision without turning XP into a currency. Every life begins as **Scrap Runner**. Reaching Level 8 unlocks one Level 8 choice; choosing it does not spend XP, consume upgrade points, or reset existing stat upgrades. Death clears the chosen path along with the rest of the run and the next deployment begins as Scrap Runner again.

Level 20 branches are provisional design targets only. They are not implemented by the current milestone, and their names, silhouettes, mechanics, and balance must survive original-design review and playtesting before production work begins.

## Provisional tree

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

### Spinner — future work

- **Combat role:** Space-control specialist that discourages opponents from lingering alongside it.
- **Main weapon concept:** A segmented, chassis-integrated impact rotor with a deliberate spin-up and exposure cycle.
- **Strengths:** Sustained local pressure and strong control of tight approaches.
- **Weaknesses:** Commitment, vulnerable downtime, and reduced precision against opponents who disengage cleanly.
- **Intended silhouette:** Low, wide robot with an unmistakable broken-ring rotor surrounding the central body while keeping front and rear readable.
- **Counterplay:** Disengage during pressure, attack during spin-down, and use obstacles to break its preferred orbit.

### Rammer — future work

- **Combat role:** Mobile initiator that creates openings through committed forward impacts.
- **Main weapon concept:** A shock-mounted industrial prow rather than a hammer.
- **Strengths:** Rapid engagement, directional displacement, and control of exposed lanes.
- **Weaknesses:** Predictable approach line, weak sides and rear, and meaningful punishment after a missed charge.
- **Intended silhouette:** Long, low wedge-front chassis with visible dampers and a narrow forward focal point.
- **Counterplay:** Sidestep the approach, turn it into walls or hazards, and attack after it overcommits.

### Pilebreaker — future work

- **Combat role:** Single-impact armor breaker and Level 20 Striker specialization.
- **Main weapon concept:** A vertical industrial pile-driver that stores force for one compact strike.
- **Strengths:** Exceptional payoff against slow or cornered targets.
- **Weaknesses:** Obvious preparation, narrow contact zone, and the longest punish window in its branch.
- **Intended silhouette:** Tall reinforced nose tower with one central downward-driving tool and heavy front bracing.
- **Counterplay:** Move laterally during its preparation and punish the tool's reset cycle.

### Twin Maul — future work

- **Combat role:** Sustained close-range bruiser and Level 20 Striker specialization.
- **Main weapon concept:** Two compact offset mauls that alternate instead of landing one oversized blow.
- **Strengths:** Repeated pressure and better coverage during a close engagement.
- **Weaknesses:** Lower single-hit threat, wider commitment footprint, and difficulty disengaging safely.
- **Intended silhouette:** Broad reinforced shoulders with visibly staggered left and right hammer mechanisms.
- **Counterplay:** Create distance, attack through the timing gap, and avoid remaining between both swing lanes.

### Stormring — future work

- **Combat role:** Perimeter-control specialist and Level 20 Spinner specialization.
- **Main weapon concept:** A segmented guard ring that delivers intermittent powered impact arcs.
- **Strengths:** Strong multi-directional denial and protection while holding contested space.
- **Weaknesses:** Telegraphs its powered arcs and gives up focused pursuit pressure.
- **Intended silhouette:** Wide circular guard broken by three distinctive powered segments around a compact central robot.
- **Counterplay:** Read the powered segment, enter through an inactive gap, or force it away from the space it wants to hold.

### Ripsaw — future work

- **Combat role:** Focused pursuit specialist and Level 20 Spinner specialization.
- **Main weapon concept:** A low forward industrial cutter that must maintain alignment to build pressure.
- **Strengths:** Threatens retreating or pinned targets with sustained frontal contact.
- **Weaknesses:** Narrow threat direction, poor side coverage, and dependence on uninterrupted pursuit.
- **Intended silhouette:** Compact triangular nose framing one low exposed cutting assembly, with the original chassis still recognizable behind it.
- **Counterplay:** Break line, change direction sharply, and attack from the sides while it tries to realign.

### Ironclad — future work

- **Combat role:** Defensive line breaker and Level 20 Rammer specialization.
- **Main weapon concept:** A broad energy-absorbing plow that trades peak speed for reliable frontal control.
- **Strengths:** Stable frontal engagements and strong resistance to displacement while committed.
- **Weaknesses:** Wide turning radius, limited rear defense, and weak chase pressure.
- **Intended silhouette:** Broad armored prow, low roof, and clearly exposed rear machinery.
- **Counterplay:** Refuse the frontal contest, rotate around the wide chassis, and attack its exposed recovery path.

### Liftjack — future work

- **Combat role:** Positional-control specialist and Level 20 Rammer specialization.
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
