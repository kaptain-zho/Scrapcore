# Scrapcore PvP — Long-Term Project Roadmap

**Status:** Living plan, not a locked design  
**Planning assumption:** 1–3 developers working part-time or learning as they build  
**Estimated path to a serious public beta:** roughly 9–15 months  
**Rule:** We advance by proving the game is fun and stable, not merely because a date arrives.

## 1. Current project direction

Players deploy as a basic robot into a continuous arena, destroy graybox objectives or fight other players, earn temporary XP, level up, and spend upgrade points to become stronger during that life. Destruction resets the run and returns the player quickly to a basic bot for another deployment.

**Core loop:**

> Deploy basic bot → destroy objects or fight players → earn XP → level up → upgrade stats → evolve → extract to bank cosmetic-only profile XP or die and lose the run → redeploy

Temporary levels, XP, upgrade points, combat-stat upgrades, and the selected evolution path still reset on death. The current bounded extraction experiment adds a separate permanent `BankedProfileXP` total that can be increased only by a successful ten-second no-damage arena extraction. Banked profile XP is reserved for future cosmetics and unlock presentation; it must never provide combat power.

The original Level 8 evolution framework prototypes **Striker**, **Spinner**, and **Rammer** as enabled, mutually exclusive per-life choices. The progression foundation defines evolution gates at Levels **8, 20, 35, 75, 150, 250, and 300**, and the server route configuration records the approved 37-node graph. Impact Foundry is the first internal Level 20 combat prototype and is reachable from every Level 8 class only through an authorized Studio action. Motion Works, Field Rig, all later nodes, and ordinary-player Level 20 selection remain disabled.

Power progression now ends at Level 300 with a provisional 80-point upgrade schedule. Levels above 300 continue for per-life score only and grant no additional stats, upgrade points, or evolution power. The provisional XP curve preserves the 695-XP Level 8 gate and requires 12,820 cumulative XP for Level 300, targeting roughly 20–45 minutes of active play pending human pacing evidence.

The first same-place workshop-lobby foundation is now the bounded bridge into the arena loop. A new connection starts in a safe, weaponless graybox workshop; the server-owned Main Arena portal begins a canonical Level 1 Scrap Runner run in the existing 380 x 380 arena. Arena deaths still reset and respawn directly in the arena during this prototype. Functional customization, leaderboards, matchmaking, alternate game modes, player-facing returns, and death choices remain deferred.

The extraction prototype adds a deterministic arena-edge banking zone. A living arena player with positive unbanked run XP must remain inside it for ten continuous seconds without authoritative damage. Damage resets the timer. Leaving cancels extraction but preserves unbanked XP for a later retry; dying, disconnecting, or leaving the server before success destroys all unbanked XP. Confirmed banking returns only that player to the protected workshop; failed persistence preserves the active run.

## 2. Design pillars

Every major feature must support at least one of these pillars:

1. **PvP immediately:** Players should reach a meaningful fight quickly.
2. **Readable robot combat:** Players must understand attacks, damage, counters, and why they lost.
3. **Meaningful builds:** Robot parts create different playstyles without creating pay-to-win advantages.
4. **Fast recovery:** Destruction should lead to a quick rebuild and redeploy, not a long punishment.
5. **A living arena:** Bounties, objectives, hazards, and player movement create fights without requiring match resets.
6. **Social status:** The lobby displays impressive robots, rankings, streaks, and achievements.

## 3. Scope rules

- We prototype with blocks before producing polished robot assets.
- We test one excellent combat mode before adding several average modes.
- PvP power is earned through play and skill, not Robux.
- Cosmetics, convenience, and expression are the main monetization categories.
- PC, mobile, and controller support are considered from the first combat prototype.
- All names, robots, arenas, branding, and artwork must be original.
- No expensive advertising campaign begins until retention and stability are promising.

## 4. Roadmap overview

