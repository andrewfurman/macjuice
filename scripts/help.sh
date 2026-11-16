#!/bin/bash
# help.sh - All help text for macjuice (sourced by the macjuice entry script).
#
# Help is plain text on purpose: it never calls osascript, so it works on any OS.
# Written for bash 3.2 (macOS system bash): no associative arrays.
#
# Layout:
#   mj_registry      one line per command: app|command|min-args|usage|summary
#   mj_cmd_body      per-command Arguments / Options / Notes / Examples
#   mj_top_help      top-level help
#   mj_app_help      "macjuice <app> --help"
#   mj_cmd_help      "macjuice <app> <command> --help"
#
# tests/test_help.sh walks mj_registry (via `macjuice --list-commands`) and fails
# if a command is missing an Examples section or has an undocumented argument/flag.

MJ_APPS="mail messages facetime calendar reminders notes contacts music photos shortcuts home"

# app|command|min-args|usage (after "macjuice <app> <command>")|one-line summary
mj_registry() {
    cat <<'EOF'
mail|accounts|0||List the mail accounts set up in Mail.app
mail|list|0|[<mailbox>]|List recent emails in a mailbox (default INBOX)
mail|search|1|<query> [--account <addresses>]|Search all mailboxes (from:, to:, subject:, body:)
mail|read|1|<message-id>|Print one email (headers and body)
mail|attachments|1|<message-id>|List the attachments on an email
mail|save-attachments|2|<message-id> <directory>|Save an email's attachments into a folder
mail|send|3|<to> <subject> <body> [--from=<address>] [<attachment-path> ...]|SEND an email immediately
mail|draft|3|<to> <subject> <body> [--from=<address>] [--cc=<addresses>] [--bcc=<addresses>]|Save an email as a draft (nothing is sent)
mail|html-draft|3|<to> <subject> <html> [--from=<address>] [--cc=<addresses>] [--bcc=<addresses>]|Open a compose window for a rich HTML email
mail|reply|2|(<message-id> or --search <query>) <body> [--from=<address>] [--cc=<addresses>] [--bcc=<addresses>]|Reply-all to an email and save it as a draft
mail|forward|2|<message-id> <to> [--from=<address>] [--cc=<addresses>] [--bcc=<addresses>] [--body=<text>] [--attach <file> ...]|Forward an email and save it as a draft
mail|attach|2|<message-id> <file> [<file> ...]|Attach files to an existing draft
mail|delete-draft|1|<message-id>|Permanently delete a draft by message ID
mail|reset|0||Kill stuck Mail scripts and restart Mail.app
messages|chats|0|[<count>]|List chats with their last message (default 30)
messages|read|1|<chat> [<count>]|Read the latest messages from one chat (default 20)
messages|recent|0|[<count>]|Show the latest messages across all chats (default 20)
messages|search|1|<query> [<count>]|Search message text (default 20 results)
messages|info|0||Show Messages database statistics
messages|unread|0||Show the unread message count
messages|send|2|<to> <message>|SEND an iMessage (falls back to SMS) immediately
messages|send-sms|2|<phone-number> <message>|SEND an SMS immediately
facetime|call|1|<number-or-email>|Start a FaceTime video call
facetime|audio|1|<number-or-email>|Start a FaceTime audio call
calendar|list|0||List all calendars
calendar|today|0||Show today's events
calendar|yesterday|0||Show yesterday's events
calendar|week|0||Show events for the next 7 days
calendar|upcoming|0|[<days>]|Show events for the next N days (default 7)
calendar|past|0|[<days>]|Show events from the past N days (default 7)
calendar|search|1|<query> [--past=<days>] [--future=<days>]|Search events by title
calendar|create|3|<title> <date> <duration> [<calendar>]|Create an event
calendar|delete|1|<title>|Delete the next event with this exact title
reminders|lists|0||List reminder lists with open counts
reminders|list|0|[<list>]|Show open reminders in one list
reminders|all|0||Show every open reminder
reminders|today|0||Show reminders due today
reminders|overdue|0||Show overdue reminders
reminders|add|1|<title> [<list>] [<due>]|Add a reminder
reminders|complete|1|<title>|Mark a reminder as done
reminders|delete|1|<title>|Delete a reminder
reminders|search|1|<query>|Search reminders
notes|list|0|[<count>]|List notes, newest first (default 50)
notes|folders|0||List note folders
notes|create|2|<title> <body>|Create a note in the "Notes" folder
notes|read|1|<title>|Print one note
notes|search|1|<query>|Search note titles and text
contacts|list|0||List contacts
contacts|search|1|<query>|Search contacts by name
contacts|show|1|<name>|Show everything stored for one contact
contacts|groups|0||List contact groups
contacts|add|2|<first> <last> [<email>] [<phone>]|Create a contact
contacts|email|1|<name>|Print a contact's email address
contacts|phone|1|<name>|Print a contact's phone number
music|play|0|[<playlist>]|Start playback, optionally from a playlist
music|open|1|<query>|Find a song in the Apple Music catalog and play it
music|pause|0||Pause playback
music|toggle|0||Toggle play and pause
music|next|0||Skip to the next track
music|previous|0||Go back to the previous track
music|now|0||Show the current track
music|volume|0|[<level>]|Show or set the volume (0-100)
music|playlists|0||List your playlists
music|search|1|<query>|Search your library
photos|recent|0|[<count>] [--since <date>]|List the most recent photos (default 20)
photos|search|1|<query> [--since <date>] [--type <type>]|Search photos by text, person, keyword or OCR
photos|people|0||List named people in your library
photos|keywords|0||List keywords in your library
photos|albums|0||List albums
photos|export|2|<query> <directory>|Export photos matching a search into a folder
photos|export-recent|2|<count> <directory>|Export the N most recent photos into a folder
photos|import|1|<file> [<album>]|Import an image or video file into Photos
shortcuts|list|0||List all your Shortcuts
shortcuts|run|1|<name>|Run a Shortcut by name
shortcuts|search|1|<query>|Search Shortcuts by name
home|list|0||List HomeKit shortcuts (named homekit-...)
home|run|1|<shortcut>|Run a HomeKit shortcut
home|setup|0||Install the preloaded HomeKit shortcuts
EOF
}

