# Scrapcore instructions for Claude Code

@AGENTS.md
@Scrapcore_PvP_Project_Roadmap.md
@docs/CLAUDE_HANDOFF.md

## Claude-specific startup rules

- Treat `AGENTS.md` as the permanent authority for product intent, coding, security, testing, scope, and completion reporting. The roadmap controls milestone order. This file only bridges those rules into Claude Code.
- Begin every session by reading all three imported files completely, then inspect `git status`, `git diff`, the current branch, HEAD, and Script Sync state before editing.
- The working tree is intentionally dirty with an incomplete Motion Works milestone. Never discard, stash, stage, commit, regenerate, or overwrite those changes unless the user explicitly directs that exact action.
- Do not treat raw measurement output or an unchanged source file as a passing gameplay test. Use Roblox Studio MCP and record observable server/client evidence.
- List Studio instances on every run and identify `savefile.rbxl` by name. Never reuse an old Studio instance identifier.
- Keep ordinary Level 20 selection disabled. Do not start Field Rig, Level 35 robots, or another milestone while Motion Works remains incomplete.
- Do not touch `art/`. Do not delete the untracked legacy `src/server/ServerScriptService/` tree without a separately approved Script Sync audit.
- Use the mock profile adapter in Studio. Never publish, enable live DataStores, change monetization, or touch production data without explicit authorization.
- Stop every playtest, restore simulated latency to zero, inspect both console contexts, and run `git diff --check` before reporting a test result.
- The automatic review files under `.codex/` are Codex-specific. Do not run or port those hooks silently. The completion marker rule in `AGENTS.md` still applies to final reports.

## Repository commands

The repository is owned by a different Windows security identity in some shells. Use command-local trust rather than changing global Git configuration:

```powershell
git -c safe.directory=C:/roblox/ScapCore status --short --branch
git -c safe.directory=C:/roblox/ScapCore diff --check
```

Do not use destructive Git commands, force pushes, history rewrites, or broad cleanup commands.
