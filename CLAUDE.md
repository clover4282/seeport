# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
make build          # swift build
make run            # Build → bundle → kill old process → open app
make debug          # Build → bundle → run in foreground (stdout/stderr visible)
make dev            # Watch mode: auto-rebuild on .swift changes (requires fswatch)
make clean          # swift package clean + remove artifacts
```

**Release:**
```bash
make release VERSION=1.4   # Bundle → ZIP → Sparkle signature
make deploy VERSION=1.4    # release + gh release create
```

After deploy, update `appcast.xml` on `gh-pages` branch with the Sparkle signature output.

**Testing:** `make test-servers` starts Python HTTP servers on 8080/3000/9999 for port scanning verification.

**Requirements:** Swift 5.9+, macOS 13+, Zsh. Docker CLI optional (for container detection).

## Environment

Copy `.env.example` to `.env` and fill in Paddle credentials. In dev mode (no credentials), any non-empty license key is accepted.

## Architecture

Seeport is a **macOS menu bar app** (`MenuBarExtra` + `LSUIElement: true`) for monitoring listening TCP ports and Docker containers. Single SPM dependency: Sparkle (auto-update).

### Data Flow

`PortListViewModel` (@MainActor) is the central state holder. It runs an async scan loop:

1. **PortScanner** (actor) — executes `lsof -iTCP -sTCP:LISTEN -nP -F pcnf`, parses field-based output into `PortInfo` structs
2. **DockerService** (actor) — runs `docker ps --format` to detect containers and parse port mappings
3. **CategoryEngine** — multi-stage port classification: user overrides → Docker flag → system commands → process name regex → port number ranges → 6 categories (Frontend/Backend/Database/Docker/System/Other)
4. **ProcessService** — retrieves app icons via `NSRunningApplication`/`NSWorkspace`, gets working directory via `lsof -a -d cwd`, handles process killing
5. **LicenseManager** — 30-day trial via `UserDefaults` first-launch date, Paddle API for activation/verification

### Background Refresh

Auto-refresh timer only runs when **both** `autoRefreshEnabled` is true **and** notification permission is authorized. When the popover opens, a manual refresh is always triggered via `onAppear`.

### Notifications

Per-category notification filtering via `SettingsManager`: `notifyLocalPorts` (Frontend/Backend/Database), `notifyDockerPorts`, `notifySystemPorts`, `notifyOtherPorts`. Event toggles: `notifyNewPort`, `notifyRemovedPort`.

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
- **No external dependencies** — pure Swift/SwiftUI, no SPM packages (except Sparkle)
- **Settings window** — `SettingsWindowController` manages a floating `NSWindow` with `NSHostingView`, not a SwiftUI WindowGroup
- **Start at login** — `SMAppService.mainApp` (ServiceManagement framework), no helper app needed. First launch auto-registers.

## UI Structure

`MainPopoverView` (420×600px popover) → HeaderView + SearchBarView + FilterTabsView (All/Local/Docker/Favorites) + PortListView (grouped by category) + StatusBarView. Settings is a separate floating NSWindow with 4 tabs (General/Notifications/Tools/About).

## Bundle Info

- Bundle ID: `com.seeport.app`
- Architecture: arm64 (Apple Silicon)
- App icon: `AppIcon.icns` in Resources/
- Auto-update: Sparkle with appcast.xml hosted on GitHub Pages