# Aliases accepted by the apps. Prints the canonical command (or the input).
mj_canonical() {
    case "$1 $2" in
        "facetime video") echo "call" ;;
        "reminders create") echo "add" ;;
        "reminders done") echo "complete" ;;
        *) echo "$2" ;;
    esac
}

# One-line app descriptions: "app|group|description"
mj_app_table() {
    cat <<'EOF'
mail|Communicate|Search, read, draft and send email
messages|Communicate|Read and send iMessage/SMS
facetime|Communicate|Start FaceTime calls
calendar|Organize|View, create and delete events
reminders|Organize|Add, complete and delete reminders
notes|Organize|Create, read and search notes
contacts|Organize|Look up and add contacts
music|Media|Control Apple Music playback
photos|Media|Search, export and import photos
shortcuts|Automate|Run any macOS Shortcut
home|Automate|Run HomeKit scenes (through Shortcuts)
EOF
}

mj_is_app() {
    local a
    for a in $MJ_APPS; do [[ "$a" == "$1" ]] && return 0; done
    return 1
}

# Registry line for app+command (aliases resolved); empty if unknown
mj_reg_line() {
    local app="$1" cmd
    cmd="$(mj_canonical "$1" "$2")"
    mj_registry | awk -F'|' -v a="$app" -v c="$cmd" '$1==a && $2==c {print; exit}'
}

mj_cmds_of() {
    mj_registry | awk -F'|' -v a="$1" '$1==a {print $2}'
}

# ---------------------------------------------------------------------------
# Per-command details. Every <argument> and --flag in the registry usage line
# must have its own definition line here (two-space indent, then the name).
# ---------------------------------------------------------------------------
mj_cmd_body() {
    case "$1 $2" in
    "mail accounts") cat <<'EOF'
Notes:
  Use the addresses shown here with --from=<address> and --account.

Examples:
  macjuice mail accounts
EOF
    ;;
    "mail list") cat <<'EOF'
Arguments:
  <mailbox>      Optional. Mailbox name, e.g. Drafts. Default: INBOX.
                 Names depend on your account; try INBOX first.

Notes:
  Each line starts with the message ID. Pass that ID to read, reply, forward,
  attach, attachments and delete-draft.

Examples:
  macjuice mail list
  macjuice mail list Drafts
EOF
    ;;
    "mail search") cat <<'EOF'
Arguments:
  <query>        Text to find. Plain text searches sender, subject and body.
                 Prefixes narrow it: from:, to:, subject:, body:
                 (body: is the slowest).

Options:
  --account <addresses>
                 Optional. Only search these accounts. Comma-separated
                 addresses; write a space after --account (not "=").
                 Run `macjuice mail accounts` to see them.

Examples:
  macjuice mail search "invoice"
  macjuice mail search "from:jane@example.com"
  macjuice mail search "subject:quarterly report" --account jane@contoso.com
  macjuice mail search "body:contract" --account jane@contoso.com,jane@fabrikam.com
EOF
    ;;
    "mail read") cat <<'EOF'
Arguments:
  <message-id>   Required. ID from the first column of `mail list` or `mail search`.

Examples:
  macjuice mail read 12345
EOF
    ;;
    "mail attachments") cat <<'EOF'
Arguments:
  <message-id>   Required. ID from `mail list` or `mail search`.

Examples:
  macjuice mail attachments 12345
EOF
    ;;
    "mail save-attachments") cat <<'EOF'
Arguments:
  <message-id>   Required. ID from `mail list` or `mail search`.
  <directory>    Required. Folder to save the files into.

Notes:
  Needs python3 and Full Disk Access for your terminal.

Examples:
  macjuice mail save-attachments 12345 ~/Downloads
  macjuice mail save-attachments 12345 /tmp/invoices