| Phase | Approximate duration | Outcome | Advancement gate |
|---|---:|---|---|
| 0. Foundation | 1–2 weeks | Project organized and testable | Team can build, publish, test, and track work safely |
| 1. Combat laboratory | 3–6 weeks | Graybox PvP prototype | Fighting with basic shapes is fun for repeated rounds |
| 2. Core-loop vertical slice | 5–8 weeks | Lobby-to-arena loop works | New tester can join, deploy, fight, die, and redeploy unaided |
| 3. Technical foundation | 6–10 weeks | Secure, scalable multiplayer base | Stable cross-platform sessions with trustworthy server combat |
| 4. Closed alpha | 4–8 weeks | Small external community tests | Players return voluntarily and key problems are measurable |
| 5. Content and presentation | 6–12 weeks | Recognizable market-ready identity | Game looks coherent and has enough variety for repeat play |
| 6. Public beta | 4–10 weeks | Live economy and larger tests | Retention, performance, fairness, and conversion meet our targets |
| 7. Launch and live operations | Ongoing | Sustainable game updates | Updates improve player and business metrics without harming trust |

Durations may overlap. Art exploration can run while engineering prototypes combat, but polished production should wait until the underlying feature survives testing.

---

## Phase 0 — Foundation

**Goal:** Create a safe, organized development environment before the project becomes complicated.

### Product work

- Choose a temporary codename; keep **Scrapcore PvP** until a better tested name appears.
- Write a one-page game vision and define the intended player fantasy.
- Define the first audience: competitive Roblox players who enjoy short, repeatable PvP encounters.
- Create a decision log for major changes and why they were made.
- Build a prioritized backlog using **Now / Next / Later / Rejected**.

### Technical work

- Create the Roblox group and group-owned experience.
- Set up source control and a repeatable Studio-to-code workflow.
- Separate development, testing, and production places.
- Establish code conventions, folder structure, module ownership, and backup procedure.
- Create a basic test map and automated checks for important shared modules.

### Business and safety work

- Reserve original names and social handles only after basic trademark and Roblox searches.
- Document which assets are original, commissioned, or licensed.
- Establish a budget ceiling for art, audio, plugins, contractors, and promotion.
- Define moderation, exploit-reporting, and community rules before inviting the public.

### Gate

Do not begin full production until the project can be opened, tested, published privately, rolled back, and handed to another contributor without confusion.

---

## Phase 1 — Combat Laboratory

**Goal:** Prove that controlling and fighting robots is fun before building the lobby, economy, or polished map.

### Build only the essentials

- One flat graybox arena.
- Two placeholder robot bodies with identical base stats.
- Responsive movement, turning, acceleration, and braking.
- Camera behavior for mouse, touch, and controller.
- One melee weapon and one ranged or utility weapon.
- Health, damage, knockback, elimination, and instant reset.
- Clear hit, miss, damage, cooldown, and destruction feedback.
- A graybox per-life XP loop with breakable arena objects and five capped stat upgrades.
- A rapid death reset that removes all temporary levels and combat upgrades before redeployment.
- Simple two-player and four-player tests.

**Provisional Milestone 3.1 arena target:** expand the graybox progression space from 120 x 120 to approximately 380 x 380 studs (about ten times the playable area). Preserve 140 runtime breakables: 80 ScrapPiles, 40 ReinforcedCrates, and 20 PowerCores. ScrapPiles are split into 60 broadly available Common piles, 16 medium-risk Rare piles, and 4 scarce interior Epic piles. Treat these dimensions, counts, rarity rewards, and placements as playtest tuning, not a final production-map commitment.

Prototype ScrapPile tuning is Common at 25 health, 10 XP, and an 8-second respawn; Rare at 75 health, 30 XP, and a 15-second respawn; and Epic at 150 health, 60 XP, and a 30-second respawn. All damage, contribution accounting, XP distribution, and respawning remain server-owned.

The desktop prototype keeps the smooth angled top-down camera as its default and permits limited right-mouse orbit plus mouse-wheel zoom. Movement remains camera-relative and mouse aiming remains world-correct after camera rotation. Player robots pass through one another and through breakables using server-configured collision groups, while arena floors, walls, and important world obstacles remain solid.

