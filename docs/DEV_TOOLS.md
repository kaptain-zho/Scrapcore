# Scrapcore Studio Developer Tools

## Purpose and safety boundary

The Scrapcore developer menu accelerates local progression, class, combat, and lifecycle testing. It is developer infrastructure, not a player feature or a substitute for normal progression tests.

Authorization is decided by the server on every request. Roblox Studio sessions are authorized. Published servers remain unauthorized unless both of these server-only settings are deliberately changed in `ServerScriptService.Server.DevToolsConfig`:

1. `EnableOutsideStudio` is set to `true`.
2. The requesting player's numeric UserId is present in `AllowedUserIds`.

The production switch is `false` and the future allowlist is empty by default. Do not move either setting into replicated storage, player attributes, or client code. The menu uses no network services and transmits no project information.

## Opening the menu

Start a Studio playtest and press **F2**. The compact panel is titled **SCRAPCORE DEV TOOLS — STUDIO ONLY**. Press F2 again or use the close button to hide it. F2 is ignored while a text box has focus.

Unauthorized clients receive no usable controls: the menu remains disabled, hidden, and unbound. A client-created GUI or forged local attribute cannot authorize requests.

## Controls

- **Add 10/50/100/500 XP** awards the exact amount through the canonical server XP path. Level gains, points, class eligibility, and caps therefore behave normally.
- **To Level 8/20/30** calculates and awards only the XP still required to reach that threshold. It does not directly write level or XP attributes.
- **Unlimited Points** toggles a server-owned Studio-session testing exception. While enabled, the existing upgrade request path can raise each category to its normal rank-30 cap without spending points. The progression HUD shows `∞ POINTS`, and the E menu remains available. Ordinary server rank, category, shape, timing, and safety validation still applies.
- **Reset Run** uses the canonical character reload lifecycle. It returns the player to Level 1, clears XP and upgrade ranks, resets the class, cancels attacks, and restores exactly one standard Scrap Runner hammer.
- **Heal** reapplies the authoritative maximum-health calculation and restores current health to that maximum.

Unlimited Points persists across death and respawn during the same authorized Studio player session. Turning it off performs the same clean canonical run reset so no free ranks, evolved class, or weapon state survives.

## Validation and logging

The client sends only a fixed action name. The server validates authorization, exact payload shape, action membership, request rate, player lifecycle, and action-specific state. XP amounts, target thresholds, upgrade ranks, health values, class state, and reset behavior are never accepted from the client.

Every accepted state-changing action produces one server log entry containing the player name, UserId, and action name. Rejected requests are counted without log spam. The single state response path is display-only and cannot grant authority.

Before shipping or publishing:

- Confirm `EnableOutsideStudio` remains `false`.
- Confirm `AllowedUserIds` remains empty unless a separately reviewed private-test policy explicitly requires it.
- Run a public-context authorization check and verify denial.
- Reset any test latency to zero and stop the Studio playtest.
- Use normal gameplay paths for final progression, combat, death-reset, and multiplayer acceptance tests.