EOF
    ;;
    "mail send") cat <<'EOF'
WARNING: this sends the email right away. There is no confirmation and no undo.
To review first, use `macjuice mail draft` instead.

Arguments:
  <to>           Required. Recipient address, e.g. jane@example.com.
  <subject>      Required. Subject line. Quote it.
  <body>         Required. Plain-text body. Quote it.
  <attachment-path>
                 Optional, repeatable. Full path of a file to attach.
                 Must come after --from if you use it.

Options:
  --from=<address>
                 Optional. Send from this account. It must directly follow
                 <body>. Default: Mail's default account.

Examples:
  macjuice mail send "jane@example.com" "Lunch?" "Are you free at noon?"
  macjuice mail send "jane@example.com" "Report" "Attached." --from=me@contoso.com /tmp/report.pdf
EOF
    ;;
    "mail draft") cat <<'EOF'
Saves a draft in Mail.app. Nothing is sent.

Arguments:
  <to>           Required. Recipient address, e.g. jane@example.com.
  <subject>      Required. Subject line. Quote it.
  <body>         Required. Plain-text body. Quote it.

Options:
  --from=<address>
                 Optional. Draft from this account (also picks that account's
                 Drafts folder). Default: Mail's default account.
  --cc=<addresses>
                 Optional. CC recipients, comma-separated.
  --bcc=<addresses>
                 Optional. BCC recipients, comma-separated.

Notes:
  File paths after the options are ignored. To attach files, create the draft,
  find its ID with `macjuice mail list Drafts`, then run `macjuice mail attach`.

Examples:
  macjuice mail draft "jane@example.com" "Hello" "Draft body"
  macjuice mail draft "jane@example.com" "Hello" "Draft body" --from=me@contoso.com
  macjuice mail draft "jane@example.com" "Plan" "See you soon" --cc=bob@fabrikam.com,amy@contoso.com --bcc=me@contoso.com
EOF
    ;;
    "mail html-draft") cat <<'EOF'
Opens a Mail compose window with the recipients filled in and puts the HTML
on your clipboard. Click the message body and press Cmd+V to paste it.
Nothing is sent.

Arguments:
  <to>           Required. Recipient address; comma-separate several.
  <subject>      Required. Subject line. Quote it.
  <html>         Required. Path to an .html file, or an HTML string.

Options:
  --from=<address>
                 Optional. Send-from account. Default: Mail's default.
  --cc=<addresses>
                 Optional. CC recipients, comma-separated.
  --bcc=<addresses>
                 Optional. BCC recipients, comma-separated.

Notes:
  Needs python3 with PyObjC (AppKit). See the README for a Swift workaround.

Examples:
  macjuice mail html-draft "jane@example.com" "Weekly update" ./update.html
  macjuice mail html-draft "jane@example.com" "Hi" "<h1>Hello</h1><p>World</p>"
  macjuice mail html-draft "jane@example.com" "Update" ./update.html --from=me@contoso.com --cc=bob@fabrikam.com
EOF
    ;;
    "mail reply") cat <<'EOF'
Replies to everyone on the message and saves the reply as a draft in Mail.
Nothing is sent; open Mail to review and send it.

Arguments:
  <message-id>   Required (unless you use --search). ID from `mail list`/`mail search`.
  <body>         Required. Your reply text. Quote it.

Options:
  --search <query>
                 Use instead of <message-id>: replies to the first message that
                 matches the search (same query syntax as `mail search`).
  --from=<address>
                 Optional. Reply from this account.
  --cc=<addresses>
                 Optional. Extra CC recipients, comma-separated.
  --bcc=<addresses>
                 Optional. BCC recipients, comma-separated.

Examples:
  macjuice mail reply 12345 "Thanks, sounds good."
  macjuice mail reply 12345 "Adding Bob." --cc=bob@fabrikam.com --from=me@contoso.com
  macjuice mail reply --search "subject:quarterly report" "Looks good to me."
EOF
    ;;
    "mail forward") cat <<'EOF'
Forwards a message and saves it as a draft in Mail. Nothing is sent.

Arguments:
  <message-id>   Required. ID from `mail list` or `mail search`.
  <to>           Required. Address to forward to.

Options:
  --from=<address>
                 Optional. Forward from this account (--account also works).
  --cc=<addresses>
                 Optional. CC recipients, comma-separated.
  --bcc=<addresses>
                 Optional. BCC recipients, comma-separated.
  --body=<text>
                 Optional. Text to put above the forwarded message.
  --attach <file>
                 Optional, repeatable. Full path of a file to attach.

Examples:
  macjuice mail forward 12345 "jane@example.com"
  macjuice mail forward 12345 "jane@example.com" --body="FYI, see below."
  macjuice mail forward 12345 "jane@example.com" --cc=bob@fabrikam.com --from=me@contoso.com
  macjuice mail forward 12345 "jane@example.com" --attach /tmp/a.pdf --attach /tmp/b.png
EOF
    ;;
    "mail attach") cat <<'EOF'
