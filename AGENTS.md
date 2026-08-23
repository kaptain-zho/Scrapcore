# Scrapcore PvP Contributor Guide

## Project intent

Scrapcore PvP is a Roblox robot-combat experience currently in its foundation phase. Treat the roadmap as a living plan and prove ideas through playtests before expanding scope. Do not begin a later phase merely because earlier code exists; satisfy the phase's advancement gate first.

The core loop currently being proven is:

> Deploy basic bot -> destroy objects or fight players -> earn XP -> level up -> upgrade stats -> evolve later -> die and reset -> redeploy

The immediate product question is whether responsive robot combat plus temporary per-life growth makes players want to redeploy. Prototype with simple geometry and narrow experiments before investing in permanent progression, economy, classes, or polished assets.

## Design pillars

Every major feature must support at least one pillar and must not undermine the others:

1. **PvP immediately:** get players to a meaningful fight quickly.
2. **Readable robot combat:** clearly communicate attacks, damage, counters, cooldowns, and causes of defeat.
3. **Meaningful builds:** parts and loadouts create distinct playstyles without paid statistical power.
4. **Fast recovery:** destruction leads quickly to rebuilding and redeployment, not prolonged punishment.
5. **A living arena:** objectives, hazards, bounties, and player movement generate encounters without requiring match resets.
6. **Social status:** the lobby makes robots, achievements, rankings, and streaks visible.

Preserve competitive trust. Monetization may support cosmetics, expression, and appropriate convenience, but never exclusive combat power, paid immunity from loss, or preferential matchmaking.

## Coding standards

- Use Luau and enable strict type checking for new modules with `--!strict` unless a documented integration constraint prevents it.
- Organize code by execution boundary: server-only code under the server source tree, client-only code under the client source tree, and shared modules under the shared source tree. Never place secrets or authoritative logic in replicated/shared code.
- Keep modules focused, with explicit dependencies and small public APIs. Prefer composition and configuration data over deep inheritance or duplicated balance constants.
- Name modules, types, and exported members in PascalCase; name local variables and functions in camelCase; use UPPER_SNAKE_CASE for true constants.
- Use descriptive names. Avoid hidden global state, magic numbers, and dependencies reached through broad descendant searches when an explicit reference can be supplied.
- Disconnect event connections and clean up instances, tasks, and resources deterministically. Avoid unbounded loops, per-frame allocations, and unnecessary remote or physics traffic.
- Handle expected failures explicitly. Log enough context to diagnose failures without exposing sensitive player data or flooding production output.
- Keep balance values in centralized configuration so experiments do not require rewriting system logic.
- Design UI and controls for keyboard/mouse, controller, and touch from the first prototype. Keep player-facing text localization-safe.
- Add focused automated tests for important shared and server modules when a test harness exists. A feature is not done until it works in multiplayer and has been tested by someone other than its author.
- Make small, reviewable commits. Update documentation when behavior, architecture, setup, or a major product decision changes.

## Security and data rules

- The server is authoritative for damage, health, cooldowns, rewards, inventory, loadouts, purchases, progression, matchmaking, and persistent data.
- Treat every client value and remote request as hostile input. Validate type, shape, range, permissions, ownership, state transitions, distance, timing, and rate before acting.
- Rate-limit remotes and expensive server actions. Reject invalid requests safely and record actionable exploit signals without trusting client-provided explanations.
- Never let a client choose reward amounts, damage results, owned items, purchase outcomes, or another player's target state.
- Keep DataStore operations server-side. Use versioned schemas, protected calls, bounded retries/backoff, session-safe writes, migration paths, and recovery behavior. Never overwrite good persistent data with incomplete defaults after a load failure.
- Grant developer products and other purchases idempotently from verified Roblox receipts. Do not award from client purchase prompts or client callbacks.
- Do not commit credentials, private keys, tokens, personal data, production identifiers that should remain private, or unlicensed assets.
- Collect only necessary analytics and moderation data. Avoid logging authentication material or sensitive player information.
- Prefer controlled server-side movement and hit validation; test latency behavior and avoid trusting client physics for competitive outcomes.

## Required workflow and Roblox Studio MCP testing

Before changing code, inspect the relevant source, nearby modules, project mappings, and current Studio hierarchy. Preserve unrelated work and do not delete or rename content without explicit scope and verification.

All behavior changes must be tested through the Roblox Studio MCP connection:

1. List connected Studio instances and select the intended place by name. Do not assume an instance ID remains stable.
2. Confirm Studio's current DataModel state and inspect the affected instances/scripts before editing.
3. Make the smallest scoped change. Do not modify unrelated instances or scripts.
4. Start a playtest through Studio MCP. Exercise the changed behavior in the correct server/client context and, when relevant, test with multiple players.
5. Inspect Studio console output for errors, warnings, and expected evidence. A print statement alone is not proof when observable gameplay or state can be checked.
6. Stop the playtest even when verification fails.
7. Report what was tested, the observed result, relevant console errors, and anything not verified.

For combat, networking, persistence, purchases, or cross-platform input, include adversarial and boundary cases appropriate to the risk. Do not publish, enable monetization, touch production data, or alter live places without explicit authorization.

## Task completion and automatic review

- When an implementation, testing, documentation, or asset task is completely finished, the final implementation report must end with `[SCRAPCORE_TASK_COMPLETE]` as its final non-whitespace line.
- Automatic post-task review responses must never include that marker.
- Do not emit the marker when work is blocked, awaiting approval, awaiting human testing, or incomplete.

## Scope discipline

- Follow the roadmap gates and protect the minimum viable public game.
- Build the smallest test that answers the current player question.
- Prefer one strong combat mode over several incomplete modes.
- Keep all robots, arenas, branding, artwork, audio, and names original or properly licensed, and preserve asset provenance.
- Do not add shops, passes, ranked modes, large content packs, elaborate progression, or production art before the relevant roadmap phase and evidence justify them.
- Record major decisions and why they changed. Move rejected ideas out of active scope rather than leaving half-built systems in production paths.

## Definition of done

A gameplay feature is complete only when it works in multiplayer; security-sensitive behavior is server-validated; keyboard/mouse, controller, and touch behavior is considered; feedback and error states are understandable; performance budgets are respected; useful evaluation signals exist; and Roblox Studio MCP testing has produced recorded evidence. If any condition is intentionally deferred, state it clearly in the handoff.
