# Scrapcore PvP — Long-Term Project Roadmap

**Status:** Living plan, not a locked design  
**Planning assumption:** 1–3 developers working part-time or learning as they build  
**Estimated path to a serious public beta:** roughly 9–15 months  
**Rule:** We advance by proving the game is fun and stable, not merely because a date arrives.

## 1. Current project direction

Players deploy as a basic robot into a continuous arena, destroy graybox objectives or fight other players, earn temporary XP, level up, and spend upgrade points to become stronger during that life. Destruction resets the run and returns the player quickly to a basic bot for another deployment.

**Core loop:**

> Deploy basic bot → destroy objects or fight players → earn XP → level up → upgrade stats → evolve later → die and reset → redeploy

This per-life arena-evolution loop is the current hypothesis to prove before extraction or permanent progression resumes. Temporary levels, XP, upgrade points, combat-stat upgrades, and the selected evolution path reset on death; they are not account progression.

The original Level 8 evolution framework now prototypes **Striker** and **Spinner** as enabled, mutually exclusive per-life choices, while **Rammer** remains a disabled preview. Level 20 specializations remain future design targets. The current test must establish that the burst-and-shove Striker and sustained-contact Spinner create readable, original counterplay without weakening server authority.

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

Temporary stat upgrades use 30-rank resolution with one point granted at every run level, including Level 1. A Level 30 run therefore earns 30 total points to distribute freely across Speed, Attack Rate, Damage, Health, and Health Regen. Rank 30 reaches 31.2 maximum speed, a 0.630-second hammer cooldown, 35 hammer damage, 150 maximum health, or 3 health per second after five uninterrupted seconds without damage. Knockback remains fixed at its safe server-owned base value. These caps preserve the prior safe endpoints while Health Regen replaces upgradeable knockback; XP is never spent, and death resets all ranks with the rest of the run.

The Level 8 framework, Striker, and Spinner are the current narrow class experiment. Spinner sustains its server-authoritative flywheel only while primary attack remains held; a validated hold lease safely ends the attack if release or focus state is lost. Rammer, all Level 20 specializations, alternate movement systems, and additional class weapons remain paused until both implemented choices survive multiplayer selection, combat-readability, authority, and death-reset playtesting.

Player-elimination XP is provisional. Assist rewards, repeated-victim farming penalties, and level-difference reward scaling require later multiplayer tuning and are not part of this prototype.

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

1. Deploy a basic bot into the continuous arena.
2. Destroy objects or fight players to earn temporary XP.
3. Level up and spend points on temporary combat-stat upgrades.
4. Reach a planned class-choice gate at Level 8 and, later, Level 20 once classes exist.
5. Continue taking greater arena risks as the bot becomes stronger.
6. Get destroyed and reset all temporary levels, XP, points, and upgrades.
7. Redeploy quickly as a basic bot and begin another run.

### Systems

- Continuous arena server with 8–12 players for initial tests.
- A basic bot whose per-life upgrades create the first build decisions.
- Four to six temporary upgrades.
- Basic bounty and live leaderboard.
- Spawn protection and anti-camping measures.
- First-pass account data for settings and a small number of permanent unlocks.
- Basic onboarding, settings, reporting, and accessibility controls.
- Event logging for joins, deployments, fights, eliminations, deaths, upgrades, extractions, and exits.

### Key experiments

- Whether extraction or banking belongs in the loop after per-life arena evolution is proven.
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

- Extraction, automatic banking, or a hybrid.
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

Compare the original Level 8 Striker and Spinner evolutions within the existing per-life arena loop. The prototype should answer whether players understand the exclusive choice, recognize Striker's heavier burst and shove versus Spinner's sustained close-contact pressure, find counterplay to both, accept losing the path on death, and want to earn another evolution.

Rammer and the provisional Level 20 branches documented in `docs/CLASS_EVOLUTION_DESIGN.md` remain disabled future work. Do not implement another branch until fresh multiplayer testing validates Spinner-versus-Striker readability, server authority, reset behavior, and sustained-contact combat.

---

## Roadmap principle

The lobby, future classes, art, and store can make the game attractive, but the project lives or dies on one question:

> Is controlling, fighting, and growing a robot for one life fun enough that players immediately want to redeploy after the reset?

Every phase exists to answer that question more reliably, at a larger scale, without losing fairness or trust.
