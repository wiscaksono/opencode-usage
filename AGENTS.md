# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

OpenCode Usage Monitor — a native macOS menu bar app (SwiftUI) that monitors OpenCode Go subscription usage (rolling, weekly, monthly limits) via `https://opencode.ai/zen/go/v1/usage`.

- Pure SwiftPM package. There is no `.xcodeproj` and no xcodegen — do not introduce one.
- Swift 6 with strict concurrency enabled. Deployment target: macOS 26 (requires Xcode 26+).
- Single executable target (`OpencodeUsage`) + test target (`OpencodeUsageTests`).
- The app is a background agent (`LSUIElement`) rendered through `MenuBarExtra` with window style.

## Commands

| Task | Command |
|---|---|
| Build debug + assemble `.app` bundle | `make build` |
| Build & launch | `make run` |
| Run tests | `swift test` |
| Format code | `swiftformat .` |
| Check formatting | `swiftformat --lint .` |
| Clean artifacts | `make clean` |

Before claiming work is done, all three of these must pass:

```bash
swift build && swift test && swiftformat --lint .
```

## Architecture

```
Sources/OpencodeUsage/
  App/           Entry point, MenuBarExtra scene, icon loading
  Views/         ContentView (popup), SettingsView (API key form)
  ViewModels/    UsageViewModel — @MainActor ObservableObject, 300s Timer refresh
  Models/        UsageModels.swift — API response types + UsageLevel enum
  Services/      NetworkManager — URLSession fetch + JSON decoding
  Storage/       AppSettings (UserDefaults prefs), KeychainStore (API key)
  Utilities/     Duration formatting helpers
Tests/OpencodeUsageTests/
Support/Info.plist   Template; version stamped by Makefile at bundle time
```

Data flow: `MenuBarExtra` → `ContentView` → `UsageViewModel` → `NetworkManager` → opencode API.

Storage split: user preferences live in `UserDefaults` via `AppSettings`; the API key lives in the Keychain via `KeychainStore`. Do not move secrets into `UserDefaults`.

The app bundle is assembled manually by the Makefile `bundle` target: binary from `.build/`, plist from `Support/Info.plist`, resources from SwiftPM's generated `OpencodeUsage_OpencodeUsage.bundle` (copied into `Contents/Resources/` so `Bundle.module` resolves at runtime). Version strings are stamped from git tags at bundle time.

## Conventions

- Swift Testing (`import Testing`, `#expect`, `@Test`), not XCTest.
- SwiftFormat config in `.swiftformat`: Swift 6, 4-space indent. Run `swiftformat .` before committing.
- Strict concurrency must stay clean. Pattern for sharing non-Sendable state across `@Sendable` closures: see `SharedFormatters` in `Services/NetworkManager.swift`.
- Prefer boring, simple code. No new dependencies without strong justification.
- Commit messages: lowercase, conventional-style summary line (e.g. `ci: add tag-driven release automation`).

## Apple Documentation (Sosumi)

This repo ships a project skill at `.agents/skills/sosumi/SKILL.md` (plus `skills-lock.json`) for fetching Apple documentation as Markdown.

- Load it whenever a task needs precise Apple API details: SwiftUI/AppKit/Foundation signatures, availability, Human Interface Guidelines, or WWDC transcripts.
- Quick pattern: swap `developer.apple.com` → `sosumi.ai` and fetch — e.g. `https://sosumi.ai/documentation/swiftui/view`.
- Unknown exact symbol path? Search first, then fetch the specific page.
- Full usage guide (patterns, MCP tools, troubleshooting) lives in the SKILL.md itself.

## Gotchas

- **Keychain queries must include `kSecAttrAccount`** (`KeychainStore` pins it to `"api-key"`). The service name collides with items written by older iterations of this app; querying by service alone makes `SecItemUpdate`/`SecItemCopyMatching` act on an arbitrary item and silently corrupt reads/writes. This caused a real production bug.
- The data-protection Keychain probe with legacy fallback in `KeychainStore` is intentional — ad-hoc signed builds can lack DP-keychain entitlements. Do not remove it.
- App version comes only from git tags (`vX.Y.Z`). Untagged builds stamp `0.0.0`. Never hardcode versions in `Support/Info.plist`; never bump versions manually.
- Releases are published exclusively by pushing a tag: `git tag vX.Y.Z && git push origin vX.Y.Z`. The release workflow re-runs lint + tests before building and publishing the dmg.
- The app is ad-hoc signed on purpose (no paid Developer Program). Do not add entitlements casually — it changes Keychain behavior and Gatekeeper handling.
- CI runs on `macos-26` GitHub runners (lint → test → build). Keep workflows compatible with that image.
