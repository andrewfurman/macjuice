# macjuice

A unified command-line interface for interacting with Apple apps on macOS via AppleScript.

## Overview

`macjuice` provides a simple, consistent CLI to interact with native macOS applications:

- **Mail** - Search, read, send, and organize emails across all accounts (Exchange, Office 365, Gmail, etc.)
- **Notes** - Create, list, search, and read notes
- **Calendar** - View events, create appointments, manage calendars
- **Messages** - Send and read iMessages/SMS
- **Music** - Control playback, search library, manage playlists
- **Photos** - List albums, export photos, search by date
- **Reminders** - Create and manage reminders
- **Contacts** - Search and manage contacts
- **Home** - Control HomeKit devices via preloaded Shortcuts (see below)
- **FaceTime** - Initiate calls

## Installation

```bash
# Clone the repo
git clone https://github.com/andrewfurman/macjuice.git
cd macjuice

# Install (adds `macjuice` command to your PATH)
./install.sh
```

## Usage

```bash
# Mail
macjuice mail list                          # List recent emails
macjuice mail search "from:boss subject:urgent"
macjuice mail send "user@example.com" "Subject" "Body"
macjuice mail accounts                      # List all mail accounts

# Notes
macjuice notes list                         # List all notes
macjuice notes create "Title" "Content"
macjuice notes search "meeting"
macjuice notes read "Note Title"

# Calendar
macjuice calendar today                     # Today's events
macjuice calendar week                      # This week's events
macjuice calendar create "Meeting" "2024-02-01 10:00" "1 hour"
macjuice calendar list                      # List all calendars

# Messages (reads via SQLite — instant!)
macjuice messages chats                     # List all chats with last message
macjuice messages recent                    # Recent messages across all chats
macjuice messages read "+15551234567"       # Read messages from a chat
macjuice messages read "John Doe" 50        # Last 50 messages from contact
macjuice messages search "dinner"           # Search all message text
macjuice messages send "+15551234567" "Hello!"  # Send via AppleScript
macjuice messages info                      # Database stats

# Music
macjuice music play
macjuice music pause
macjuice music next
macjuice music now                          # Current track info
macjuice music search "artist:Beatles"

# Photos
macjuice photos albums                      # List all albums
macjuice photos list "Album Name"           # Photos in album
macjuice photos export "Album Name" ~/Desktop/export

# Reminders
macjuice reminders list
macjuice reminders create "Buy groceries" --due "tomorrow 5pm"
macjuice reminders complete "Buy groceries"

# Contacts
macjuice contacts search "John"
macjuice contacts show "John Doe"

# Home (HomeKit via Shortcuts)
macjuice home setup                         # Install preloaded shortcuts
macjuice home list                          # List available scenes/devices
macjuice home run "Good Night"              # Run a scene
macjuice home "Living Room Lights" off
macjuice home "Thermostat" 72

# FaceTime
macjuice facetime "+15551234567"            # Start video call
macjuice facetime "user@icloud.com" --audio # Audio only
```

## Full Disk Access (Required for Messages)

The Messages module reads directly from the iMessage SQLite database (`~/Library/Messages/chat.db`) for fast, reliable access to your full message history. This requires **Full Disk Access** for your terminal app.

### Setup

1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Click the **+** button
3. Navigate to `/Applications/Utilities/Terminal.app` (or your terminal of choice)
4. Click **Open** and make sure the toggle is **on**
5. **Restart your terminal** for changes to take effect

> **Note:** macOS won't accept raw binaries like `node` or `bash` — you must add the `.app` bundle (Terminal.app, iTerm.app, etc.). If you run commands over SSH, also add `/usr/sbin/sshd`.

### Why SQLite instead of AppleScript?

| | AppleScript | SQLite (chat.db) |
|---|---|---|
| **Speed** | Slow (iterates chats via IPC) | Instant (direct DB queries) |
| **Reliability** | Flaky on modern macOS | Rock solid |
| **History** | Limited to open chats | Full history (all 188k+ messages) |
| **Search** | Very slow | Sub-second |
| **Sending** | ✅ Works | ❌ Read-only |

MacJuice uses **SQLite for all read operations** (chats, read, recent, search) and **AppleScript only for sending** messages.

## How It Works

### AppleScript Layer

Each Apple app has a corresponding AppleScript file in `scripts/`:

