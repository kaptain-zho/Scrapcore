# Claude handoff — Scrapcore

**Prepared:** September 4, 2026

**Repository:** `C:\roblox\ScapCore`

**Remote:** `https://github.com/kaptain-zho/Scrapcore.git`

**Branch:** `main`, tracking `origin/main`
**Committed baseline:** `b951c16b74dc04dd8dc7f29c2dc0cacfd2804b33` (`docs: add public project overview`)

## Read this first

This is an in-place handoff of a working Roblox project with important uncommitted work. Do not begin by making the tree clean. Do not clone over this directory. Do not reset to the GitHub version: GitHub contains only the committed baseline and does not contain the current Motion Works work.

Read, in order:

1. `AGENTS.md` — permanent engineering, security, testing, and scope rules.
2. `Scrapcore_PvP_Project_Roadmap.md` — evolving scope and milestone order.
3. `docs/MOTION_WORKS_PROTOTYPE.md` — current prototype design and accumulated evidence.
4. `docs/MOTION_WORKS_DIRECTIONAL_VALIDATION.md` — exact latest test results, discarded trials, blocker, and next tests.
5. The complete working-tree diff and every new Motion Works source file before editing.

Verified facts must be kept separate from modeled values, source inspection, assumptions, and untested claims.

## Current task state

The uncommitted milestone is the Studio-only Level 20 **Motion Works** prototype. Its intended identity is an energy-limited forward drive with narrow movement-dependent contact damage. It replaces the selected Level 8 kit for the life. Ordinary players cannot select Level 20 routes.

Directional testing found and repaired substantive problems:

- reverse/side input could inherit an overly broad Driven allowance;
- the original probe fought the normal movement controller and did not prove observed velocity;
- exact side input needed a forward deadzone;
- server displacement sampling needed direction-aware limits and bounded server elapsed time;
- wall probing and vertical validation needed Motion Works-specific protection;
- legal turn momentum needed to avoid false strafe corrections.

Measured valid trials at zero and 150 ms found normal reverse/strafe near the ordinary 26-stud/second Rank 0 limit with no invalid-direction damage. Forged approximately 34- and 80-stud/second reverse/side movement was corrected when actually observed. Smooth curves and approximately 90-degree turns avoided Driven corrections. These are partial single-client fixture results, not multiplayer approval.

The last code adjustment gives bounded Coastdown a direction-aware forward inertial envelope and counts Coastdown corrections. That exact final working tree has **not** completed a fresh runtime regression.

## Hard blocker at handoff

During the final test session Roblox Studio reported that its Assistant plugin changed version and explicitly required a Studio restart. Later test setup calls did not reach the server; the player remained `Lobby` / `ScrapRunner`. Those trials were discarded.

Studio was then stopped in Edit mode, latency was restored to zero, all three Script Sync roots reported healthy, and runtime fixtures were absent. The console was not called clean because the plugin-version and remote-service warnings remained.

Before any more testing:

1. Restart Roblox Studio completely.
2. Reopen the original `savefile.rbxl`.
3. Keep the disk version if Script Sync asks which version to use; do not discard the uncommitted files.
4. Wait for all three existing roots to become healthy.
5. Verify the Assistant/MCP warning is gone and a harmless read reaches both Edit and playtest contexts.

Stop if Script Sync reports a conflict, a root path differs, or Studio/MCP disconnects.

## Canonical Script Sync layout

Do not remap, stop, or replace healthy roots casually.

| Studio root | Local mapping | Canonical synchronized files |
|---|---|---|
| `ServerScriptService.Server` | `src/server` | `src/server/Server/*.luau` |
| `ReplicatedStorage.Shared` | `src/shared` | `src/shared/Shared/*.luau` |
| `StarterPlayer.StarterPlayerScripts` | `src/client` | `src/client/StarterPlayerScripts/*.luau` |

The wrapper directories are intentional Script Sync output. Do not flatten them.

The untracked `src/server/ServerScriptService/` directory is an old, inactive duplicate created by an earlier incorrect mapping. It is not the active Server root. Preserve it until the user authorizes a dedicated comparison/removal task.

## Working-tree ownership

The dirty tree belongs to the user. Current tracked Motion Works work touches:

