# apple-cli

A unified command-line interface for interacting with Apple apps on macOS via AppleScript.

## Overview

`apple-cli` provides a simple, consistent CLI to interact with native macOS applications:

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
git clone https://github.com/andrewfurman/apple-cli.git
cd apple-cli

# Install (adds `apple` command to your PATH)
./install.sh
```

## Usage

```bash
# Mail
apple mail list                          # List recent emails
apple mail search "from:boss subject:urgent"
apple mail send "user@example.com" "Subject" "Body"
apple mail accounts                      # List all mail accounts

# Notes
apple notes list                         # List all notes
apple notes create "Title" "Content"
apple notes search "meeting"
apple notes read "Note Title"

# Calendar
apple calendar today                     # Today's events
apple calendar week                      # This week's events
apple calendar create "Meeting" "2024-02-01 10:00" "1 hour"
apple calendar list                      # List all calendars

# Messages
apple messages send "+15551234567" "Hello!"
apple messages list                      # Recent conversations
apple messages read "John Doe"           # Messages from contact

# Music
apple music play
apple music pause
apple music next
apple music now                          # Current track info
apple music search "artist:Beatles"

# Photos
apple photos albums                      # List all albums
apple photos list "Album Name"           # Photos in album
apple photos export "Album Name" ~/Desktop/export

# Reminders
apple reminders list
apple reminders create "Buy groceries" --due "tomorrow 5pm"
apple reminders complete "Buy groceries"

# Contacts
apple contacts search "John"
apple contacts show "John Doe"

# Home (HomeKit via Shortcuts)
apple home setup                         # Install preloaded shortcuts
apple home list                          # List available scenes/devices
apple home run "Good Night"              # Run a scene
apple home "Living Room Lights" off
apple home "Thermostat" 72

# FaceTime
apple facetime "+15551234567"            # Start video call
apple facetime "user@icloud.com" --audio # Audio only
```

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
2. **Auto-Install**: Running `apple home setup` imports these shortcuts into your Shortcuts app
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
3. The CLI will detect and use it: `apple home run "My Shortcut"`

#### How Shortcut Auto-Install Works

When you run `apple home setup`, the CLI:

1. Scans `scripts/shortcuts/` for `.shortcut` files
2. Signs each shortcut (required by macOS)
3. Imports them via `shortcuts import <file>`
4. Verifies installation with `shortcuts list`

```bash
$ apple home setup
Installing HomeKit shortcuts...
  ✓ homekit-lights-on
  ✓ homekit-lights-off
  ✓ homekit-good-morning
  ✓ homekit-good-night
  ✓ homekit-thermostat-set
  ✓ homekit-lock-doors
  ✓ homekit-scene-runner
Done! Run 'apple home list' to see available commands.
```

## Output Formats

```bash
# Default: Human-readable
apple mail list

# JSON output (for scripting)
apple mail list --json

# Quiet mode (minimal output)
apple mail send "user@example.com" "Subject" "Body" --quiet
```

## Configuration

Optional config file at `~/.apple-cli/config.toml`:

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
apple-cli/
├── README.md
├── install.sh
├── apple                    # Main CLI entry point (bash or python)
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