```
scripts/
├── mail.applescript
├── notes.applescript
├── calendar.applescript
├── messages.applescript
├── music.applescript
├── photos.applescript
├── reminders.applescript
├── contacts.applescript
└── home.applescript
```

The CLI invokes these scripts via `osascript` and parses the output.

### HomeKit / Home App Integration

Apple's Home app has **no AppleScript support**. We work around this using macOS Shortcuts:

1. **Preloaded Shortcuts**: The `scripts/shortcuts/` folder contains `.shortcut` files for common HomeKit actions
2. **Auto-Install**: Running `macjuice home setup` imports these shortcuts into your Shortcuts app
3. **CLI Invocation**: The CLI calls shortcuts via the `shortcuts` command-line tool

#### Preloaded Shortcuts

```
scripts/shortcuts/
├── homekit-lights-on.shortcut
├── homekit-lights-off.shortcut
├── homekit-good-morning.shortcut
├── homekit-good-night.shortcut
├── homekit-thermostat-set.shortcut
├── homekit-lock-doors.shortcut
└── homekit-scene-runner.shortcut    # Generic scene runner
```

#### Creating Custom Shortcuts

You can add your own HomeKit shortcuts:

1. Create the shortcut in Shortcuts.app with your HomeKit actions
2. Export it: `shortcuts export "My Shortcut" -o scripts/shortcuts/`
3. The CLI will detect and use it: `macjuice home run "My Shortcut"`

#### How Shortcut Auto-Install Works

When you run `macjuice home setup`, the CLI:

1. Scans `scripts/shortcuts/` for `.shortcut` files
2. Signs each shortcut (required by macOS)
3. Imports them via `shortcuts import <file>`
4. Verifies installation with `shortcuts list`

```bash
$ macjuice home setup
Installing HomeKit shortcuts...
  ✓ homekit-lights-on
  ✓ homekit-lights-off
  ✓ homekit-good-morning
  ✓ homekit-good-night
  ✓ homekit-thermostat-set
  ✓ homekit-lock-doors
  ✓ homekit-scene-runner
Done! Run 'macjuice home list' to see available commands.
```

## Output Formats

```bash
# Default: Human-readable
macjuice mail list

# JSON output (for scripting)
macjuice mail list --json

# Quiet mode (minimal output)
macjuice mail send "user@example.com" "Subject" "Body" --quiet
```

## Configuration

Optional config file at `~/.macjuice/config.toml`:

```toml
[mail]
default_account = "Work Exchange"

[calendar]
default_calendar = "Personal"

[home]
shortcuts_folder = "HomeKit"  # Shortcuts folder name

[output]
format = "text"  # or "json"
```

## Requirements

- macOS 12.0+ (Monterey or later)
- Shortcuts app (for HomeKit integration)
- Full Disk Access permission (for some apps)
- Accessibility permission (for UI automation fallbacks)

## Permissions

On first run, macOS will prompt for permissions. Grant access to:

- **Automation** - Required for AppleScript to control apps
- **Full Disk Access** - Required for Mail and Photos access
- **Contacts** - Required for Contacts app access

## Project Structure

```
macjuice/
├── README.md
├── install.sh
├── macjuice                 # Main CLI entry point (bash or python)
├── scripts/
│   ├── mail.applescript
│   ├── notes.applescript
│   ├── calendar.applescript
│   ├── messages.applescript
│   ├── music.applescript
│   ├── photos.applescript
│   ├── reminders.applescript
│   ├── contacts.applescript
│   ├── home.applescript     # Shortcuts wrapper
│   └── shortcuts/
│       ├── homekit-lights-on.shortcut
│       ├── homekit-lights-off.shortcut
│       └── ...
├── lib/
│   ├── parser.sh            # Output parsing utilities
│   └── config.sh            # Config file handling
└── tests/
    └── test_mail.sh
```

## Contributing

1. Fork the repo
2. Create a feature branch
3. Add your AppleScript to `scripts/`
4. Update the CLI to support new commands
5. Submit a PR

## License

MIT

## Acknowledgments

- Inspired by [applescript-mcp](https://github.com/joshrutkowski/applescript-mcp)
- HomeKit integration approach from [Apple's Shortcuts CLI documentation](https://support.apple.com/guide/shortcuts-mac/run-shortcuts-from-the-command-line-apd455c82f02/mac)