- the roadmap and class/evolution documents;
- client developer, hammer, progression, Rammer, robot movement, and Motion Works controllers/state;
- server developer tools, route/session/extraction/progression integration, movement validation, and Motion Works combat;
- shared class, evolution, and Motion Works configuration.

Important new files include:

- `src/shared/Shared/MotionWorksConfig.luau`
- `src/server/Server/MotionWorksCombatService.luau`
- `src/client/StarterPlayerScripts/MotionWorksClientState.luau`
- `src/client/StarterPlayerScripts/MotionWorksController.local.luau`
- `docs/MOTION_WORKS_PROTOTYPE.md`
- `docs/MOTION_WORKS_DIRECTIONAL_VALIDATION.md`
- `tools/motionworks/DirectionalProbe.server.luau`
- `tools/motionworks/DirectionalProbe.local.luau`
- `tools/motionworks/directional-results-2026-09-04.json`

The probe files are non-synchronized, explicit Studio-only tools. They must never run automatically for normal players. The JSON preserves intermediate and discarded observations for auditability; do not interpret every row as a pass.

Nothing is staged. Keep it that way until the requested automated checks and genuine human gate pass. `art/` is untracked and must remain untouched.

## Product and security boundaries

- Level 8 Striker, Spinner, and Rammer are accepted behavior and must remain exact.
- Impact Foundry is the accepted first internal Level 20 prototype.
- Motion Works is the incomplete second internal prototype.
- Field Rig has not started.
- `Level20PublicEnabled` must remain false until all three Level 20 families are implemented and validated.
- Combat, movement validation, damage, cooldowns, progression, XP, extraction, and persistence remain server-authoritative.
- Clients never choose targets, hit results, damage, rewards, timestamps used as authority, arbitrary destinations, or class state.
- Studio uses the mock profile adapter. Live persistence was validated in an isolated namespace but is not launched.
- The published private Roblox build was restored to persistence-disabled configuration. Do not publish as part of this handoff.

## Exact continuation plan

After the restart:

1. Inspect Git and the real Studio hierarchy before editing.
2. Confirm the final local Motion Works files have synchronized to the intended Studio instances.
3. Re-run the complete cases 11–20 directional matrix from `MOTION_WORKS_DIRECTIONAL_VALIDATION.md` at zero and 150 ms, including Coastdown correction accounting and Rank 30 endpoints.
4. Re-run wall-lift, grounding, camera, movement, standard hammer, Striker, Spinner, Rammer, Impact Foundry, HUD, progression, extraction, death, respawn, and lobby regression checks.
5. Restore latency to zero, stop Studio, inspect server/client consoles, confirm the roots remain healthy, and run `git diff --check`.
6. Only after all automated checks pass, provide the documented genuine two-client Motion Works gate. Leave the work uncommitted until the user reports that gate passed.

Do not start Field Rig, balance tuning, another evolution, publishing, or a new milestone.

## First prompt for Claude

Use this if a fresh Claude session does not automatically continue:

> Read `CLAUDE.md` and every imported file completely. This working tree contains the user's uncommitted Motion Works milestone; preserve it exactly. First inspect Git status and diff, then list the current Roblox Studio instances and verify the three Script Sync roots. Roblox Studio previously required a restart after an Assistant plugin update. Resume only the final Motion Works directional and regression tests described in `docs/MOTION_WORKS_DIRECTIONAL_VALIDATION.md`. Do not commit, publish, touch `art/`, remove the inactive legacy tree, start Field Rig, or request the two-client human gate until every remaining automated check passes.

## Tooling handoff

Claude Code is not installed on this PC at preparation time. The project-level `.mcp.json` points to the existing local Roblox launcher at `%LOCALAPPDATA%\Roblox\mcp.bat` through `cmd.exe`, which is the Windows-compatible form documented by Anthropic. It contains no credentials. Claude Code should request approval for this project-scoped MCP server on first use.

If Claude cannot start the MCP server, do not guess or install an unrelated Roblox package. Verify the launcher exists, install/authenticate Claude Code, approve the project MCP entry, restart Studio, and use `/mcp` or `claude mcp list` to inspect the connection. A successful connection must list the intended Studio instance and expose read/play/console controls before work resumes.

The `.codex/` review automation is not a Claude hook. Do not claim automatic review coverage unless it is separately and safely ported, simulated once, and approved by the user.
