# Discovery State

**Grade:** A
**Minimum Grade:** A
**Project Type:** Greenfield
**User Approved:** yes

## External Documentation

- https://www.redblobgames.com/grids/hexagons/ -- Red Blob Games Hexagonal Grids
- https://docs.godotengine.org/en/stable/ -- Godot 4.x docs
- https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/ -- GDScript reference
- https://docs.godotengine.org/en/stable/tutorials/platform/android/ -- Godot Android guidelines
- https://docs.godotengine.org/en/stable/tutorials/platform/ios/ -- Godot iOS guidelines

## Settings
- **Minimum Grade:** A
- **Last Run:** 2026-04-03T14:30:00Z

## Current Grade: A

**Recommendation:** Pass

The Knowledge Base is thorough, well-sourced, and accurate. All critical, high, and medium issues from prior review cycles have been resolved. The remaining issues are minor: external-sources.md has a factual error claiming Farhaven "avoids class_name for most scripts" (line 110) when 30 of 41 files use it, a touch emulation line reference off by 1 (line 44 vs 45), README.md has a stale test count (518 vs 600), and feature-inventory.md has a minor inaccuracy about FaunaManager location. These are all minor-severity issues that would not cause significant problems for an agent working in this codebase.

## Documents

| Document | Grade | Status | Issues |
|----------|-------|--------|--------|
| architecture.md | A+ | Pass | -- |
| technology-stack.md | A+ | Pass | -- |
| module-map.md | A+ | Pass | -- |
| coding-standards.md | A+ | Pass | -- |
| data-model.md | A+ | Pass | -- |
| api-contracts.md | A+ | Pass | -- |
| integration-map.md | A+ | Pass | -- |
| domain-glossary.md | A+ | Pass | -- |
| test-landscape.md | A+ | Pass | -- |
| security-model.md | A+ | Pass | -- |
| tech-debt.md | A+ | Pass | -- |
| infrastructure.md | A+ | Pass | -- |
| ui-architecture.md | A+ | Pass | -- |
| feature-inventory.md | A | Pass | 1 minor: FaunaManager location wrong |
| project-structure.md | A+ | Pass | -- |
| external-sources.md | A- | Pass | 2 minors: class_name convention claim wrong, touch emulation line ref off by 1 |
| known-issues.md | A+ | Pass | -- |
| INDEX.md | A+ | Pass | -- |
| README.md | A | Pass | 1 minor: stale test count (518 vs 600) |
| CLAUDE.md | A+ | Pass | -- |

## Issues Found

### external-sources.md (A-)
- [MINOR] Source 3 (line 110) claims "Farhaven avoids this [class_name] for most scripts, using preload() instead." This is factually wrong: 30 of 41 source files DO use class_name. coding-standards.md correctly says "Most scripts register class_name." The external-sources claim is the opposite of reality.
- [MINOR] Source 2 (line 74) references "project.godot line 44" for touch emulation. The actual line is 45 (line 44 is blank/section header).

### README.md (A)
- [MINOR] Line 28 says test-landscape.md has "518 tests" but the document now correctly says ~600 test functions (512 unit + 88 integration). README.md completeness table was not updated when test-landscape.md was fixed.

### feature-inventory.md (A)
- [MINOR] Feature #9 (Survival System) says "FaunaManager (stubbed in main.gd)" but FaunaManager is referenced in auto_interaction_system.gd (line 340), not main.gd.

## Verification Spot-Checks

