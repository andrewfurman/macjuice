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
macjuice mail search "insurify"                         # All fields, all mailboxes
macjuice mail search "from:boss"                        # Sender only (fast)
macjuice mail search "subject:urgent"                   # Subject only (fast)
macjuice mail search "to:client@example.com"            # Recipient search
macjuice mail search "body:contract"                    # Body content (slower)
macjuice mail search "insurify" --account andrew@ad-ga.com  # Specific account
macjuice mail read <message-id>                      # Read a specific email
macjuice mail send "user@example.com" "Subject" "Body"   # Send an email
macjuice mail send "user@example.com" "Subject" "Body" --from=me@icloud.com  # Send from specific account
macjuice mail draft "user@example.com" "Subject" "Body"  # Save email as draft
macjuice mail draft "user@example.com" "Subject" "Body" --from=me@icloud.com  # Draft from specific account
macjuice mail draft "user@example.com" "Subject" "Body" --cc=a@x.com --bcc=b@x.com  # Draft with CC/BCC
macjuice mail draft "user@example.com" "Subject" "Body" --cc=a@x.com,b@x.com  # Draft with multiple CC
macjuice mail draft "user@example.com" "Subject" "Body" /path/to/file.pdf  # Draft with attachment (UNRELIABLE - see note below)
macjuice mail html-draft "user@example.com" "Subject" /path/to/file.html  # Draft with HTML body (opens compose, pastes from clipboard)
macjuice mail html-draft "user@example.com" "Subject" "<h1>Hello</h1><p>World</p>"  # Draft with inline HTML string
macjuice mail html-draft "user@example.com" "Subject" /path/to/file.html --from=me@icloud.com --cc=a@x.com  # HTML draft with from/CC/BCC
# NOTE: html-draft requires PyObjC/AppKit for its Python helper (mail_html_clipboard.py).
# If AppKit is not available, see the "HTML Email Workaround (without AppKit)" in Common Patterns below.
macjuice mail reply <message-id> "Reply body"          # Reply-all (saves as draft)
macjuice mail reply <message-id> "Reply body" --from=me@icloud.com  # Reply from specific account
macjuice mail reply <message-id> "Reply body" --cc=extra@x.com,other@x.com  # Reply with extra CC
macjuice mail reply <message-id> "Reply body" --bcc=hidden@x.com  # Reply with BCC
macjuice mail reply --search "subject query" "Reply body"  # Search and reply
macjuice mail forward <message-id> "user@example.com"    # Forward a message (saves as draft)
macjuice mail forward <message-id> "user@example.com" --from=me@icloud.com  # Forward from specific account
macjuice mail forward <message-id> "user@example.com" --body="See below"  # Forward with body text prepended
macjuice mail forward <message-id> "user@example.com" --cc=a@x.com --bcc=b@x.com  # Forward with CC/BCC
macjuice mail attach <message-id> /path/to/file1.png /path/to/file2.pdf  # Attach files to an existing draft
macjuice mail delete-draft <message-id>                   # Delete a draft by ID
```

Use `macjuice mail list Drafts` to find draft message IDs for deletion.

**IMPORTANT: Attaching files to drafts requires a two-step process.** Passing attachment paths as positional args to `macjuice mail draft` is unreliable (the attachment often silently fails to attach). Instead, use:

```bash
# Step 1: Create the draft without attachment
macjuice mail draft "to@example.com" "Subject" "Body" --from=me@example.com --cc=a@x.com

# Step 2: Find the draft ID and attach separately
macjuice mail list "Drafts"   # get the ID of the draft you just created
macjuice mail attach <draft-id> /path/to/file.pdf
```

This two-step approach works reliably every time.

The `--cc` and `--bcc` flags accept comma-separated email addresses for multiple recipients.

The `--from=` flag controls which mail account is used, which determines which Drafts folder the draft is saved to (e.g., iCloud's "Cloud Drafts"). Use `macjuice mail accounts` to see available account addresses.

### Calendar

```bash
macjuice calendar list                     # List all calendars
macjuice calendar today                    # Today's events
macjuice calendar yesterday                # Yesterday's events
macjuice calendar week                     # This week's events (next 7 days)
macjuice calendar upcoming 14              # Next 14 days of events
macjuice calendar past 7                   # Past 7 days of events
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
macjuice music open "Live Sheck Wes"       # Search Apple Music catalog and play
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
│   ├── mail.applescript      # Mail: list, search, read, send, draft, reply, delete-draft
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

**Creating an email draft from a specific account:**
```bash
macjuice mail draft "recipient@example.com" "Subject line" "Email body text here" --from=me@icloud.com
```

**HTML Email Workaround (without AppKit):**

The preferred approach for HTML emails is `macjuice mail html-draft`, but it depends on a Python helper (`mail_html_clipboard.py`) that requires PyObjC/AppKit, which isn't always available in every Python environment.

If AppKit is not available, use this two-step workaround:

**Step 1 — Load HTML as RTF into the clipboard using Swift:**
```bash
swift -e '
import Cocoa
let html = try! String(contentsOfFile: "/path/to/email.html", encoding: .utf8)
let data = html.data(using: .utf8)!
let attrStr = NSAttributedString(html: data, documentAttributes: nil)!
let rtfData = attrStr.rtf(from: NSRange(location: 0, length: attrStr.length), documentAttributes: [:])!
let pasteboard = NSPasteboard.general
pasteboard.clearContents()
pasteboard.setData(rtfData, forType: .rtf)
print("OK")
'
```

**Step 2 — Create a compose window and paste via AppleScript:**
```bash
osascript -e '
tell application "Mail"
    activate
    set newMessage to make new outgoing message with properties {subject:"Subject", content:" ", sender:"from@example.com", visible:true}
    tell newMessage
        make new to recipient at end of to recipients with properties {address:"to@example.com"}
        make new cc recipient at end of cc recipients with properties {address:"cc@example.com"}
    end tell
end tell
delay 2
tell application "System Events"
    tell process "Mail"
        set frontmost to true
        delay 0.5
        keystroke tab
        delay 0.3
        keystroke tab
        delay 0.3
        keystroke tab
        delay 0.3
        keystroke tab
        delay 0.3
        keystroke "a" using command down
        delay 0.3
        keystroke "v" using command down
    end tell
end tell
'
```

The Swift step converts HTML to RTF and places it on the clipboard. The AppleScript step opens a new compose window, tabs into the body field, selects all placeholder content, and pastes the formatted HTML from the clipboard. Replace the addresses, subject, and file path with actual values.

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

## Dependencies

MacJuice does **not** use himalaya or any external IMAP CLI tools. It exclusively interacts with Apple Mail.app via AppleScript for all mail operations: reading, searching, sending, drafting, replying, and deleting drafts. No third-party packages or external tools are required.

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