Temporary stat upgrades retain 30-rank resolution and the accepted normalized exponential curve with a provisional strength of 1.5. Levels 1–30 still grant one point each; 50 explicit later grants produce exactly 80 total points by Level 300. Levels above 300 are score-only and grant no power. The five categories remain Speed, Attack Rate, Damage, Health, and Health Regen, with unchanged Rank 30 endpoints of 31.2 maximum speed, a 0.630-second hammer cooldown, 35 hammer damage, 150 maximum health, or 3 health per second after five uninterrupted seconds without damage. Spinner damage and Attack Rate timing use the same shared factor. Knockback remains fixed at its safe server-owned base value. XP is never spent, and death resets all ranks with the rest of the run.

The Level 8 framework, Striker, Spinner, and Rammer remain the public class experiment. Spinner sustains its server-authoritative flywheel only while LMB remains held. Rammer holds LMB to build a server-measured charge, remains ready at full charge until release, then receives one bounded forward dash whose damage depends on legal charge and observed closing speed. RMB remains camera orbit, and the evolution cards plus top-right run HUD communicate each specialized control. Validated hold leases safely end Spinner or Rammer preparation if input or focus state is lost.

The internal Impact Foundry prototype proves generic Level 20 route commitment and complete kit replacement without changing Level 8 tuning. LMB begins one server-timed forge strike with reduced windup movement, an automatic bounded frontal impact, and normal punishable recovery. Only frontal horizontal displacement is partially resisted during the windup; damage, side and rear displacement, vertical motion, and wall collision remain normal. Ordinary players see Level 20 routes as under construction. Motion Works and Field Rig must be implemented and all three families must pass multiplayer, security, farming, and balance gates before public Level 20 selection can be considered.

Studio-only developer tools are approved as testing infrastructure for rapidly exercising the existing per-life progression and class lifecycle. They are not player progression, balance content, or a production feature. Authorization and all mutations remain server-owned; the outside-Studio switch stays disabled and its server-only UserId allowlist stays empty by default. Tool-assisted results must still be followed by normal-path and multiplayer acceptance tests.

A confirmed player elimination now transfers the victim's exact server-owned unbanked run XP to the eliminator once instead of granting a fixed reward. Authoritative death snapshots and one-time humanoid reward markers prevent duplicate Hammer, Spinner, Rammer, or stale-hit claims. Environmental death and disconnect transfer nothing and destroy the unfinished run. Assist ownership, repeated-victim farming penalties, coordinated feed prevention, and level-difference scaling still require later multiplayer tuning.

### Questions to answer

- Is movement enjoyable by itself?
- Does attacking require timing, aim, spacing, or prediction?
- Can players understand why an attack connected?
- Do melee and ranged combat both have counterplay?
- Does knockback improve fights or make them random?
- What is the ideal time-to-eliminate?
- Does mobile aim assistance help without taking over combat?
- Is earning XP from objects and PvP readable, paced well, and worth taking arena risks for?
- Do temporary stat choices create a satisfying run without making fresh bots irrelevant?
- Does losing all temporary run power on death encourage immediate redeployment rather than quitting?

### Gate

Invite at least several people who did not build the prototype. Advance only when they repeatedly request another fight and can explain at least one skill they are trying to improve.

### Explicitly excluded

No shop, season pass, giant map, detailed garage, ranked mode, complicated crafting, or large asset pack.

---

## Phase 2 — Core-Loop Vertical Slice

**Goal:** Build the smallest complete version of the experience.

### Player flow

1. Join in the safe workshop lobby as a weaponless Scrap Runner.
2. Use the server-validated Main Arena portal to begin a fresh run.
3. Deploy a basic bot into the continuous arena.
4. Destroy objects or fight players to earn temporary XP.
5. Level up and spend points on temporary combat-stat upgrades.
6. Reach the implemented class-choice gate at Level 8; continue through the data-defined Levels 20, 35, 75, 150, 250, and 300 as later evolution robots are separately proven.
7. Continue taking greater arena risks as the bot becomes stronger.
8. Optionally hold the arena-edge extraction zone undamaged for ten seconds to permanently bank the current run's XP and return to the workshop.
9. If destroyed or disconnected first, lose all unbanked run XP and reset all temporary levels, points, upgrades, and evolution state.
10. Respawn quickly in the arena after destruction; a confirmed extraction is the current server-authorized path back to the lobby.

### Systems