| Claim | Document | Verified | Evidence |
|-------|----------|----------|----------|
| Godot Engine 4.6-stable | technology-stack.md | Yes | project.godot line 20: features=PackedStringArray("4.6", "Mobile") |
| gdUnit4 version 6.0.3 | technology-stack.md | Yes | addons/gdUnit4/plugin.cfg line 6: version="6.0.3" |
| Mobile renderer (Vulkan) at line 49 | technology-stack.md | Yes | project.godot line 49: renderer/rendering_method="mobile" |
| ETC2/ASTC compression at line 50 | technology-stack.md | Yes | project.godot line 50: import_etc2_astc=true |
| Viewport 1080x1920 at lines 34-35 | technology-stack.md | Yes | project.godot lines 34-35 confirmed |
| Touch emulation at line 45 | technology-stack.md | Yes | project.godot line 45: emulate_touch_from_mouse=true |
| 32 .gd files in scripts/ | architecture.md | Yes | find scripts/ -name "*.gd" returns 32 |
| 30 of 41 source files use class_name | coding-standards.md | Yes | Anchored grep ^class_name: 30 files (22 scripts + 8 ui + 0 scenes/world); total 41 .gd files |
| Flat-top hexagons | architecture.md | Yes | hex_math.gd line 5: "Flat-top hexagon layout" |
| HEX_SIZE = 3.0 | domain-glossary.md | Yes | hex_math.gd line 7: const HEX_SIZE: float = 3.0 |
| GATHER_RADIUS = 0.75 | api-contracts.md | Yes | auto_interaction_system.gd line 43: const GATHER_RADIUS: float = 0.75 |
| Inventory extends RefCounted | data-model.md | Yes | inventory.gd line 2: extends RefCounted |
| Player owns Inventory at line 26 | architecture.md | Yes | player.gd line 26: var inventory: _Inventory = _Inventory.new() |
| WALKABLE_STRUCTURES has 5 items at line 20 | api-contracts.md | Yes | hex_grid.gd line 20: shelter, torch, workbench, storage_chest, campfire |
| PropRegistry at project.godot line 25 | architecture.md | Yes | project.godot line 25 confirmed |
| HexGrid at project.godot line 26 | architecture.md | Yes | project.godot line 26 confirmed |
| prop_renderer.gd is 473 lines | module-map.md | Yes | wc -l confirms 473 |
| main.gd is 76 lines | module-map.md | Yes | wc -l confirms 76 |
| hex_grid.gd is 220 lines | module-map.md | Yes | wc -l confirms 220 |
| auto_interaction_system.gd is 409 lines | module-map.md | Yes | wc -l confirms 409 |
| ~600 total test functions (512 unit + 88 integration) | test-landscape.md | Yes | grep ^func test_ across tests/ returns 600 (512 unit + 88 integration) |
| Knowledge states: UNKNOWN/ENCOUNTERED/CATALOGED | feature-inventory.md | Yes | catalog.gd line 7: enum KnowledgeState { UNKNOWN, ENCOUNTERED, CATALOGED } |
| SCAN_RANGE = 1 at line 26 | domain-glossary.md | Yes | scanner_system.gd line 26: const SCAN_RANGE: int = 1 |
| _wire_systems at main.gd line 23 | architecture.md | Yes | grep confirms func _wire_systems at line 23 |
| Two autoloads: PropRegistry and HexGrid | external-sources.md | Yes | project.godot lines 25-26 confirmed |
| Touch emulation at line 44 | external-sources.md | No | Actual line is 45, not 44 |
| "Farhaven avoids class_name for most scripts" | external-sources.md | No | 30 of 41 files use class_name. Most scripts DO use it. |
| FaunaManager stubbed in main.gd | feature-inventory.md | No | FaunaManager is in auto_interaction_system.gd:340, not main.gd |

## Cross-Cutting Concerns

1. **All critical, high, and medium issues from prior reviews are resolved.** class_name count (30/41), knowledge state names (UNKNOWN/ENCOUNTERED/CATALOGED), test function totals (600), autoload ordering, entry points table, source file count (41), INDEX.md stale summaries -- all now correct in the primary documents.

2. **external-sources.md class_name claim contradicts coding-standards.md.** Source 3 says "avoids class_name for most scripts" while coding-standards.md correctly says "Most scripts register class_name." This error is isolated to external-sources.md and does not propagate to other documents.

3. **README.md stale test count.** README.md says "518 tests" for test-landscape.md but INDEX.md, test-landscape.md, and CLAUDE.md all correctly say ~600. The README completeness table was not refreshed in the last fix cycle.

4. **No coverage gaps remain.** All 16 primary KB documents cover their promised scope, are well-sourced with file paths, and provide actionable guidance for agents.

## Q&A

