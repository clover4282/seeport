# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build
swift build

# Build and run as macOS app bundle (creates .build/seeport.app)
./run.sh
```

`run.sh` compiles, creates an app bundle at `.build/seeport.app`, copies `Info.plist`, code-signs ad-hoc, and opens the app.

**Requirements:** Swift 5.9+, macOS 13+, Zsh. Docker CLI optional (for container detection).

## Environment

Copy `.env.example` to `.env` and fill in Paddle credentials. In dev mode (no credentials), any non-empty license key is accepted.

## Architecture

Seeport is a **macOS menu bar app** (`MenuBarExtra` + `LSUIElement: true`) for monitoring listening TCP ports and Docker containers.

### Data Flow

`PortListViewModel` is the central state holder. It runs an async scan loop:

1. **PortScanner** (actor) — executes `lsof -iTCP -sTCP:LISTEN -nP -F pcnf`, parses field-based output into `PortInfo` structs
2. **DockerService** (actor) — runs `docker ps --format` to detect containers and parse port mappings
3. **CategoryEngine** — multi-stage port classification: user overrides → Docker flag → system commands → process name regex → port number ranges
4. **ProcessService** — retrieves app icons via `NSRunningApplication`/`NSWorkspace`, handles process killing
5. **LicenseManager** — 30-day trial via `UserDefaults` first-launch date, Paddle API for activation/verification

### Web Server

Optional HTTP server on port 7777 using Network framework (`NWListener`). Serves HTML UI at `/`, JSON API at `/api/ports`, and supports process kill/favorite toggle via POST.

### Persistence

All state uses `UserDefaults.standard` with `seeport.*` key prefix — favorites, category overrides, settings, license state. No Core Data or external database.

## Key Patterns

- **Actor concurrency** — `PortScanner` and `DockerService` are Swift actors for thread-safe scanning
- **Shell execution** — `ShellExecutor` wraps `Process` with Zsh; both sync (`run`) and async (`runAsync`) variants
- **Graceful degradation** — missing Docker CLI returns empty containers, shell failures return empty string
- **Constants centralization** — colors, fonts, spacing, dimensions in `Constants.swift`
- **Dark theme** — background RGB(0.11, 0.11, 0.13) with blue/cyan accent throughout
- **No external dependencies** — pure Swift/SwiftUI, no SPM packages

## UI Structure

`MainPopoverView` (420×600px popover) → HeaderView + SearchBarView + FilterTabsView (All/Docker/Favorites) + PortListView + StatusBarView. Settings is a separate 4-tab view (General/Display/License/About).

## Bundle Info

- Bundle ID: `com.seeport.app`
- Architecture: arm64 (Apple Silicon)
- App icon: programmatically generated via Core Graphics in `SeeportApp.swift`
