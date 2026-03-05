# Seeport

A lightweight macOS menu bar app for monitoring listening TCP ports and Docker containers in real-time.

<img src="https://img.shields.io/badge/macOS-13+-blue" alt="macOS 13+"> <img src="https://img.shields.io/badge/Swift-5.9+-orange" alt="Swift 5.9+"> <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">

## Overview

Seeport runs in your macOS menu bar and provides instant visibility into what's listening on your local ports. With a single click, see which process owns each port, Docker containers, and manage your network services—all without cluttering your dock.

**Key Features:**
- Real-time port scanning with process detection
- Docker container monitoring and port mapping
- Intelligent port categorization (user overrides → Docker → system commands → regex patterns → ranges)
- Favorites and custom category overrides
- External editor integration (VSCode, Cursor, Zed, Sublime, Atom)
- Shell integration (iTerm2, Terminal, Warp, Alacritty)
- Keyboard shortcuts for common actions
- Optional HTTP server (port 7777) with web UI and JSON API
- Auto-refresh with configurable interval
- New port / port closed notifications
- Sparkle auto-update support

## Getting Started

### Requirements

- macOS 13 or later
- Swift 5.9 or later
- Docker CLI (optional, for container detection)
- `fswatch` (optional, only for `make dev`)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/seeport.git
cd seeport
```

2. Copy environment template (optional, for Paddle licensing):
```bash
cp .env.example .env
# Fill in PADDLE_VENDOR_ID, PADDLE_PRODUCT_ID, PADDLE_VENDOR_AUTH_CODE if using licensing
```

3. Build and run:
```bash
make run
```

The app will build and launch in your menu bar. Click the network icon to open the popover.

## Usage

### Menu Bar Interface

- **Menu Icon**: Network symbol in the macOS menu bar
- **Popover**: 420×600px window showing ports grouped by category
- **Search**: Filter by port number, process name, or category (⌘F)
- **Tabs**: All / Local / Docker / Favorites
- **Refresh**: Manually scan ports (⌘R) or enable auto-refresh in settings
- **Quit**: Exit the app (⌘Q)

### Port Categories

Ports are automatically categorized in this order:

1. **User Overrides** - Custom categories you define
2. **Docker** - Ports mapped from Docker containers
3. **Backend** - Common development ports (3000, 5000, 8000, 8080, etc.)
4. **System** - System services and privileged ports
5. **Other** - All remaining ports

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘R | Refresh ports manually |
| ⌘F | Focus search bar |
| ⌘Q | Quit app |

### Settings

Access settings by clicking the gear icon in the popover header:

**General**
- Auto-refresh enabled/disabled
- Refresh interval (5-60 seconds)

**Display**
- Theme options
- Font size

**External Tools**
- Configure preferred editor (VSCode, Cursor, Zed, Sublime, Atom)
- Configure preferred shell (iTerm2, Terminal, Warp, Alacritty)

**License**
- 30-day free trial
- Paddle license activation

**About**
- Version info and credits

## Development

### Build Commands

```bash
# Build the Swift package
make build

# Build app bundle and launch
make run

# Run in foreground (see stdout/stderr)
make debug

# Watch files and auto-rebuild (requires fswatch)
make dev

# Clean build artifacts
make clean
```

### Release Management

```bash
# Create signed release zip (requires Sparkle signing tools)
make release VERSION=0.2

# Publish release to GitHub (requires gh CLI)
make deploy VERSION=0.2
```

### Testing

```bash
# Start test HTTP servers on ports 8080, 3000, 9999
make test-servers

# Stop test servers
make test-servers-stop
```

## Architecture

### Core Components

**PortListViewModel** - Central state management
- Orchestrates port scanning and Docker detection
- Manages filtering, search, and categorization
- Publishes observable changes to SwiftUI views

**PortScanner** (Swift actor)
- Executes `lsof -iTCP -sTCP:LISTEN -nP -F pcnf` to list listening ports
- Parses field-based output into `PortInfo` structs
- Thread-safe concurrent scanning

**DockerService** (Swift actor)
- Runs `docker ps --format` to detect running containers
- Parses container names and port mappings
- Gracefully handles missing Docker CLI

**CategoryEngine**
- Multi-stage port classification
- Evaluates user overrides → Docker flag → system commands → process regex patterns → port ranges
- Extensible rule-based categorization

**ProcessService**
- Retrieves process metadata via `NSRunningApplication`
- Fetches application icons from NSWorkspace
- Handles process termination

**LicenseManager**
- 30-day free trial tracking via UserDefaults
- Paddle API integration for license activation/verification
- License state persistence

**WebServer** (optional)
- HTTP server on port 7777 using Network framework (NWListener)
- Serves HTML UI at `/`
- JSON API at `/api/ports`
- POST endpoints for process kill and favorite toggle

### Data Flow

```
1. PortScanner (lsof) → PortInfo structs
           ↓