Adds files to a draft that already exists. This is the reliable way to attach files.

Arguments:
  <message-id>   Required. Draft ID from `macjuice mail list Drafts`.
  <file>         Required, repeatable. Full path of a file to attach.

Examples:
  macjuice mail attach 12345 /tmp/report.pdf
  macjuice mail attach 12345 /tmp/photo1.png /tmp/photo2.png
EOF
    ;;
    "mail delete-draft") cat <<'EOF'
WARNING: deletes the message with this ID. It does not check that the message
is a draft, so only use IDs from `macjuice mail list Drafts`.

Arguments:
  <message-id>   Required. Draft ID from `macjuice mail list Drafts`.

Examples:
  macjuice mail list Drafts
  macjuice mail delete-draft 12345
EOF
    ;;
    "mail reset") cat <<'EOF'
Use this when a mail command hangs or times out (default timeout 60 seconds;
set MACJUICE_TIMEOUT=<seconds> to change it). It stops stuck scripts, quits
Mail.app (force-quitting if needed) and reopens it. Unsaved compose windows
may be lost.

Examples:
  macjuice mail reset
EOF
    ;;
    "messages chats") cat <<'EOF'
Arguments:
  <count>        Optional. How many chats to show. Default: 30.

Notes:
  Reads the Messages database; your terminal needs Full Disk Access.

Examples:
  macjuice messages chats
  macjuice messages chats 10
EOF
    ;;
    "messages read") cat <<'EOF'
Arguments:
  <chat>         Required. Phone number, email address, or part of a group name.
  <count>        Optional. How many messages to show. Default: 20.

Notes:
  Reads the Messages database; your terminal needs Full Disk Access.

Examples:
  macjuice messages read "+15555550123"
  macjuice messages read "Jane Doe" 50
  macjuice messages read "jane@example.com" 5
EOF
    ;;
    "messages recent") cat <<'EOF'
Arguments:
  <count>        Optional. How many messages to show. Default: 20.

Notes:
  Reads the Messages database; your terminal needs Full Disk Access.

Examples:
  macjuice messages recent
  macjuice messages recent 10
EOF
    ;;
    "messages search") cat <<'EOF'
Arguments:
  <query>        Required. Text to look for in message bodies.
  <count>        Optional. Maximum results. Default: 20.

Notes:
  Reads the Messages database; your terminal needs Full Disk Access.

Examples:
  macjuice messages search "dinner"
  macjuice messages search "flight confirmation" 5
EOF
    ;;
    "messages info") cat <<'EOF'
Prints message, chat and contact counts, the date range, and the database size.

Examples:
  macjuice messages info
EOF
    ;;
    "messages unread") cat <<'EOF'
Examples:
  macjuice messages unread
EOF
    ;;
    "messages send") cat <<'EOF'
WARNING: sends right away. There is no confirmation and no undo. Double-check
the recipient.

Arguments:
  <to>           Required. Phone number with country code (+15555550123), an
                 email address, or a contact name such as "Jane Doe".
  <message>      Required. Message text. Quote it.

Notes:
  Phone numbers are sent over iMessage and also SMS when Text Message
  Forwarding is enabled on your iPhone.

Examples:
  macjuice messages send "+15555550123" "Running 10 minutes late"
  macjuice messages send "Jane Doe" "Are you free tonight?"
  macjuice messages send "jane@example.com" "Hello!"
EOF
    ;;
    "messages send-sms") cat <<'EOF'
WARNING: sends right away. There is no confirmation and no undo.

Arguments:
  <phone-number> Required. Phone number with country code, e.g. +15555550123.
  <message>      Required. Message text. Quote it.

Notes:
  Needs Text Message Forwarding enabled on your iPhone.

Examples:
  macjuice messages send-sms "+15555550123" "Call me when you can"
EOF
    ;;
    "facetime call") cat <<'EOF'
Opens FaceTime and starts a video call. `video` is the same command, and the
shortest form is `macjuice facetime <number-or-email>`.

Arguments:
  <number-or-email>
                 Required. Phone number with country code, or an Apple ID email.

Examples:
  macjuice facetime call "+15555550123"
  macjuice facetime "jane@example.com"
  macjuice facetime video "+15555550123"
EOF
    ;;
    "facetime audio") cat <<'EOF'
Opens FaceTime and starts an audio-only call.

Arguments:
  <number-or-email>
                 Required. Phone number with country code, or an Apple ID email.

Examples:
  macjuice facetime audio "+15555550123"
  macjuice facetime audio "jane@example.com"
EOF
    ;;
    "calendar list") cat <<'EOF'
Examples:
  macjuice calendar list
EOF
    ;;
    "calendar today") cat <<'EOF'
Examples:
  macjuice calendar today
EOF
    ;;
    "calendar yesterday") cat <<'EOF'
Examples:
  macjuice calendar yesterday
EOF
    ;;
    "calendar week") cat <<'EOF'
Shows today plus the next 6 days.

Examples:
  macjuice calendar week