- Continuous arena server with 8–12 players for initial tests.
- A basic bot whose per-life upgrades create the first build decisions.
- Four to six temporary upgrades.
- Basic bounty and live leaderboard.
- Spawn protection and anti-camping measures.
- First-pass account data for settings and a small number of permanent unlocks.
- Schema-versioned, receipt-idempotent banked profile XP for future cosmetic-only unlocks. The architecture passed an isolated private published DataStore validation on August 24, 2026; ordinary development and the restored private build still use the safe persistence-disabled configuration, so production persistence is validated but not launched.
- Basic onboarding, settings, reporting, and accessibility controls.
- Event logging for joins, deployments, fights, eliminations, deaths, upgrades, extractions, and exits.

### Key experiments

- Whether the ten-second no-damage extraction improves run tension and redeployment intent without encouraging avoidance or spawn-edge camping.
- Manual deployment zone selection versus automatic safe spawn.
- Losing all, some, or none of carried scrap on destruction.
- Level advantages versus normalized combat power.
- One continuous arena versus short server-wide seasons.

### Gate

A first-time tester should understand the loop without developer instructions, reach PvP quickly, and redeploy after destruction without becoming confused or frustrated.

---

## Phase 3 — Technical Foundation

**Goal:** Replace fragile prototype shortcuts with systems that can support a real audience.

### Multiplayer and security

- Make damage, rewards, inventory, purchases, and progression server-authoritative.
- Validate remote requests, movement limits, attack timing, and loadouts.
- Add rate limits, exploit logging, and suspicious-behavior review tools.
- Test lag compensation and high-latency combat behavior.
- Create clean server shutdown, reconnect, and data-recovery behavior.

### Performance

- Establish budgets for part count, physics, particles, textures, network traffic, and memory.
- Pool frequently created effects and projectiles.
- Test low-end mobile devices early.
- Use simplified collision and server logic where visual complexity adds no gameplay value.
- Profile with realistic player counts and combat effects, not an empty map.

### Game architecture

- Modularize combat, robots, weapons, upgrades, UI, data, analytics, and matchmaking.
- Use configuration data for balance so numbers can change without rewriting systems.
- Create test commands and a private admin panel for development only.
- Add versioned player-data migrations and recovery procedures.
- Prepare localization-safe UI layouts and text handling.

### Gate

The game survives repeated multiplayer tests without data loss, common exploits, severe frame-rate drops, or combat disagreements between client and server.

---

## Phase 4 — Closed Alpha

**Goal:** Learn how real players behave when developers are not guiding them.

### Alpha content

- One complete arena with safe outskirts, contested middle zones, and a high-risk center.
- Four to six builds assembled from a limited part set.
- Eight to twelve meaningful upgrade choices.
- Daily and weekly test missions.
- Friend party support if technically practical.
- Private test servers and basic moderation tools.
- Simple post-life results showing damage, eliminations, survival, scrap, and cause of destruction.

### Testing cadence

- Run one scheduled test each week.
- Observe silently before asking questions.
- Collect a short survey after the session.
- Review analytics and player clips together.
- Fix the three largest problems before adding more content.

### Provisional metrics

These are targets to refine, not guarantees:

- Median time from joining to first deployment: under 2 minutes.
- Redeployment after first destruction: above 70%.
- Meaningful PvP encounter within 90 seconds of deployment.
- Crash-free and data-safe sessions: as close to 100% as practical.
- Increasing percentage of testers returning for the following weekly test.

### Gate

Advance when players return without being personally persuaded, several builds remain viable, the most common deaths feel understandable, and the team can identify problems through data rather than guesswork.

---

## Phase 5 — Content, Identity, and Ethical Monetization

**Goal:** Turn the proven loop into a recognizable product without weakening competitive trust.

### Art and audio

- Establish an original industrial-sport visual style.
- Create modular chassis, movement bases, weapons, armor, and cosmetic attachment standards.
- Produce one polished representative robot before scaling the asset pipeline.
- Add readable silhouettes and team/enemy color rules.
- Build destruction effects, weapon sounds, lobby ambience, UI audio, and music layers.
- Optimize every asset against established device budgets.

### Content target for beta

