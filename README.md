# OpenCode Usage Monitor

[![CI](https://github.com/wiscaksono/opencode-usage/actions/workflows/ci.yml/badge.svg)](https://github.com/wiscaksono/opencode-usage/actions/workflows/ci.yml)

A native macOS Menu Bar application built with SwiftUI to easily monitor your Opencode Go subscription usage (Rolling, Weekly, and Monthly limits).

![App Screenshot](assets/screenshot.png)

## Features

- **Real-Time Monitoring**: View your Rolling, Weekly, and Monthly usage directly from the menu bar.
- **Smart Progress Bars**: Progress bar colors dynamically change based on usage levels (Green for safe, Yellow for medium, Red for critical).
- **Auto-Refresh**: Automatically fetches new data every 5 minutes, or you can manually refresh.
- **Lightweight**: Runs as a background agent (`LSUIElement`) with no dock icon clutter.
- **Terminal-Driven**: No Xcode GUI required. Built with plain SwiftPM and a `Makefile`.

## Prerequisites

- macOS 26+ with Command Line Tools / Xcode installed.

## Installation & Setup

1. **Clone the repository** (or navigate to the project directory):
   ```bash
   cd opencode-usage
   ```

2. **Build**:
   ```bash
   make build
   ```

3. **Run the app**:
   ```bash
   make run
   ```
   *(Note: The app will appear in your macOS Menu Bar. It does not have a dock icon).*

## Configuration: How to Get Your API Key

The app uses the official OpenCode API (`https://opencode.ai/zen/go/v1/usage`) to fetch your usage. You only need your OpenCode API key.

1. Open your opencode console.
2. Go to **Settings** → **API Keys**.
3. Copy your API key (starts with `sk-...`).
4. Open the **OpenCode Usage Monitor** from your Mac menu bar.
5. Click the **Settings (⚙️)** icon in the top right corner of the header.
6. Paste your API key into the text field and click **Save**.

The app will automatically fetch your usage every 5 minutes.

## Development Commands

A `Makefile` is provided for easy terminal workflows:

- `make build`: Builds the application and assembles the app bundle (Debug configuration).
- `make run`: Kills any existing instance, builds, and runs the app.
- `make release`: Builds the optimized app bundle (Release configuration) into `build/Release/`. The version is stamped from the latest git tag (`vX.Y.Z`), or `0.0.0` when no tag exists — override with `make release VERSION=0.2.0`.
- `make dmg`: Builds the Release bundle and packages it as `OpenCode Usage.dmg` for distribution.
- `make clean`: Removes the `.build/` and `build/` directories.
- `make test`: Runs the unit test suite ([Swift Testing](https://developer.apple.com/xcode/swift-testing/)).
- `make format`: Formats the codebase with [SwiftFormat](https://github.com/nicklockwood/SwiftFormat).
- `make logs`: Streams the unified logs specifically for this app subsystem (`com.wiscaksono.opencode-usage`).

## Releases

Pre-built `.dmg` images are published automatically on every version tag — grab the latest one from [Releases](https://github.com/wiscaksono/opencode-usage/releases).

> The app is ad-hoc signed, so macOS Gatekeeper may warn on first launch. Right-click the app → **Open** once to allow it.

### Cutting a release locally

1. Tag the commit (versions come only from git tags — never edit them by hand):
   ```bash
   git tag vX.Y.Z
   ```
2. Build the optimized bundle and disk image:
   ```bash
   make release
   make dmg
   ```
3. Push the tag to publish (CI rebuilds, tests, and attaches the `.dmg` to the release):
   ```bash
   git push origin vX.Y.Z
   ```

## Launch at login (persist across reboots)

The app is a background agent (`LSUIElement`) — no dock icon, menu bar only — so the standard Login Items flow applies:

1. Move `OpenCode Usage.app` into `/Applications` (from `build/Release/` or by opening the `.dmg`).
2. Open **System Settings → General → Login Items**.
3. Under **Open at Login**, click **+**, select **OpenCode Usage**, and click **Open**.

The usage icon will now appear in the menu bar automatically after every reboot. To remove it later, select it in the same list and click **−**.

## License

MIT License