EOF
    ;;
    "calendar upcoming") cat <<'EOF'
Arguments:
  <days>         Optional. How many days ahead, as a whole number. Default: 7.

Examples:
  macjuice calendar upcoming
  macjuice calendar upcoming 14
EOF
    ;;
    "calendar past") cat <<'EOF'
Arguments:
  <days>         Optional. How many days back, as a whole number. Default: 7.

Examples:
  macjuice calendar past
  macjuice calendar past 30
EOF
    ;;
    "calendar search") cat <<'EOF'
Arguments:
  <query>        Required. Text to look for in event titles.

Options:
  --past=<days>  Optional. How far back to search. Default: 90.
  --future=<days>
                 Optional. How far ahead to search. Default: 90.

Examples:
  macjuice calendar search "dentist"
  macjuice calendar search "Team sync" --past=7 --future=30
EOF
    ;;
    "calendar create") cat <<'EOF'
Adds an event. Nothing is sent to attendees.

Arguments:
  <title>        Required. Event title. Quote it.
  <date>         Required. "YYYY-MM-DD HH:MM" in 24-hour time, e.g.
                 "2026-03-01 14:30". With just "YYYY-MM-DD" the time is 12:00.
  <duration>     Required. 30m, 1h or 1h30m. A bare number means minutes.
                 Unreadable values become 1 hour.
  <calendar>     Optional. Calendar name from `macjuice calendar list`.
                 Default: "Calendar"; if not found, the first calendar is used.

Examples:
  macjuice calendar create "Team sync" "2026-03-01 14:00" 30m
  macjuice calendar create "Dentist" "2026-03-05 09:15" 1h "Personal"
  macjuice calendar create "Workshop" "2026-03-10 13:00" 1h30m
EOF
    ;;
    "calendar delete") cat <<'EOF'
WARNING: deletes the event right away. There is no confirmation and no undo.
Only the first match is deleted (today or later, exact title, case-sensitive).

Arguments:
  <title>        Required. Exact event title.

Examples:
  macjuice calendar search "Team sync"
  macjuice calendar delete "Team sync"
EOF
    ;;
    "reminders lists") cat <<'EOF'
Examples:
  macjuice reminders lists
EOF
    ;;
    "reminders list") cat <<'EOF'
Arguments:
  <list>         Optional. Reminder list name from `reminders lists`.
                 Default: the list named "Reminders".

Examples:
  macjuice reminders list
  macjuice reminders list "Groceries"
EOF
    ;;
    "reminders all") cat <<'EOF'
Examples:
  macjuice reminders all
EOF
    ;;
    "reminders today") cat <<'EOF'
Examples:
  macjuice reminders today
EOF
    ;;
    "reminders overdue") cat <<'EOF'
Examples:
  macjuice reminders overdue
EOF
    ;;
    "reminders add") cat <<'EOF'
Also available as `reminders create`.

Arguments:
  <title>        Required. What to be reminded of. Quote it.
  <list>         Optional. List name. Default: "Reminders". An unknown name
                 silently uses your default list.
  <due>          Optional. One of: today, tomorrow, next week, a time today
                 such as 5pm or 10am, or a date your Mac can read, such as
                 "March 5, 2026". Unreadable values add the reminder with no
                 due date; combined forms like "tomorrow 5pm" are not understood.

Examples:
  macjuice reminders add "Buy milk"
  macjuice reminders add "Buy milk" "Groceries"
  macjuice reminders add "Call the dentist" "Reminders" tomorrow
  macjuice reminders add "Submit report" "Work" "March 5, 2026"
EOF
    ;;
    "reminders complete") cat <<'EOF'
Also available as `reminders done`. Marks the first open reminder with this
exact title as done; if none matches exactly, the first open one containing the
text is used.

Arguments:
  <title>        Required. Reminder title (or part of it).

Examples:
  macjuice reminders complete "Buy milk"
EOF
    ;;
    "reminders delete") cat <<'EOF'
WARNING: deletes right away. There is no confirmation and no undo. Matches the
first reminder whose title CONTAINS the text, in any list, so be specific.

Arguments:
  <title>        Required. Reminder title (or distinctive part of it).

Examples:
  macjuice reminders search "milk"
  macjuice reminders delete "Buy milk"
EOF
    ;;
    "reminders search") cat <<'EOF'
Arguments:
  <query>        Required. Text to look for in reminder titles.

Examples:
  macjuice reminders search "milk"
EOF
    ;;
    "notes list") cat <<'EOF'
Arguments:
  <count>        Optional. How many notes to show. Default: 50.

Examples:
  macjuice notes list
  macjuice notes list 10
EOF
    ;;
    "notes folders") cat <<'EOF'
Examples:
  macjuice notes folders
EOF
    ;;
    "notes create") cat <<'EOF'
Creates a new note in the "Notes" folder.

Arguments:
  <title>        Required. Note title. Quote it.
  <body>         Required. Note text. Quote it.