- One excellent continuous PvP arena.
- Six to eight viable combat builds or class directions.
- Twelve to twenty compatible combat parts/upgrades.
- A focused set of cosmetics with multiple color and material variations.
- Bounties, rotating objectives, and two or three arena events.
- Social lobby displays, inspection, leaderboards, and spectating.

### Monetization order

1. Cosmetic paint/material packs.
2. Robot skins and visual part variants.
3. Elimination, deployment, trail, and victory effects.
4. Extra cosmetic/loadout organization slots.
5. Fair season pass after the content pipeline is reliable.
6. Optional rewarded ad placements only when they fit naturally and do not interrupt PvP.

Never sell exclusive statistical power, unavoidable paid revives, immunity from loss, or better ranked matchmaking. Every purchase flow must be clear, age-appropriate, correctly granted, and recoverable.

### Gate

The game has a distinctive thumbnail-ready identity, runs well on target devices, contains enough build variety for repeat sessions, and its store feels optional rather than required.

---

## Phase 6 — Public Beta

**Goal:** Validate the game with a wider audience while spending cautiously.

### Release approach

- Soft-launch to a controlled audience.
- Publish accurate icons, thumbnails, trailer footage, description, and update notes.
- Use small promotion experiments; scale only when acquired players stay and return.
- Schedule regular test events and communicate patches clearly.
- Keep a public known-issues list and an easy feedback route.

### Measure

- New-player funnel: join → lobby understanding → deploy → first fight → first return.
- Session length and number of deployments per session.
- Day 1, Day 7, and Day 30 retention.
- Win rates, pick rates, damage, and deaths by build and device.
- Spawn deaths, quitting after death, and extraction behavior.
- Purchase conversion, revenue per active player, refunds/issues, and shop engagement.
- Server performance, crash rate, data errors, exploit reports, and moderation load.

### Gate

Do not call the game launched until new players understand it, combat is fair across devices, retention is moving in the right direction, critical technical failures are rare, and monetization does not damage play behavior.

---

## Phase 7 — Launch and Live Operations

**Goal:** Operate a sustainable PvP game rather than treating launch as the finish line.

### Update rhythm

- Weekly: bug fixes, balance changes, communication, and small challenges.
- Every 3–5 weeks: meaningful content or arena event.
- Every 8–12 weeks: a season only after the team can reliably support it.
- Quarterly: reassess the roadmap, technical debt, player sentiment, and business health.

### Possible post-launch additions

Add these only when the continuous arena is healthy:

- Ranked 3v3.
- Duel pits and tournament brackets.
- Clan or crew competition.
- More arenas with different combat rules.
- Player-created cosmetic robot displays.
- Replay, spectator, and creator tools.
- Limited-time modes and collaborative boss threats inside the PvP world.

## 5. Minimum viable public game

Our first public-quality version should contain:

- One workshop lobby.
- One continuous PvP arena.
- Clear Deploy flow and rapid redeployment.
- Four to six balanced robot builds.
- Temporary per-life upgrades.
- Bounties and a live leaderboard.
- One tested answer for banking or extraction.
- Persistent cosmetics and basic mastery.
- Cross-platform controls and settings.
- Analytics, moderation, reporting, data protection, and anti-exploit foundations.
- A small fair cosmetic shop.

Anything beyond this must justify the delay it causes.

## 6. First 30 days

### Week 1 — Organize and choose the combat hypothesis

- Establish group ownership, source control, test places, task board, and decision log.
- Write the one-page vision.
- Choose the first movement model and camera direction.
- Choose only two weapon prototypes.
- Build an empty graybox arena.

### Week 2 — Make fighting possible

- Implement movement, turning, camera, health, server-validated damage, and reset.
- Add one melee weapon with strong feedback.
- Test repeatedly on keyboard, controller, and touch.

### Week 3 — Add contrast and conduct first tests

- Add a second weapon with a different range and counterplay pattern.
- Add knockback, cooldown feedback, destruction feedback, and simple stats.
- Run the first outside playtest with placeholder visuals.

### Week 4 — Decide, refine, or restart

- Review observation notes and basic combat data.
- Keep only mechanics that created understandable, repeatable fun.
- Adjust movement, camera, time-to-eliminate, and weapon behavior.
- Decide whether the combat foundation is good enough for the lobby-to-arena slice.

