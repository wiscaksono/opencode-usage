# OpenCode Usage Monitor

[![CI](https://github.com/wiscaksono/opencode-usage/actions/workflows/ci.yml/badge.svg)](https://github.com/wiscaksono/opencode-usage/actions/workflows/ci.yml)

A native macOS Menu Bar application built with SwiftUI to easily monitor your Opencode Go subscription usage (Rolling, Weekly, and Monthly limits).

![App Screenshot](assets/screenshot.png)

## Features

- **Real-Time Monitoring**: View your Rolling, Weekly, and Monthly usage directly from the menu bar.
- **Smart Progress Bars**: Progress bar colors dynamically change based on usage levels (Green for safe, Yellow for medium, Red for critical).
- **Zero-Config Credentials**: Uses the OpenCode sign-in token already stored by the OpenCode app. No API key needed unless you want to override it.
- **24h History**: A monthly sparkline is built from local samples taken every refresh.
- **Auto-Refresh**: Automatically fetches new data every 5 minutes, or you can manually refresh.
- **Lightweight**: Runs as a background agent (`LSUIElement`) with no dock icon clutter.
- **Terminal-Driven**: No Xcode GUI required. Built with plain SwiftPM and a `Makefile`.

## Prerequisites

- macOS 26+
- Xcode 26+ (SwiftUI macros require the full Xcode toolchain; Command Line Tools alone are not enough to build)
- OpenCode signed in to OpenCode Console with a Go / Go Plus / Go Teams plan, or an `sk-...` API key

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

## Credentials

The app uses the official OpenCode API (`https://opencode.ai/zen/go/v1/usage`) to fetch your usage.

By default it reads the OAuth access token from the local OpenCode database
(`~/.local/share/opencode/opencode.db`, table `credential`), so if you are
already signed in to OpenCode there is nothing to configure.

To override it with a dedicated API key:

1. Open your OpenCode console.
2. Go to **Settings** → **API Keys**.
3. Copy your API key (starts with `sk-...`).
4. Open the **OpenCode Usage Monitor** from your Mac menu bar.
5. Click the **Settings (⚙️)** icon in the top right corner of the header.
6. Paste your API key into the text field and click **Save**.

The API key wins over the OpenCode token. If neither is available, the setup
screen is shown.

Usage history is stored in `~/Library/Application Support/OpenCode Usage/history.json`
(percentages only, last 24 hours).

## Development Commands

A `Makefile` is provided for easy terminal workflows:

- `make build`: Builds the application and assembles the app bundle (Debug configuration).
- `make run`: Kills any existing instance, builds, and runs the app.
- `make clean`: Removes the `.build/` and `build/` directories.
- `make test`: Runs the unit test suite ([Swift Testing](https://developer.apple.com/xcode/swift-testing/)).
- `make format`: Formats the codebase with [SwiftFormat](https://github.com/nicklockwood/SwiftFormat).
- `make logs`: Streams the unified logs specifically for this app subsystem (`com.wiscaksono.opencode-usage`).

## Releases

Pre-built `.dmg` images are published automatically on every version tag — grab the latest one from [Releases](https://github.com/wiscaksono/opencode-usage/releases).

> The app is ad-hoc signed, so macOS Gatekeeper may warn on first launch. Right-click the app → **Open** once to allow it.

## License

MIT License