Examples:
  macjuice notes create "Shopping list" "Milk, eggs, bread"
  macjuice notes create "Meeting notes" "Agenda: budget review"
EOF
    ;;
    "notes read") cat <<'EOF'
Arguments:
  <title>        Required. Note title. An exact match is tried first, then a
                 partial match. Titles are listed by `macjuice notes list`.

Examples:
  macjuice notes read "Shopping list"
EOF
    ;;
    "notes search") cat <<'EOF'
Arguments:
  <query>        Required. Text to look for in note titles and contents.

Examples:
  macjuice notes search "budget"
EOF
    ;;
    "contacts list") cat <<'EOF'
Examples:
  macjuice contacts list
EOF
    ;;
    "contacts search") cat <<'EOF'
Arguments:
  <query>        Required. Part of a contact's name.

Examples:
  macjuice contacts search "Jane"
EOF
    ;;
    "contacts show") cat <<'EOF'
Arguments:
  <name>         Required. Full or partial contact name; the first match is shown.

Examples:
  macjuice contacts show "Jane Doe"
EOF
    ;;
    "contacts groups") cat <<'EOF'
Examples:
  macjuice contacts groups
EOF
    ;;
    "contacts add") cat <<'EOF'
Creates a new contact (does not check for duplicates).

Arguments:
  <first>        Required. First name.
  <last>         Required. Last name. Use "" if there is none.
  <email>        Optional. Email address (saved with the label "work").
  <phone>        Optional. Phone number (saved with the label "mobile").
                 To give a phone but no email, pass "" for <email>.

Examples:
  macjuice contacts add "Jane" "Doe"
  macjuice contacts add "Jane" "Doe" "jane@example.com" "+15555550123"
  macjuice contacts add "Jane" "Doe" "" "+15555550123"
EOF
    ;;
    "contacts email") cat <<'EOF'
Arguments:
  <name>         Required. Full or partial contact name; the first match is used.

Examples:
  macjuice contacts email "Jane Doe"
EOF
    ;;
    "contacts phone") cat <<'EOF'
Arguments:
  <name>         Required. Full or partial contact name; the first match is used.

Examples:
  macjuice contacts phone "Jane Doe"
EOF
    ;;
    "music play") cat <<'EOF'
Arguments:
  <playlist>     Optional. Exact playlist name from `macjuice music playlists`.
                 Without it, playback simply resumes.

Examples:
  macjuice music play
  macjuice music play "Road Trip"
EOF
    ;;
    "music open") cat <<'EOF'
Looks the song up in the Apple Music catalog (needs internet), opens its album
in Music and plays it. This clicks Play through the Music UI, so your terminal
needs Accessibility permission. It takes about 10 seconds.

Arguments:
  <query>        Required. A song title, or "<song> by <artist>".

Examples:
  macjuice music open "Yesterday by The Beatles"
  macjuice music open "Bohemian Rhapsody"
EOF
    ;;
    "music pause") cat <<'EOF'
Examples:
  macjuice music pause
EOF
    ;;
    "music toggle") cat <<'EOF'
Examples:
  macjuice music toggle
EOF
    ;;
    "music next") cat <<'EOF'
Examples:
  macjuice music next
EOF
    ;;
    "music previous") cat <<'EOF'
Examples:
  macjuice music previous
EOF
    ;;
    "music now") cat <<'EOF'
Examples:
  macjuice music now
EOF
    ;;
    "music volume") cat <<'EOF'
Arguments:
  <level>        Optional. Whole number 0-100. Without it, shows the current volume.

Examples:
  macjuice music volume
  macjuice music volume 40
EOF
    ;;
    "music playlists") cat <<'EOF'
Examples:
  macjuice music playlists
EOF
    ;;
    "music search") cat <<'EOF'
Searches your own library (not the Apple Music catalog; use `music open` for that).

Arguments:
  <query>        Required. Text to look for in your library.

Examples:
  macjuice music search "Beatles"
EOF
    ;;
    "photos recent") cat <<'EOF'
Arguments:
  <count>        Optional. How many photos to list. Default: 20.

Options:
  --since <date> Optional. Only photos on or after this date. Use YYYY-MM-DD,
                 today, yesterday, or a relative value: 3d, 1w, 2m.

Examples:
  macjuice photos recent
  macjuice photos recent 50
  macjuice photos recent --since 1w
EOF
    ;;
    "photos search") cat <<'EOF'
Arguments:
  <query>        Required. Text to find in filename, title, OCR text, people and
                 keywords. Prefix it to narrow: person:<name>, keyword:<tag>,
                 ocr:<text>, text:<query> (filename/title/description only).

Options:
  --since <date> Optional. Only photos on or after this date. Use YYYY-MM-DD,
                 today, yesterday, or a relative value: 3d, 1w, 2m.
  --type <type>  Optional. One of: all, person, keyword, text, ocr. Default: all.
                 Same effect as the prefixes above.

Examples:
  macjuice photos search "beach"
  macjuice photos search person:Jane
  macjuice photos search ocr:receipt --since 1w
  macjuice photos search "bike" --since 2026-03-09
