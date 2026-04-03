# Infrastructure

> **Source:** discovery-quality-assessor
> **Status:** Active
> **Last Updated:** 2026-04-03

## Context

Farhaven is a 100% offline single-player mobile game with no backend services. Infrastructure means the build/export pipeline, development environment, and distribution tooling -- not cloud servers or containers.

## Build System

### Engine
- **Godot 4.6-stable** (standard edition, not .NET)
- **Language:** GDScript (interpreted, no compilation step)
- **Project config:** project.godot (lines 9-51)

### Build Process
There is no formal build process. The current workflow is:
1. Open the project in the Godot editor
2. Press Play to run in the editor
3. No export presets configured -- no mobile builds have been produced

### Export Configuration
**Status: Not configured.**
- No export_presets.cfg file exists
- No Android export preset (APK/AAB)
- No iOS export preset
- No desktop export preset

### Required Export Setup (from external-sources.md)

#### Android (Primary Target)
- Android SDK (API 26+ per GDD, but Google Play requires API 34+ currently)
- OpenJDK 17
- Debug keystore (auto-generated or manual)
- Release keystore (must be created for Play Store)
- Output: AAB (required for Play Store), APK (for testing)
- Architectures: arm64-v8a (required), armeabi-v7a (optional)

#### iOS (Secondary Target)
- macOS with Xcode required -- cannot build on Windows
- Apple Developer Account ($99/year)
- Provisioning profiles (development + distribution)
- Mac availability unconfirmed (docs/01-godot-engine-setup.md: "Andre has a Mac?")
- Alternative: MacStadium or GitHub Actions macOS runners

## CI/CD Pipeline

**Status: None exists.**

No automation of any kind:
- No .github/workflows/ directory
- No Jenkinsfile
- No Makefile
- No shell scripts for building or testing
- No pre-commit hooks

### Recommended Pipeline (not yet implemented)

A minimal CI pipeline for a Godot project would include:
1. **Test stage:** Run gdUnit4 tests via godot --headless
2. **Build stage:** Export Android APK/AAB via godot --headless --export-release
3. **Artifact stage:** Upload build artifacts
4. **Trigger:** On push to main, on PR creation

GitHub Actions has community Godot Docker images (e.g., barichello/godot-ci) suitable for this.

## Containerization

**None.** No Dockerfile, no docker-compose, no container configuration. Not expected for a Godot game project -- the Godot editor is the development environment.

If CI/CD is added, a Godot Docker image would be used in the pipeline, not in development.

## Infrastructure as Code

**None.** No Terraform, Pulumi, CDK, or CloudFormation. Not applicable -- there is no cloud infrastructure. The game is 100% offline with no backend.

## Environments

| Environment | Status | Details |
|-------------|--------|---------|
| Development | Active | Godot 4.6 editor on Windows 11 |
| Testing | Manual | gdUnit4 in-editor test runner only |
| Staging | None | No staging builds or devices |
| Production (Android) | None | No export preset, no builds, no Play Store listing |
| Production (iOS) | None | No export preset, no macOS access confirmed |

## Monitoring and Observability

**None.** No crash reporting, no analytics, no telemetry. Per the GDD, the game collects zero user data (100% offline). This is a deliberate design decision, not an oversight.

If crash reporting is desired in the future, Godot supports:
- Custom crash handler writing to local log files
- Third-party SDKs (Sentry, Firebase Crashlytics) -- but these would conflict with the "no data collection" policy

## Version Control

- **VCS:** Git, hosted on GitHub (private repository)
- **Main branch:** main
- **Current branch:** delivery-003
- **Branch strategy:** Feature/delivery branches off main
- **.gitignore:** Excludes .godot/, exports, IDE files, logs, test reports
- **Notable:** .uid files are committed (Godot 4.x UID tracking files)

## Asset Pipeline

- **Current:** No imported 3D models. All rendering is programmatic (ArrayMesh, MultiMesh, shaders).
- **Planned (from docs):** AI-generated low-poly 3D models via the pipeline described in docs/02-visual-assets-pipeline.md.
- **No assets/ directory exists yet** (noted in project-structure.md observation #1).

## Display and Rendering Configuration

| Setting | Value | Source |
|---------|-------|--------|
| Viewport | 1080x1920 (portrait) | project.godot line 34-35 |
| Stretch mode | viewport | project.godot line 36 |
| Orientation | portrait | project.godot line 37 |
| Renderer | mobile (Vulkan) | project.godot line 49 |
| Texture compression | ETC2/ASTC | project.godot line 50 |
| Touch emulation | enabled | project.godot line 45 |

**Discrepancy:** The renderer is set to "mobile" (Vulkan) but docs/01-godot-engine-setup.md recommends "Compatibility" (OpenGL) for broadest device support. See tech-debt.md for details.

## Dependencies

| Dependency | Version | Scope | Files |
|------------|---------|-------|-------|
| Godot Engine | 4.6-stable | Runtime | project.godot |
| gdUnit4 | 6.0.3 | Test only | addons/gdUnit4/ (934 files) |

No other third-party dependencies. No package manager, no lock files. The project uses only Godot built-in APIs and one test addon.

## Gaps and Risks

1. **No mobile builds possible.** Export presets must be created before any real-device testing.
2. **No CI/CD.** All testing and building is manual.
3. **iOS build path unclear.** macOS access not confirmed. Cloud build alternatives not configured.
4. **No crash reporting.** When the game ships, there will be no visibility into player-side crashes.
5. **Android API level may need updating.** GDD targets API 26 but Google Play currently requires API 34+.
