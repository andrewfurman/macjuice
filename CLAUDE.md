# CLAUDE.md - macjuice CLI Reference

## What is macjuice?

A bash CLI that controls native macOS apps via AppleScript. Each app has a `.applescript` file in `scripts/` that gets invoked through the main `macjuice` entry point using `osascript`.

## Installation

```bash
cd /Users/andrewfurman/repos/personal/macjuice
./install.sh
```

This adds `macjuice` to PATH.

## Command Reference

### Mail

```bash
macjuice mail accounts                              # List all mail accounts
macjuice mail list                                   # List recent inbox emails
macjuice mail list "Drafts"                          # List messages in a specific mailbox
macjuice mail search "from:boss subject:urgent"      # Search emails
macjuice mail read <message-id>                      # Read a specific email
macjuice mail send "user@example.com" "Subject" "Body"   # Send an email
macjuice mail draft "user@example.com" "Subject" "Body"  # Save email as draft
```

### Calendar

```bash
macjuice calendar list                     # List all calendars
macjuice calendar today                    # Today's events
macjuice calendar week                     # This week's events
macjuice calendar upcoming 14              # Next 14 days of events
macjuice calendar search "CoverNode"       # Search events by title
macjuice calendar create "Meeting" "2026-02-01 10:00" "1h"           # Create event
macjuice calendar create "Meeting" "2026-02-01 10:00" "30m" "Work"   # Create in specific calendar
macjuice calendar delete "Meeting Title"   # Delete event by title
```

**Known issue:** Some calendars (Exchange, subscribed) may time out. The script handles this gracefully by skipping slow calendars and showing a warning.

### Notes

```bash
macjuice notes list                        # List all notes
macjuice notes folders                     # List all folders
macjuice notes create "Title" "Content"    # Create a new note
macjuice notes read "Note Title"           # Read a note by title
macjuice notes search "meeting"            # Search notes
```

### Messages (iMessage/SMS)

```bash
macjuice messages chats                    # List all chats
macjuice messages send "+15551234567" "Hello!"        # Send by phone number
macjuice messages send "John Smith" "Hey!"            # Send by contact name
macjuice messages read "John Doe" 20                  # Read last 20 messages from contact
macjuice messages recent 10                            # Show 10 most recent messages
macjuice messages search "keyword"                     # Search messages
```

### Music

```bash
macjuice music play                        # Start playback
macjuice music play "The Lounge"           # Play a specific playlist
macjuice music pause                       # Pause playback
macjuice music toggle                      # Toggle play/pause
macjuice music next                        # Next track
macjuice music previous                    # Previous track
macjuice music now                         # Current track info
macjuice music volume 75                   # Set volume (0-100)
macjuice music playlists                   # List playlists
macjuice music search "Beatles"            # Search library
```

### Contacts

```bash
macjuice contacts list                     # List contacts
macjuice contacts search "John"            # Search contacts
macjuice contacts show "John Doe"          # Show contact details
macjuice contacts groups                   # List contact groups
macjuice contacts add "John" "Doe" "john@example.com" "+15551234567"
macjuice contacts email "John Doe"         # Get contact's email
macjuice contacts phone "John Doe"         # Get contact's phone
```

### Reminders

```bash
macjuice reminders lists                   # List all reminder lists
macjuice reminders list "Groceries"        # List reminders in a specific list
macjuice reminders all                     # All incomplete reminders
macjuice reminders today                   # Reminders due today
macjuice reminders overdue                 # Overdue reminders
macjuice reminders add "Buy milk" "Groceries" "tomorrow 5pm"
macjuice reminders complete "Buy milk"     # Mark as complete
macjuice reminders delete "Buy milk"       # Delete a reminder
macjuice reminders search "milk"           # Search reminders
```

### Home (HomeKit via Shortcuts)

```bash
macjuice home setup                        # Install HomeKit shortcuts
macjuice home list                         # List available shortcuts
macjuice home run "Good Night"             # Run a scene/shortcut
```

Requires Shortcuts app. HomeKit has no AppleScript support, so this works via preloaded `.shortcut` files in `scripts/shortcuts/`.

### FaceTime

```bash
macjuice facetime "+15551234567"           # Video call
macjuice facetime "user@icloud.com" audio  # Audio-only call
```

## Architecture

```
macjuice/
├── macjuice                  # Main bash entry point - routes commands to scripts
├── scripts/
│   ├── mail.applescript      # Mail: list, search, read, send, draft
│   ├── calendar.applescript  # Calendar: today, week, upcoming, search, create, delete
│   ├── notes.applescript     # Notes: list, folders, create, read, search
│   ├── messages.applescript  # Messages: chats, send, read, recent, search
│   ├── music.applescript     # Music: play, pause, toggle, next, previous, now, volume
│   ├── contacts.applescript  # Contacts: list, search, show, groups, add, email, phone
│   ├── reminders.applescript # Reminders: lists, list, all, today, overdue, add, complete
│   ├── home.applescript      # Home: shortcuts wrapper
│   ├── home-setup.sh         # HomeKit shortcuts installer
│   └── shortcuts/            # Preloaded .shortcut files for HomeKit
├── lib/                      # Shared utilities (unused currently)
├── tests/                    # Test scripts per app
└── install.sh                # Adds macjuice to PATH
```

## How It Works

1. User runs `macjuice <app> <command> [args]`
2. Main bash script routes to `scripts/<app>.applescript`
3. AppleScript runs via `osascript` and interacts with the native macOS app
4. Output returned as plain text (or `--json` for structured output)

## Common Patterns When Using macjuice

**Creating an email draft:**
```bash
macjuice mail draft "recipient@example.com" "Subject line" "Email body text here"
```

**Checking today's schedule:**
```bash
macjuice calendar today
```

**Sending a quick iMessage:**
```bash
macjuice messages send "Contact Name" "Message text"
```

## Permissions

On first run, macOS will prompt for:
- **Automation** - Required for AppleScript to control apps
- **Full Disk Access** - Required for Mail and Photos
- **Contacts** - Required for Contacts access

## Troubleshooting

- **Calendar timeouts:** Some Exchange/subscribed calendars are slow. The script skips them after 15 seconds per calendar and shows a warning.
- **Permission denied:** Grant Automation permissions in System Settings > Privacy & Security > Automation.
- **"command not found: macjuice":** Run `./install.sh` to add to PATH, then restart your terminal.

## Config

Optional config at `~/.macjuice/config.toml`:

```toml
[mail]
default_account = "Work Exchange"

[calendar]
default_calendar = "Personal"

[output]
format = "text"  # or "json"
```