EOF
    ;;
    "photos people") cat <<'EOF'
Examples:
  macjuice photos people
EOF
    ;;
    "photos keywords") cat <<'EOF'
Examples:
  macjuice photos keywords
EOF
    ;;
    "photos albums") cat <<'EOF'
Examples:
  macjuice photos albums
EOF
    ;;
    "photos export") cat <<'EOF'
Copies the photos matching a search into a folder. Originals stay in Photos.

Arguments:
  <query>        Required. Same query syntax as `photos search`
                 (e.g. "beach", person:Jane, keyword:vacation).
  <directory>    Required. Existing folder to write into.

Examples:
  macjuice photos export "beach" ~/Desktop/beach-photos
  macjuice photos export person:Jane /tmp/export
EOF
    ;;
    "photos export-recent") cat <<'EOF'
Copies the newest photos into a folder. Originals stay in Photos.

Arguments:
  <count>        Required. How many recent photos to export.
  <directory>    Required. Existing folder to write into.

Examples:
  macjuice photos export-recent 10 ~/Desktop/recent
EOF
    ;;
    "photos import") cat <<'EOF'
Adds a file to your Photos library.

Arguments:
  <file>         Required. Full path of an image or video file.
  <album>        Optional. Album to add it to. Default: none.

Examples:
  macjuice photos import ~/Downloads/beach.jpg
  macjuice photos import ~/Downloads/beach.jpg "Vacation"
EOF
    ;;
    "shortcuts list") cat <<'EOF'
Examples:
  macjuice shortcuts list
EOF
    ;;
    "shortcuts run") cat <<'EOF'
Runs the Shortcut right away. A Shortcut can do anything it is built to do, so
check what it does first.

Arguments:
  <name>         Required. Exact Shortcut name from `macjuice shortcuts list`.

Examples:
  macjuice shortcuts run "Morning Routine"
EOF
    ;;
    "shortcuts search") cat <<'EOF'
Arguments:
  <query>        Required. Text to look for in Shortcut names.

Examples:
  macjuice shortcuts search "morning"
EOF
    ;;
    "home list") cat <<'EOF'
Lists Shortcuts whose names start with "homekit-".

Examples:
  macjuice home list
EOF
    ;;
    "home run") cat <<'EOF'
Runs a HomeKit scene through the Shortcuts app (Home has no command line).

Arguments:
  <shortcut>     Required. Shortcut name from `macjuice home list`.

Examples:
  macjuice home list
  macjuice home run "homekit-lock-doors"
EOF
    ;;
    "home setup") cat <<'EOF'
Walks you through installing the preloaded HomeKit shortcuts into the Shortcuts
app. macOS asks you to confirm each import. Run it once.

Examples:
  macjuice home setup
EOF
    ;;
    esac
}

# First example line of a command (used in error messages)
mj_first_example() {
    mj_cmd_body "$1" "$(mj_canonical "$1" "$2")" | awk '/^Examples:/ {f=1; next} f && /^  macjuice/ {sub(/^  /, ""); print; exit}'
}

mj_top_help() {
    cat <<EOF
macjuice v$VERSION - run macOS apps (Mail, Calendar, Messages, Music...) from the terminal.

Setup: ./install.sh puts macjuice on your PATH (macOS only). No sign-in and no
config file. Allow Automation when macOS asks; Mail, Messages and Photos reads
also need Full Disk Access for your terminal app (see docs/permissions.md).

Usage: macjuice <app> <command> [arguments]

Apps:
  Communicate
    mail         Search, read, draft and send email
    messages     Read and send iMessage/SMS
    facetime     Start FaceTime calls
  Organize
    calendar     View, create and delete events
    reminders    Add, complete and delete reminders
    notes        Create, read and search notes
    contacts     Look up and add contacts
  Media
    music        Control Apple Music playback
    photos       Search, export and import photos
  Automate
    shortcuts    Run any macOS Shortcut
    home         Run HomeKit scenes (through Shortcuts)

Examples:
  macjuice calendar today
  macjuice mail search "from:jane@example.com"
  macjuice mail draft "jane@example.com" "Lunch?" "Free at noon?" --from=me@contoso.com
  macjuice messages read "Jane Doe" 20
  macjuice reminders add "Buy milk" "Groceries" tomorrow
  macjuice notes create "Shopping list" "Milk, eggs, bread"
  macjuice music open "Yesterday by The Beatles"
  macjuice shortcuts run "Morning Routine"

More help:
  macjuice <app> --help             commands of one app (e.g. macjuice mail --help)
  macjuice <app> <command> --help   arguments and examples (also: macjuice help mail send)

Output: plain text (no JSON mode).
Safety: there is no --yes flag and no confirmation prompt, so send, delete and
  run commands act immediately. Use "mail draft" to review an email first.
EOF
}

