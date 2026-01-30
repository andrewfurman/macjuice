# HomeKit Setup Guide

MacJuice controls HomeKit devices through **macOS Shortcuts**. Apple doesn't provide direct CLI access to HomeKit, so Shortcuts acts as the bridge.

## How It Works

```
macjuice home run "Lamp On"
       ↓
Shortcuts Events (AppleScript)
       ↓
Your "Lamp On" shortcut
       ↓
HomeKit → Your devices
```

## Step 1: Create Your Shortcuts

Open the **Shortcuts** app on your Mac and create shortcuts for each action you want to control from the CLI.

### Example: "Lamp On"

1. Open **Shortcuts** (Spotlight → "Shortcuts")
2. Click **+** to create a new shortcut
3. Name it `Lamp On`
4. Search for **"Control my home"** in the action search bar
5. Add the action → select your light(s) → set to **On**
6. Save

### Example: "Lamp Off"

Same steps, but set the action to **Off**.

### Naming Tips

- Use clear, descriptive names: `Lamp On`, `Lamp Off`, `Good Morning`, `Good Night`
- Avoid special characters in names
- Names are case-sensitive when running from the CLI

## Step 2: Grant Permissions

The first time macjuice runs a shortcut, macOS will ask for **Automation** permission. Click **Allow**.

If you accidentally denied it:
1. Go to **System Settings → Privacy & Security → Automation**
2. Find your terminal app (Terminal, iTerm, etc.)
3. Enable **Shortcuts Events**

## Step 3: Test It

```bash
# List all your shortcuts
macjuice shortcuts list

# Search for home-related ones
macjuice shortcuts search "lamp"

# Run it
macjuice home run "Lamp On"

# Or use the general shortcuts command
macjuice shortcuts run "Lamp On"
```

## Suggested Shortcuts for Home

| Shortcut Name | What It Does |
|---|---|
| `Lamp On` | Turn on lights |
| `Lamp Off` | Turn off lights |
| `Good Morning` | Morning scene (lights, music, etc.) |
| `Good Night` | Night scene (lights off, lock up) |
| `Movie Mode` | Dim lights for movies |

## Troubleshooting

### "Shortcut not found"
- Check the exact name: `macjuice shortcuts list`
- Names are case-sensitive

### "The shortcut cannot be run because an action could not be found"
- The shortcut references a device that's no longer in your Home
- **Fix:** Open the shortcut in Shortcuts app, delete the broken action, re-add your devices

### Shortcut runs but nothing happens
- Make sure your Home Hub (HomePod, Apple TV, or iPad) is online
- Check the Home app to verify your devices are responsive
- Try running the shortcut manually from the Shortcuts app first

### Permission denied
- Go to **System Settings → Privacy & Security → Automation**
- Enable **Shortcuts Events** for your terminal app
