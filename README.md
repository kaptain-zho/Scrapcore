# Scrapcore

**Build a battle robot. Enter the arena. Grow stronger for one life. Decide when to risk everything—or extract safely.**

Scrapcore is an original top-down robot-combat game being built on Roblox. It combines quick player-versus-player fights with open-arena progression: destroy scrap, battle other robots, choose upgrades, and evolve your machine during each run.

> **Project status:** Early playable prototype. The core combat loop is being tested, but Scrapcore is not yet a finished public game.

## How a run works

1. **Start in the workshop** as a basic, weaponless Scrap Runner.
2. **Deploy into the arena** through the Main Arena portal.
3. **Destroy scrap or fight players** to earn temporary run XP.
4. **Level up and choose upgrades** for speed, attack rate, damage, health, and health regeneration.
5. **Evolve at Level 8** into one of three distinct robot classes.
6. **Keep fighting or extract.** A successful ten-second extraction banks your run XP for future cosmetic rewards.
7. **If your robot is destroyed, the run resets** and you redeploy as a basic bot.

## Level 8 robot classes

| Class | Play style |
|---|---|
| **Striker** | Heavy hammer hits, strong shove, and deliberate recovery between swings. |
| **Spinner** | Sustained close-range pressure against several nearby targets, with low knockback. |
| **Rammer** | Hold and release a frontal charge for a powerful, alignment-dependent impact. |

These classes are mutually exclusive for each life. Death resets the selected class along with temporary levels and upgrades.

## What works today

- A safe industrial workshop lobby and server-validated arena deployment.
- Smooth top-down robot movement, mouse aiming, camera orbit, and zoom.
- A 380 × 380 graybox arena with 140 server-controlled breakable objects.
- Server-authoritative hammer, Spinner, and Rammer combat.
- Temporary per-life XP, levels, stat upgrades, and class evolution.
- Extraction that banks the exact run XP once and returns the player to the lobby.
- A permanent profile-XP system validated against Roblox's live DataStore service using an isolated test namespace.
- Multiplayer lifecycle, respawning, collision, grounding, latency, and exploit-boundary testing.

## Fair-play promise

Scrapcore is designed around competitive trust:

- The server decides damage, cooldowns, rewards, progression, and persistent data.
- Permanent banked XP is reserved for future cosmetics and unlock presentation—not combat power.
- Paid statistical advantages, paid immunity from loss, and preferential matchmaking are outside the design.
- Robot designs, names, environments, and visual assets must be original or properly licensed.

## What is still in development

- Level 20 and later evolution families.
- A polished arena, effects, sound, onboarding, accessibility settings, and mobile refinement.
- Public production persistence and cosmetic rewards.
- Bounties, live leaderboards, moderation, analytics, and larger-player-count testing.
- Final balancing based on broader human playtests.

The **Impact Foundry** is an internal Level 20 prototype. Ordinary Level 20 access remains disabled until all three planned Level 20 families are implemented and validated.

## Why the project is public

This repository shows Scrapcore's development process, design decisions, and prototype architecture. A public source repository does **not** mean the Roblox experience is publicly launched or production-ready.

## Learn more

- [Long-term project roadmap](Scrapcore_PvP_Project_Roadmap.md)
- [Master evolution graph](docs/EVOLUTION_TREE_MASTER_PLAN.md)
- [Class evolution design](docs/CLASS_EVOLUTION_DESIGN.md)
- [Workshop lobby foundation](docs/LOBBY_FOUNDATION.md)
- [Extraction and profile XP](docs/EXTRACTION_AND_PROFILE_XP.md)
- [Asset standards](docs/ASSET_STANDARDS.md)
- [Contributor guide](AGENTS.md)

## Development notes

Scrapcore is built with Roblox Studio, typed Luau, Git, and Script Sync. Gameplay changes are tested through Roblox Studio with multiplayer, security, latency, console, and lifecycle checks appropriate to the feature.

No license has been granted for reuse of the code or original project assets at this time.