**The correct first milestone is not “finish the lobby.” It is “two people voluntarily want another robot fight.”**

## 7. Team operating system

### Weekly rhythm

- **Start of week:** choose one measurable player problem.
- **During week:** build the smallest test that can answer it.
- **End of week:** playtest, record evidence, and update the decision log.
- **After test:** fix, keep, change, or remove—then reprioritize.

### Definition of done

A feature is done only when it:

- Works in multiplayer.
- Is validated by the server where security matters.
- Works with keyboard, controller, and touch.
- Has understandable feedback and error states.
- Meets performance budgets.
- Produces the analytics needed to judge it.
- Has been tested by someone other than its creator.

## 8. Major risks and responses

| Risk | Early warning | Response |
|---|---|---|
| Combat feels random | Players cannot explain losses | Improve telegraphs, collision, timing, and post-death information |
| Progression overwhelms skill | High-level players become untouchable | Cap advantages, add tradeoffs, or normalize combat power |
| Arena feels empty | Long periods without encounters | Reduce size, improve heat map/spawns, add moving objectives |
| Spawn camping | Players die soon after deploying | Protected zones, safer spawn selection, threat-aware spawning |
| Mobile disadvantage | Large performance or win-rate gap | Tune UI, aim support, camera, effects, and control options |
| Physics instability | Desync, flinging, inconsistent hits | Simplify collision, use controlled forces, keep authority on server |
| Scope explosion | Many half-finished modes and parts | Protect the MVP and enforce advancement gates |
| Pay-to-win perception | Purchases correlate with combat power | Monetize expression and convenience, publish clear rules |
| Weak retention | Players try once but do not return | Repair core combat/onboarding before buying more traffic |
| Asset/IP trouble | Designs resemble known combat robots | Maintain original style guides and asset provenance records |

## 9. Decisions intentionally left open

We should test these instead of deciding them permanently now:

- Exact extraction placement, duration, interruption feedback, and whether later variants should offer additional risk; the current prototype uses one manual ten-second no-damage zone.
- Top-down, angled, or close third-person camera.
- Freeform modular construction versus curated chassis/loadouts.
- Player count and arena size.
- Whether any temporary power should ever survive destruction; the current prototype resets all of it.
- Whether servers run forever or have periodic arena resets.
- Solo-only launch versus teams.
- Ranked mode timing.
- Exact class list and number of weapons.
- Final name, art direction, and monetization prices.

## 10. Immediate next decision

The extraction and profile-XP validation gate is complete. Two-client testing established readable portal and countdown behavior, authoritative damage resets, cancellation and retry behavior, exact one-time banking, isolated player sessions, safe lobby return, canonical redeployment, and clean consoles. A controlled private published test then proved exact live persistence across separate servers: 100 XP survived the first rejoin, a second 50 XP increased the bank to exactly 150, and later death and disconnect tests did not bank either unfinished 100-XP run.

The test used an isolated live-test namespace, left production data untouched, and ended by restoring the published private build to `EnableLiveDataStore = false`. Production persistence is **validated but not launched**. Any production rollout still requires a separate explicit approval, reviewed namespace and configuration, monitoring, and rollback plan.

The Level 300 progression foundation is documented in `docs/LEVEL300_PROGRESSION_FOUNDATION.md`: score-only levels beyond 300, seven evolution gates, an 80-point schedule, a faster provisional XP curve, and exact one-time elimination transfer of unbanked run XP. The current bounded class milestone adds the generic server-owned route foundation and the Studio-only Impact Foundry prototype documented in `docs/IMPACT_FOUNDRY_PROTOTYPE.md`. Level 20 remains publicly disabled, and no Motion Works, Field Rig, Level 35 robot, or later combat kit is implemented. Functional skins, live leaderboards, matchmaking, extra modes, death choices, paid revives, ads, spending systems, monetization, and production persistence launch remain separate future milestones.

---

## Roadmap principle

The lobby, future classes, art, and store can make the game attractive, but the project lives or dies on one question:

> Is controlling, fighting, and growing a robot for one life fun enough that players immediately want to redeploy after the reset?

Every phase exists to answer that question more reliably, at a larger scale, without losing fairness or trust.
