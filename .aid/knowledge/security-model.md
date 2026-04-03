# Security Model

> **Source:** discovery-quality-assessor
> **Status:** Active
> **Last Updated:** 2026-04-03

## Context

Farhaven is a 100% offline single-player mobile game with no backend, no network calls, no user accounts, and no multiplayer. The security model is scoped to:
- Save-game integrity (preventing corruption, not anti-cheat)
- Monetization safety (demo/premium unlock gate)
- Data privacy (no data collection)

## Authentication

**Not applicable.** No user accounts, no login, no API keys, no network authentication.
The game is entirely offline per the GDD (line 7: "no ads, no IAP, no premium currency").

## Authorization

**Not applicable in the traditional sense.** The only authorization boundary is:
- **Demo vs. Premium unlock gate:** GDD section 10.1 describes a free demo (Days 1-5) with a $2.99 one-time unlock for the full game.
- **Current status:** No unlock gate implementation exists in code. The demo/premium boundary is a future feature.

⚠️ Inferred from code -- needs confirmation: When the unlock gate is implemented, it will likely use platform-native purchase verification (Google Play Billing / Apple StoreKit). No code for this exists yet.

## Secrets Management

**No secrets in the codebase.** Verified:
- No `.env` files found.
- No API keys, tokens, or credentials in source files.
- No `credentials.json` or similar.
- `.gitignore` does not exclude secret files (because none exist).

**Future concern:** When the monetization unlock is implemented, purchase receipt validation should not embed any secret keys client-side. For a purely offline game, platform receipt verification via Google Play / Apple APIs is the standard approach.

## Save System

Five scripts implement serialization via `get_save_data()` / `load_save_data()` pattern:

| Script | Data Serialized |
|--------|----------------|
| `scripts/hex/hex_grid.gd` (lines 165-209) | All tile state: biome, elevation, fog, structures, resources |
| `scripts/player/player.gd` (lines 324-339) | Player position (tile coordinates) |
| `scripts/inventory/inventory.gd` (lines 190-214) | Inventory slots, tool slots, bonus slots |
| `scripts/crafting/crafting_system.gd` (lines 177-186) | Crafting state |
| `scripts/scanner/catalog.gd` (lines 174-191) | Knowledge state, encounter labels |

### Save System Security Observations

1. **No save file encryption.** Save data is plain Dictionary objects. A player could edit saves to give themselves items or skip content. For a single-player offline game this is acceptable — there is no competitive advantage to exploit.

2. **No save data validation on load.** `load_save_data()` methods use `data.get()` with defaults but do not validate data types or value ranges. Malformed save data could cause runtime errors.
   - Evidence: `hex_grid.gd` line 204 accesses `td["tile_col"]` with bracket notation (no default), which would crash on missing keys.
   - Evidence: `inventory.gd` line 213 uses `mini()` for bounds checking on array size — one of the few validation points.

3. **No save file I/O code exists yet.** The `get_save_data()`/`load_save_data()` methods produce/consume Dictionaries, but no code calls `FileAccess` to write saves to disk. The actual persistence layer is not yet implemented.

## Input Validation

| Location | Validation | Evidence |
|----------|-----------|----------|
| `scripts/hex/map_loader.gd` | File existence check, JSON parse validation | Lines 44+ — `FileAccess.open()` + null check |
| `scripts/player/player_camera.gd` | Clamp on camera values | 3 clamp/min/max calls |
| `scripts/player/player_input.gd` | Input magnitude validation | 1 clamp call |
| `scripts/auto_interaction/auto_interaction_system.gd` | Distance/range validation | 1 clamp call |

General observation: Input validation is minimal but appropriate for an offline game. Touch input goes through Godot's input system which handles sanitization at the engine level.

## OWASP Concerns Observed

Most OWASP categories do not apply to an offline mobile game. Relevant concerns:

### M1: Improper Platform Usage
- **Status:** Low risk. The game uses standard Godot APIs for file I/O and rendering.
- **Concern:** When monetization is added, improper Play Store / App Store API usage could allow purchase bypass.

### M2: Insecure Data Storage
- **Status:** Medium risk (future).
- **Concern:** Save files will be stored in the app's user data directory. On rooted Android devices, these are accessible. No encryption is planned. For a single-player game, this is acceptable but the premium unlock state should not be stored in an easily editable save file.
- ⚠️ Inferred from code -- needs confirmation: The demo/premium unlock should be verified via platform purchase APIs, not a local flag.

### M9: Reverse Engineering
- **Status:** Low risk. GDScript source is included in the exported PCK file and is trivially decompilable. This is inherent to Godot and not a significant concern for a $2.99 game.

⚠️ Security assessment from static analysis only -- dynamic testing required

## Dependencies with Known Vulnerabilities

- **gdUnit4 v6.0.3** — test-only dependency, not shipped in production builds. No known vulnerabilities.
- **Godot 4.6-stable** — the engine itself. No specific CVEs checked; the project should track Godot security advisories.
- No third-party GDScript libraries beyond gdUnit4.
- No lock files to audit (GDScript has no package manager).

## Recommendations

1. When implementing save persistence, validate all loaded data types and ranges to prevent crashes from corrupted/edited saves.
2. When implementing the premium unlock gate, use platform-native purchase verification (Google Play Billing Library / Apple StoreKit 2) rather than a local boolean flag.
3. Do not embed any signing keys or API secrets in the client binary.
4. Consider obfuscating the premium unlock state (though this is low priority for a $2.99 game).