### Q1
- **Category:** Infrastructure
- **Impact:** High
- **Status:** Answered
- **Context:** project.godot sets renderer/rendering_method="mobile" (Vulkan-based), but docs/01-godot-engine-setup.md recommends Compatibility renderer for broadest device support. Mobile renderer requires Vulkan-capable hardware, excluding older Android devices (pre-2018). For a casual game targeting maximum reach, this matters.
- **Suggested:** Compatibility renderer for broad device support. Current Mobile renderer may be intentional for development visuals with a plan to switch later.
- **Question:** Which Godot rendering method is the final decision -- Mobile or Compatibility?
- **Answer:** Compatibility. Farhaven aesthetic is intentionally simple (per-vertex color on hexes, placeholder meshes, no complex shaders). Nothing requires Vulkan. Maximum device reach is more important than extra visuals for a $2.99 casual mobile game.

### Q2
- **Category:** Infrastructure
- **Impact:** High
- **Status:** Answered
- **Context:** docs/01-godot-engine-setup.md raises this directly ("Andre has a Mac?"). Godot iOS export requires macOS + Xcode. If no Mac is available, alternatives include cloud macOS services. iOS is listed as a primary target platform.
- **Suggested:** If no Mac, launch Android first and use a CI cloud runner for iOS later.
- **Question:** Is a macOS environment available for iOS builds?
- **Answer:** No Mac available. Will need cloud macOS (GitHub Actions macOS runner or similar) or defer iOS.

### Q3
- **Category:** Infrastructure
- **Impact:** High
- **Status:** Answered
- **Context:** No CI/CD configuration exists -- no .github/workflows/, no build scripts. GitHub is the remote origin. gdUnit4 tests exist (23 files) but nothing runs them automatically. For a mobile game targeting two app stores, automated builds and test runs are important.
- **Suggested:** GitHub Actions with Godot community Docker images.
- **Question:** What is the planned CI/CD pipeline for building and testing?
- **Answer:** GitHub Actions with Godot community Docker images.

### Q4
- **Category:** Infrastructure
- **Impact:** Medium
- **Status:** Answered
- **Context:** GDD specifies Android 8.0+ (API 26) as minimum. Google Play now requires target API 34+. No export_presets.cfg exists to check actual values.
- **Suggested:** Minimum SDK 26 (Android 8.0), Target SDK 34+ (per Google Play requirements).
- **Question:** What Android target SDK and minimum SDK levels should be used?
- **Answer:** Minimum SDK 26 (Android 8.0), Target SDK 34+ (per Google Play requirements).

### Q5
- **Category:** Infrastructure
- **Impact:** Medium
- **Status:** Answered
- **Context:** Godot 4.x generates .uid files alongside .gd scripts (59+ committed). .gitignore does not exclude them. Committing is generally recommended for team/multi-agent projects.
- **Suggested:** Keep committing them (current behavior is correct).
- **Question:** Will .uid files continue to be committed to the repository?
- **Answer:** Yes, keep committing them. Current behavior is correct for multi-agent development.

### Q6
- **Category:** Business
- **Impact:** Medium
- **Status:** Answered
- **Context:** Original GDD defines "Free demo + $2.99 one-time unlock." Vision pivot changes to "Chapter 1 FREE + ~$2.50 per chapter." These are fundamentally different monetization architectures. Code currently has only ch1.json with no chapter-switching or unlock infrastructure.
- **Suggested:** Episodic model (per vision pivot), but Chapter 1 MVP does not need unlock infrastructure since Ch1 is free.
- **Question:** Is the episodic chapter model confirmed, or is the original single-unlock model still under consideration?
- **Answer:** Undecided. Build Chapter 1 first, decide monetization model later. No unlock infrastructure needed for Ch1 MVP regardless.

### Q7
- **Category:** Infrastructure
- **Impact:** Medium
- **Status:** Answered
- **Context:** No keystore files, signing config, or export_presets.cfg exist. Android requires a release keystore for Play Store. iOS requires Apple Developer certificates. These are security-sensitive and should not be in the repository.
- **Suggested:** Store signing credentials outside the repo. Use environment variables or secrets manager in CI/CD.
- **Question:** How will release builds be signed for Android (keystore) and iOS (certificates)?
- **Answer:** Deferred until release is imminent. Will use environment variables/secrets in CI/CD when the time comes.