mj_app_help() {
    local app="$1" cmd usage summary min label desc
    desc="$(mj_app_table | awk -F'|' -v a="$app" '$1==a {print $3}')"
    echo "macjuice $app - $desc"
    echo ""
    echo "Usage: macjuice $app <command> [arguments]"
    echo ""
    echo "Commands:"
    while IFS='|' read -r _ cmd min usage summary; do
        # Show only the required arguments here; --help has the full usage
        label="$cmd $(echo "$usage" | sed -E -e 's/^\(<message-id> or --search <query>\)/<message-id>/' -e 's/ *(\[|--).*//')"
        label="$(echo "$label" | sed -E 's/ +$//')"
        printf '  %-42s %s\n' "$label" "$summary"
    done < <(mj_registry | awk -F'|' -v a="$app" '$1==a')
    echo ""
    echo "Examples:"
    case "$app" in
        facetime) echo "  macjuice facetime call \"+15555550123\""; echo "  macjuice facetime audio \"jane@example.com\"" ;;
        mail) echo "  macjuice mail search \"from:jane@example.com\""; echo "  macjuice mail draft \"jane@example.com\" \"Hello\" \"Draft body\""; echo "  macjuice mail reply 12345 \"Thanks!\"" ;;
        messages) echo "  macjuice messages recent 10"; echo "  macjuice messages read \"Jane Doe\" 20"; echo "  macjuice messages send \"+15555550123\" \"On my way\"" ;;
        calendar) echo "  macjuice calendar today"; echo "  macjuice calendar upcoming 14"; echo "  macjuice calendar create \"Team sync\" \"2026-03-01 14:00\" 30m" ;;
        reminders) echo "  macjuice reminders today"; echo "  macjuice reminders add \"Buy milk\" \"Groceries\" tomorrow"; echo "  macjuice reminders complete \"Buy milk\"" ;;
        notes) echo "  macjuice notes list 10"; echo "  macjuice notes search \"budget\""; echo "  macjuice notes create \"Shopping list\" \"Milk, eggs\"" ;;
        contacts) echo "  macjuice contacts search \"Jane\""; echo "  macjuice contacts email \"Jane Doe\""; echo "  macjuice contacts add \"Jane\" \"Doe\" \"jane@example.com\"" ;;
        music) echo "  macjuice music now"; echo "  macjuice music volume 40"; echo "  macjuice music open \"Yesterday by The Beatles\"" ;;
        photos) echo "  macjuice photos recent --since 1w"; echo "  macjuice photos search person:Jane --since 2026-03-09"; echo "  macjuice photos export \"beach\" ~/Desktop/beach-photos" ;;
        shortcuts) echo "  macjuice shortcuts list"; echo "  macjuice shortcuts run \"Morning Routine\"" ;;
        home) echo "  macjuice home setup"; echo "  macjuice home list"; echo "  macjuice home run \"homekit-lock-doors\"" ;;
    esac
    echo ""
    echo "Details and more examples for one command: macjuice $app <command> --help"
    [[ "$app" == "facetime" ]] && echo "Shortcut: macjuice facetime <number-or-email> is the same as 'facetime call'."
    return 0
}

mj_cmd_help() {
    local app="$1" cmd line usage summary
    cmd="$(mj_canonical "$1" "$2")"
    line="$(mj_reg_line "$app" "$cmd")"
    usage="$(echo "$line" | cut -d'|' -f4)"
    summary="$(echo "$line" | cut -d'|' -f5)"
    echo "macjuice $app $cmd - $summary"
    echo ""
    echo "Usage:"
    if [[ -n "$usage" ]]; then
        echo "  macjuice $app $cmd $usage"
    else
        echo "  macjuice $app $cmd"
    fi
    echo ""
    mj_cmd_body "$app" "$cmd"
    echo ""
    echo "All $app commands: macjuice $app --help"
}

# Error for unknown app or command (stderr, exit handled by caller)
mj_unknown_app() {
    {
        echo "Error: unknown app '$1'."
        echo "Apps: $MJ_APPS"
        echo "Run 'macjuice --help' for examples."
    } >&2
}

mj_unknown_cmd() {
    local app="$1" cmd="$2"
    {
        echo "Error: unknown command '$cmd' for 'macjuice $app'."
        echo "Commands: $(mj_cmds_of "$app" | tr '\n' ' ')"
        echo "Run 'macjuice $app --help' for what each one does."
    } >&2
}

# Missing arguments: short error + usage + one example + pointer to help
mj_missing_args() {
    local app="$1" cmd min usage ex got="$3"
    cmd="$(mj_canonical "$1" "$2")"
    min="$(mj_reg_line "$app" "$cmd" | cut -d'|' -f3)"
    usage="$(mj_reg_line "$app" "$cmd" | cut -d'|' -f4)"
    ex="$(mj_first_example "$app" "$cmd")"
    {
        echo "Error: 'macjuice $app $cmd' needs at least $min argument(s) but got $got."
        echo "Usage:   macjuice $app $cmd $usage"
        [[ -n "$ex" ]] && echo "Example: $ex"
        echo "Run 'macjuice $app $cmd --help' for details."
    } >&2
}
