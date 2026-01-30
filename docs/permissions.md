# Permissions Guide

MacJuice uses AppleScript to interact with Apple apps. macOS requires explicit permission for each app the first time.

## How Permissions Work

When macjuice runs a command for the first time, macOS will show a dialog:

> "[Your Terminal] wants to control [App]. Allow?

Click **Allow**. This is a one-time prompt per app.

## Required Permissions by App

| App | Permission Needed | Granted Via |
|---|---|---|
| **Mail** | Automation → Mail | First-run dialog |
| **Calendar** | Automation → Calendar | First-run dialog |
| **Contacts** | Automation → Contacts | First-run dialog |
| **Notes** | Automation → Notes | First-run dialog |
| **Messages** | Automation → Messages | First-run dialog |
| **Music** | Automation → Music | First-run dialog |
| **Reminders** | Automation → Reminders | First-run dialog |
| **Shortcuts** | Automation → Shortcuts Events | First-run dialog |
| **Home** | Automation → Shortcuts Events | First-run dialog (via Shortcuts) |

## If You Accidentally Clicked "Don't Allow"

1. Open **System Settings**
2. Go to **Privacy & Security → Automation**
3. Find your terminal app (Terminal, iTerm2, Warp, etc.)
4. Toggle on the app you need

## If Permissions Aren't Appearing

Some environments (SSH, cron, background agents) can't show permission dialogs. To fix:

1. Run the command **once from a local terminal** (not SSH) to trigger the dialog
2. After granting permission, it will work from any context

## Full Disk Access (Optional)

Some advanced features (like reading Mail message bodies) may require **Full Disk Access**:

1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Add your terminal app

## Checking Your Permissions

Run the test suite to see what's working:

```bash
cd /path/to/macjuice
bash tests/run_all.sh
```

Or test individual apps:

```bash
macjuice mail accounts      # Tests Mail access
macjuice calendar list      # Tests Calendar access
macjuice contacts list      # Tests Contacts access
macjuice notes list         # Tests Notes access
macjuice messages recent    # Tests Messages access
macjuice music now          # Tests Music access
macjuice shortcuts list     # Tests Shortcuts access
```

If a command returns results, you have permission. If it hangs or errors, check System Settings.