### Q8
- **Category:** Architecture
- **Impact:** Medium
- **Status:** Answered
- **Context:** GDD section 4.1 describes "procedurally generated hex map per playthrough." Vision pivot introduced episodic chapters with narrative-driven maps. Current implementation uses MapLoader to load hand-designed JSON maps. No procedural generation code exists.
- **Suggested:** Hand-designed maps for story chapters. Procedural generation may return as post-launch feature (daily challenges).
- **Question:** Is procedural map generation still planned, or are all maps hand-designed?
- **Answer:** Hand-designed maps only. No procedural generation planned.

### Q9
- **Category:** Infrastructure
- **Impact:** Low
- **Status:** Answered
- **Context:** No version number defined anywhere. project.godot has no version field. No changelog. GDD references "v1.0" informally.
- **Suggested:** Semver (major.minor.patch), currently pre-1.0 development.
- **Question:** What is the versioning scheme for releases?
- **Answer:** Semver (major.minor.patch). Currently pre-1.0 development.

### Q10
- **Category:** Infrastructure
- **Impact:** Low
- **Status:** Answered
- **Context:** .gitignore excludes reports/ directory. No reports directory exists and no test reporting configuration found. Tests run only in Godot editor.
- **Suggested:** gdUnit4 generates XML/JUnit reports. Configure output to reports/ (already gitignored). Integrate with CI/CD later.
- **Question:** Where will test reports be stored and how will test results be tracked?
- **Answer:** gdUnit4 XML/JUnit reports to reports/ (already gitignored). Integrate with GitHub Actions CI/CD later.

### Q11
- **Category:** Business
- **Impact:** Low
- **Status:** Answered
- **Context:** GDD mentions store description but no store assets (screenshots, descriptions) exist. ASO keywords, category, and age rating not documented.
- **Suggested:** Defer until closer to release.
- **Question:** What is the App Store / Play Store listing strategy?
- **Answer:** Deferred until closer to release. Focus on gameplay completion first.

### Q12
- **Category:** Features
- **Impact:** Required
- **Status:** Answered
- **Context:** The feature inventory needs to be populated with the complete list of features this game will ship. The codebase shows implemented features (hex grid, movement, gathering, crafting, scanning, inventory, HUD) and the GDD/vision pivot describe planned features (survival, building, day/night, fauna, escape). A confirmed feature list is needed to track scope and completeness.
- **Suggested:** Based on code and docs: hex grid/map, player movement, resource gathering, inventory, crafting, scanner/catalog, HUD/UI, auto-interaction, survival system (stubbed), building system (stubbed), day/night cycle (stubbed), fauna/threats (stubbed).
- **Question:** What is the confirmed list of features for the game? Please review the suggested list and add/remove/modify as needed.
- **Answer:** Confirmed 13 features: hex grid/map, player movement, resource gathering, inventory, crafting, scanner/catalog, HUD/UI, auto-interaction, survival system, building system, day/night cycle, fauna/threats, journal and narrative system. Note: "journal and narrative system" is a new addition not in the suggested list.

## Discovery -- Review Cycle 1

### Q13: [Data Quality: High] Scripts file count discrepancy -- is the count 28 or 32?
**Status:** Answered
**Context:** architecture.md and project-structure.md both claim scripts/ has 28 .gd files. Actual filesystem count is 32. The KB was generated on 2026-04-03 and the most recent commits also date from that period. Possible that 4 files were added after the scout phase but before the architect phase, or the count was simply wrong. The correct count needs to propagate to all docs that reference it.
**Suggested:** 32 is correct. The docs should be updated. Verify by running find scripts/ -name "*.gd" and counting.
**Answer:** 32 is correct (verified via filesystem). Update all docs.

### Q14: [Data Quality: Medium] class_name registration count -- what is the project convention?
**Status:** Answered
**Context:** coding-standards.md states "Only 16 of 44 scripts use class_name" and implies most scripts deliberately avoid it. Actual count is 30 of 41 source files use class_name. The convention description is misleading. Is the intent to move toward universal class_name registration, or are autoloads/renderers intentionally excluded?
**Suggested:** Update the convention docs to reflect reality: most scripts DO use class_name. The exceptions are autoloads (which cannot due to initialization ordering) and main.gd.
**Answer:** 31 of 40 source files use class_name (verified via grep). Most scripts DO register class_name. Exceptions are autoloads (hex_grid.gd, prop_registry.gd) and bootstrap (main.gd) plus a few renderers. Update docs to reflect majority convention.

