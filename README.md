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
macjuice <app> <command> [arguments]
```

### Getting help

Every level has built-in help with copy-pasteable examples. Help works anywhere (it never calls AppleScript).

```bash
macjuice --help                  # All apps, common examples, safety notes
macjuice mail --help             # Every command of one app
macjuice mail send --help        # One command: each argument, defaults, examples
macjuice help mail send          # Same as the line above
```

`-h` and `--help` print the same text. A missing argument or unknown command prints a short error, a usage line, an example, and the `--help` command to run next.

**Safety:** there is no `--yes` flag and no confirmation prompt. `mail send`, `messages send`, `calendar delete`, `reminders delete`, `mail delete-draft` and `shortcuts run` act immediately. Use `mail draft` to review an email before sending.

### Common tasks

```bash
# Mail
macjuice mail accounts                                   # Addresses you can use with --from
macjuice mail list                                       # Recent inbox messages (IDs in the first column)
macjuice mail search "from:jane@example.com"             # Prefixes: from:, to:, subject:, body:
macjuice mail search "invoice" --account jane@contoso.com
macjuice mail read 12345                                 # Read one message by ID
macjuice mail draft "jane@example.com" "Lunch?" "Free at noon?" --from=me@contoso.com
macjuice mail reply 12345 "Thanks!"                      # Reply-all, saved as a draft
macjuice mail forward 12345 "jane@example.com" --body="FYI" --cc=bob@fabrikam.com
macjuice mail attach 12345 /tmp/report.pdf               # Attach to an existing draft
macjuice mail send "jane@example.com" "Hi" "Body"        # Sends immediately

# Calendar
macjuice calendar today                                  # Also: yesterday, week, upcoming 14, past 7
macjuice calendar search "dentist" --future=30
macjuice calendar create "Team sync" "2026-03-01 14:00" 30m "Work"
macjuice calendar delete "Team sync"                     # Deletes immediately

# Messages (reads via SQLite, needs Full Disk Access)
macjuice messages chats
macjuice messages read "Jane Doe" 50
macjuice messages search "dinner"
macjuice messages send "+15555550123" "Hello!"           # Sends immediately

# Notes, Reminders, Contacts
macjuice notes create "Shopping list" "Milk, eggs, bread"
macjuice notes read "Shopping list"
macjuice reminders add "Buy milk" "Groceries" tomorrow   # due: today, tomorrow, 5pm, next week, a date
macjuice reminders complete "Buy milk"
macjuice contacts add "Jane" "Doe" "jane@example.com" "+15555550123"
macjuice contacts email "Jane Doe"

# Music and Photos
macjuice music open "Yesterday by The Beatles"           # Search the Apple Music catalog and play
macjuice music volume 40
macjuice photos recent 10 --since 1w
macjuice photos search person:Jane --since 2026-03-09
macjuice photos export "beach" ~/Desktop/beach-photos

# Shortcuts, Home, FaceTime
macjuice shortcuts run "Morning Routine"
macjuice home setup                                      # Install preloaded HomeKit shortcuts
macjuice home run "homekit-lock-doors"
macjuice facetime audio "+15555550123"                   # Or: facetime call <number-or-email>
```

## HTML Email Drafts

The `html-draft` command lets you compose rich HTML emails (tables, formatted text, images) in Apple Mail. It accepts either an HTML file path or an inline HTML string.

```bash
# From an HTML file
macjuice mail html-draft "user@example.com" "Monthly Report" /path/to/report.html

# From an inline HTML string
macjuice mail html-draft "user@example.com" "Hello" "<h1>Welcome</h1><p>Thanks for signing up!</p>"

# With sender, CC, and BCC
macjuice mail html-draft "user@example.com" "Report" report.html --from=me@work.com --cc=boss@work.com --bcc=archive@work.com
```

**How it works:** The command converts your HTML to RTF, loads it onto the clipboard, and opens a compose window with recipients pre-filled. You then click the email body and press **Cmd+V** to paste the formatted content.

**Tip for automation (e.g. Claude Code):** After calling `html-draft`, you can programmatically Tab into the body and paste using AppleScript/System Events to skip the manual step.

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

Output is plain text, meant to be read in the terminal or piped to other tools (for example `macjuice contacts email "Jane Doe" | pbcopy`). There is no JSON or quiet mode yet.

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
