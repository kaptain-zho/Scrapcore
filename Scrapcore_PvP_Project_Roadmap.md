# Scrapcore PvP — Long-Term Project Roadmap

**Status:** Living plan, not a locked design  
**Planning assumption:** 1–3 developers working part-time or learning as they build  
**Estimated path to a serious public beta:** roughly 9–15 months  
**Rule:** We advance by proving the game is fun and stable, not merely because a date arrives.

## 1. Current project direction

Players join a social robot workshop lobby, build or select a combat robot, and choose when to deploy into a continuous open PvP arena. In the arena they fight, collect scrap, gain temporary upgrades, pursue bounties, and eventually return to the lobby through extraction or destruction.

**Core loop:**

> Lobby → choose robot → deploy → fight and upgrade → extract or get destroyed → improve loadout → deploy again

This direction is our starting hypothesis. It is not a permanent promise. Classes, extraction, map size, player count, progression, and game modes should change whenever testing shows a better answer.

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
- Simple two-player and four-player tests.

### Questions to answer

- Is movement enjoyable by itself?
- Does attacking require timing, aim, spacing, or prediction?
- Can players understand why an attack connected?
- Do melee and ranged combat both have counterplay?
- Does knockback improve fights or make them random?
- What is the ideal time-to-eliminate?
- Does mobile aim assistance help without taking over combat?

### Gate

Invite at least several people who did not build the prototype. Advance only when they repeatedly request another fight and can explain at least one skill they are trying to improve.

### Explicitly excluded

No shop, season pass, giant map, detailed garage, ranked mode, complicated crafting, or large asset pack.

---

## Phase 2 — Core-Loop Vertical Slice

**Goal:** Build the smallest complete version of the experience.

### Player flow

1. Spawn in a simple workshop lobby.
2. See the arena, current leaders, and a clear **Deploy** button.
3. Select one of three prototype loadouts.
4. Choose or receive a safe deployment zone.
5. Enter the continuous arena.
6. Fight players and obtain scrap/XP.
7. Select temporary combat upgrades during that life.
8. Get destroyed or use a prototype extraction point.
9. Return to the lobby and redeploy quickly.

### Systems

- Continuous arena server with 8–12 players for initial tests.
- Three distinct prototype builds, each with obvious strengths and weaknesses.
- Four to six temporary upgrades.
- Basic bounty and live leaderboard.
- Spawn protection and anti-camping measures.
- First-pass account data for settings and a small number of permanent unlocks.
- Basic onboarding, settings, reporting, and accessibility controls.
- Event logging for joins, deployments, fights, eliminations, deaths, upgrades, extractions, and exits.

### Key experiments

- Extraction versus automatic banking.
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
- How much temporary power survives destruction.
- Whether servers run forever or have periodic arena resets.
- Solo-only launch versus teams.
- Ranked mode timing.
- Exact class list and number of weapons.
- Final name, art direction, and monetization prices.

## 10. Immediate next decision

Before building, choose the first combat camera and movement prototype:

1. **Top-down twin-stick:** closest to the `diep.io` inspiration and easiest to read.
2. **Angled third-person:** more physical and dramatic, but harder for mobile combat clarity.
3. **Hybrid:** top-down exploration with a closer combat camera, offering spectacle at the cost of complexity.

The recommended starting point is **top-down twin-stick** because it lets us test the PvP loop quickly. The camera can change after the combat laboratory produces evidence.

---

## Roadmap principle

The lobby, progression, art, and store can make the game attractive, but the project lives or dies on one question:

> Is controlling a robot and fighting another player fun enough that both players immediately want to deploy again?

Every phase exists to answer that question more reliably, at a larger scale, without losing fairness or trust.
