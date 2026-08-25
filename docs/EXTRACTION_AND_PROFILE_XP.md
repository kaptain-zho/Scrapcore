# Extraction and Banked Profile XP

## Purpose and boundaries

This milestone tests one safe answer to arena banking without making permanent progression a source of combat power. A run still starts at Level 1 with zero XP, one unspent upgrade point, zero upgrade ranks, and `ScrapRunner`. XP earned from breakables and player eliminations is temporary until the player completes a physical extraction.

Two XP values now have deliberately different meanings:

- `RunXP` is the progress from the current level toward the next level.
- `UnbankedRunXP` is the server-owned total XP earned during the current life. It is the amount at risk and the only amount an extraction may bank.
- `BankedProfileXP` is permanent profile XP reserved for future cosmetic unlocks, presentation, and non-power account goals. It must never modify health, damage, movement, cooldowns, knockback, matchmaking, or any other combat outcome.

No store, spending system, skin inventory, paid recovery, or permanent combat progression is part of this milestone.

## Extraction rule

`ExtractionService` creates `Workspace.GrayboxArena.RunXPExtraction` deterministically near the northeast arena edge. `ArenaLayoutService` reserves clearance around the configured zone before generating the 140 breakables, so the portal does not overlap a wall, cardinal spawn, or breakable. The workshop remains far outside the arena.

The server accepts an attempt only when the triggering player:

- Is in authoritative `Arena` session state.
- Has a living current character and positive health.
- Is physically inside the configured extraction volume according to the server-observed root position.
- Has more than zero server-owned `UnbankedRunXP`.
- Has a safely loaded profile.

The portal uses a server-connected `ProximityPrompt`; there is no client extraction-completion remote. Once accepted, the player must remain inside for ten continuous seconds. `Workspace:GetServerTimeNow()` supplies the authoritative deadline. The client receives status and deadline messages only so it can interpolate the HUD.

Authoritative player damage flows through `AuthoritativeDamageService`. A real health reduction emits the shared server notification used by extraction and resets the deadline to a fresh ten seconds. Client damage claims, positions, timestamps, countdown values, and completion claims are never accepted. Leaving cancels extraction and preserves the active run and its unbanked XP for another attempt. Dying, disconnecting, or leaving the server before successful extraction destroys all unbanked XP and never invokes banking.

## Successful banking lifecycle

At the authoritative deadline, the extraction service snapshots the current unbanked total and the current run serial. It asks `ProfileDataService` to atomically bank that exact amount. The player remains in the arena with the run intact until the bank operation is confirmed.

Only after confirmation does the server:

1. Report the exact amount banked.
2. Cancel active Spinner and Rammer state; delayed hammer impacts are invalidated by the session transition.
3. Use the canonical `PlayerSessionService.ReturnToLobby` path.
4. Reset temporary level, XP, points, upgrade ranks, and class state.
5. Strip every arena weapon and class visual.
6. Move the grounded chassis to the protected workshop lobby.

A failed bank reports `BANKING FAILED — TRY AGAIN`, preserves the entire active run, and leaves the player in the arena. A later attempt reuses any unresolved receipt rather than creating duplicate credit. While that receipt is unresolved, additional XP awards are paused so the retried amount cannot silently diverge from the exact attempted amount. Death abandons the local retry state together with the run.

## Profile schema and idempotency

`ProfileDataService` owns a server-only in-memory cache with schema version 1:

- `SchemaVersion`
- `BankedXP`
- `LifetimeExtractedXP`
- `SuccessfulExtractions`
- `ProcessedExtractionReceipts`

Every extraction receives a server-generated GUID receipt. Live mutations use `UpdateAsync`, validate the stored schema inside the transform, and add XP only when the receipt is absent. A retried or reconciled receipt returns the already-credited profile without adding XP again. Receipt history is bounded to the latest 48 entries. Only one unresolved extraction can exist for a player at a time, so the active receipt cannot age out while it is needed.

DataStore reads and writes are wrapped in `pcall` with three bounded attempts and exponential backoff. An invalid, unsupported, or repeatedly unavailable profile is never replaced with defaults. The player stays protected in the lobby and deployment is blocked. `PlayerRemoving` discards unbanked run state and never calls the banking path. Current bank writes are atomic, so `BindToClose` does not convert or flush active runs.

## Studio-safe adapters

`ProfileDataConfig.EnableLiveDataStore` defaults to `false`. Therefore Studio and the current development build use the explicit in-memory `Mock` adapter. `AllowLiveDataStoreInStudio` also defaults to `false`; enabling only the first switch does not connect Studio to live profile data.

Mock profiles persist only for the life of the running Studio server. Stop and restart the playtest, or call the server-only Studio test function `ProfileDataService.ResetStudioMockProfiles()`, to clear them. `SetStudioMockWriteMode` can simulate a total write failure or one uncertain outcome for receipt-reconciliation tests. These helpers require Studio, are not remotes, and cannot be invoked by normal players.

The existing authorized developer request channel also accepts explicitly named Studio test actions for moving the current character to the Main Arena portal or extraction fixture, applying ten points of authoritative test damage, selecting the mock profile write mode, and reloading the mock profile from its adapter. Each action is rejected outside Studio and remains behind the unchanged developer authorization and request limiter. They are not shown to ordinary players and do not directly grant banked XP.

## Live DataStore validation

On August 24, 2026, the committed profile architecture was validated against Roblox's live DataStore service in the existing private Scrapcore experience. The published test build used the isolated `ScrapcoreProfile_LiveTest_v1` namespace and `BankedProfileXP` scope. Studio continued to use the mock adapter, Studio API access remained disabled, and no future production namespace was read, written, migrated, deleted, or overwritten.

The validation produced this evidence:

- A newly loaded isolated profile began with 0 banked XP.
- Extracting exactly 100 unbanked XP changed the bank from 0 to 100, and 100 survived a rejoin into a separate published server.
- Extracting a second 50 XP changed the bank from 100 to 150, and a later rejoin loaded exactly 150 rather than duplicating either extraction.
- Authoritative death with 100 unbanked XP left the bank at 150.
- Disconnecting with another 100 unbanked XP also left the bank at 150 after rejoining.
- Redeployment after extraction and rejoining began a canonical Level 1 run with zero unbanked run XP.
- No DataStore throttling, load/save failure, uncertain-write, or duplicate-receipt warning was observed during the controlled live test.

The Studio mock suite remains the evidence for deliberately simulated failed and uncertain writes, including receipt reconciliation. The live test did not manufacture Roblox networking failures.

After validation, the private published build was restored to the reviewed safe configuration with `EnableLiveDataStore = false`; Studio still defaults to the mock adapter, and the isolated live-test data was retained for audit purposes. The persistence architecture is therefore **validated against Roblox's live service but not launched for production**. A future production launch requires a separate reviewed configuration change, an explicitly approved production namespace, operational monitoring, and rollout evidence; it must not reuse or migrate the isolated live-test namespace by assumption.

## Deferred work

This milestone deliberately defers Level 300 progression, the Level 20 evolution graph, additional modes, functional skins, a profile-XP store, monetization, Robux revival, production analytics, and multi-place migration. Any future use of banked XP must remain cosmetic-only and pass a separate design and security review.