2. DockerService (docker ps) → DockerContainer data
           ↓
3. ProcessService (NSWorkspace) → App icons and process info
           ↓
4. CategoryEngine → Classify ports
           ↓
5. PortListViewModel (Published) → SwiftUI views
           ↓
6. MainPopoverView & WebServer (optional) → User interface
```

### Key Design Patterns

**Actor Concurrency**
- `PortScanner` and `DockerService` are Swift actors for thread-safe background scanning
- Eliminates data races in concurrent port detection

**Shell Execution**
- `ShellExecutor` wraps Foundation's `Process` with Zsh
- Sync (`run`) and async (`runAsync`) variants

**Graceful Degradation**
- Missing Docker CLI returns empty containers (no error)
- Shell command failures return empty string
- App remains functional with partial data

**Constants Centralization**
- Colors, fonts, spacing, dimensions in `Constants.swift`
- Dark theme: background RGB(0.11, 0.11, 0.13) with blue/cyan accent

**Persistence**
- All state stored in `UserDefaults.standard` with `seeport.*` prefix
- Favorites, category overrides, settings, license state
- No Core Data or external database required

### Tech Stack

- **Language**: Pure Swift 5.9+
- **UI Framework**: SwiftUI with AppKit integration
- **Concurrency**: Swift Actors (PortScanner, DockerService)
- **HTTP Server**: Network framework (NWListener)
- **Licensing**: Paddle API
- **Auto-Update**: Sparkle framework
- **External Dependencies**: Sparkle only (for auto-updates)

### Bundle Information

- **Bundle ID**: `com.seeport.app`
- **Architecture**: arm64 (Apple Silicon)
- **Menu Bar Style**: MenuBarExtra with window styling
- **App Icon**: Programmatically generated via Core Graphics
- **Activation Policy**: Accessory (menu bar only, no dock icon)

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
PADDLE_VENDOR_ID=your_vendor_id
PADDLE_PRODUCT_ID=your_product_id
PADDLE_VENDOR_AUTH_CODE=your_auth_code
PADDLE_CHECKOUT_URL=https://buy.paddle.com/product/YOUR_PRODUCT_ID
```

In development mode (no credentials), any non-empty license key is accepted.

### Customization

**Port Categories** - Edit `CategoryEngine.swift` to add custom port ranges or regex patterns.

**Colors & Theme** - Update `Constants.swift` to customize the dark theme.

**Refresh Interval** - Adjustable in Settings (5-60 seconds).

**External Tools** - Configure preferred editor and shell in Settings.

## HTTP API

If enabled, the web server on port 7777 provides:

**GET /api/ports**
Returns JSON array of current listening ports with process info.

**POST /api/ports/{port}/kill**
Terminate the process on a specified port.

**POST /api/ports/{port}/favorite**
Toggle favorite status for a port.

## Files & Structure

```
Sources/seeport/
├── App/
│   └── SeeportApp.swift          # App entry point & delegate
├── Models/
│   ├── PortInfo.swift             # Port data structure
│   ├── PortCategory.swift         # Category enumeration
│   ├── ProcessInfo.swift          # Process metadata
│   └── DockerContainer.swift      # Docker container data
├── Services/
│   ├── PortScanner.swift          # lsof-based port scanning
│   ├── DockerService.swift        # docker ps integration
│   ├── ProcessService.swift       # App icons & termination
│   ├── CategoryEngine.swift       # Port classification
│   ├── LicenseManager.swift       # Trial & Paddle licensing
│   ├── PaddleService.swift        # Paddle API client
│   └── WebServer.swift            # HTTP server on port 7777
├── ViewModels/
│   └── PortListViewModel.swift    # Central state management
├── Views/
│   ├── MainPopoverView.swift      # Root popover
│   ├── PortListView.swift         # Scrollable port list
│   ├── PortCardView.swift         # Individual port card
│   ├── SettingsView.swift         # Settings tabs
│   ├── SearchBarView.swift        # Search input
│   ├── FilterTabsView.swift       # Tab navigation
│   └── Other UI components
├── Utilities/
│   ├── ShellExecutor.swift        # Process wrapper
│   ├── Constants.swift             # Colors, fonts, spacing
│   ├── Favorites.swift             # Favorite management
│   ├── CategoryOverrides.swift     # Custom categories
│   ├── SettingsManager.swift      # Settings persistence
│   ├── LicenseManager.swift       # Trial tracking
│   ├── PaddleConfig.swift         # Paddle credentials
│   ├── PortDatabase.swift         # Port → service mapping
│   └── EnvLoader.swift            # Environment config
└── Resources/
    └── Info.plist                  # App metadata
```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Please submit pull requests to the main branch.

## Support

For issues, feature requests, or questions, open an issue on GitHub or visit the project homepage.

---

**Seeport** - Know what's listening, at a glance.