## Discovery -- Review Cycle 2

### Q15: [Data Quality: High] class_name count still wrong after fix -- 31/40 or 30/41?
**Status:** Answered
**Context:** The fix cycle updated class_name count to "31 of 40" across coding-standards.md and tech-debt.md, citing "verified via grep." However, an anchored grep (^class_name) shows only 30 files with class_name declarations (22 in scripts/, 8 in ui/, 0 in scenes/world/). hex_grid_renderer.gd does NOT have class_name. Total source files are 41 (32 scripts + 8 ui + 1 scenes/world), not 40. The non-anchored grep likely matched hex_grid.gd comment mentioning "class_name registration" as a false positive.
**Suggested:** Correct to "30 of 41." The 11 files without class_name are: hex_grid.gd, prop_registry.gd, main.gd, player.gd, player_camera.gd, map_loader.gd, prop_renderer.gd, prop_label_renderer.gd, scan_progress_renderer.gd, crafting_system.gd, hex_grid_renderer.gd.
**Answer:** 30 of 41 confirmed via anchored grep (^class_name). Fix applied to all docs.

### Q16: [Data Quality: Medium] feature-inventory.md uses wrong knowledge state names
**Status:** Answered
**Context:** Feature #6 (Scanner/Catalog) description says "knowledge states (Unknown -> Scanned -> Identified -> Analyzed)" but catalog.gd defines enum KnowledgeState { UNKNOWN, ENCOUNTERED, CATALOGED } -- only 3 states with completely different names. Every other KB document (data-model.md, api-contracts.md, domain-glossary.md) uses the correct names.
**Suggested:** Replace with "knowledge states (UNKNOWN -> ENCOUNTERED -> CATALOGED)"
**Answer:** Fixed to "knowledge states (UNKNOWN -> ENCOUNTERED -> CATALOGED)" per catalog.gd enum.

### Q17: [Data Quality: Low] Test function count discrepancy in test-landscape.md summary
**Status:** Answered
**Context:** test-landscape.md summary says "~430 test functions" for unit tests and "~518 test functions" total. But the per-file table in the same document sums to 512 unit + 88 integration = 600 total. The per-file counts are individually correct; only the summary totals are wrong.
**Suggested:** Update summary to "~512 unit test functions" and "~600 test functions total."
**Answer:** Fixed summary to match per-file table totals: 512 unit + 88 integration = 600 total.

## Review History

| # | Date | Grade | Source | Notes |
|---|------|-------|--------|-------|
| 1 | 2026-04-03 | Pending | discovery | Initial generation complete, 12 Q&A questions collected |
| 2 | 2026-04-03 | D | review-1 | 4 criticals (wrong CLI flag, wrong class_name count, pointy-top claim, empty feature-inventory), 1 high, multiple lows |
| 3 | 2026-04-03 | -- | fix-1 | Fixed all criticals/high/lows, populated feature-inventory, Q&A complete (14 answered) |
| 4 | 2026-04-03 | C | review-2 | 1 critical (wrong knowledge state names), 5 mediums (class_name count, test count, autoload order, entry points) |
| 5 | 2026-04-03 | -- | fix-2 | Fixed all criticals/mediums from review-2, updated Q&A (Q15-Q17 answered) |
| 6 | 2026-04-03 | A- | review-3 | 7 minors remaining (stale INDEX.md summary, external-sources sole autoload claim, line ref off-by-ones, source file count 40 vs 41) |
| 7 | 2026-04-03 | -- | fix-3 | Fixed INDEX.md stale summary, external-sources sole autoload claim, source file counts 40->41, touch emulation line refs |
| 8 | 2026-04-03 | A | review-4 | 4 minors remaining: external-sources class_name convention claim wrong, external-sources touch line ref still off-by-1, README.md stale test count, feature-inventory FaunaManager location wrong |
| 9 | 2026-04-03 | A | approval | User approved. KB ready for Interview phase. Last 4 minors fixed. |
