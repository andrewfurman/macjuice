# HomeKit Shortcuts

This folder contains definitions for HomeKit shortcuts used by apple-cli.

## Why Not .shortcut Files?

Apple requires shortcuts to be **signed** before they can be shared. The signing process:
1. Requires an Apple Developer account
2. Embeds the signer's identity in the file
3. Shows a "created by [name]" notice when imported

Instead, we provide **shortcut definitions** that you can quickly recreate.

## Quick Setup

Run the setup script:
```bash
./scripts/home-setup.sh
```

Or create manually in Shortcuts.app:

### 1. homekit-lights-on
- New Shortcut → Search "Control"
- Add "Control [Your Home]"
- Select your lights → Turn On
- Rename to: `homekit-lights-on`

### 2. homekit-lights-off
Same as above, but Turn Off

### 3. homekit-good-morning
- Add "Control [Your Home]"
- Select: Run Scene → "Good Morning" (or your morning scene)
- Rename to: `homekit-good-morning`

### 4. homekit-good-night
Same pattern for your evening scene

### 5. homekit-thermostat-set
- Add "Receive Input" → Text
- Add "Control [Your Thermostat]"
- Set temperature to: Shortcut Input
- Rename to: `homekit-thermostat-set`

Usage: `shortcuts run "homekit-thermostat-set" <<< "72"`

### 6. homekit-scene (Generic)
- Add "Receive Input" → Text
- Add "Control [Your Home]" → Run Scene
- Scene name: Shortcut Input
- Rename to: `homekit-scene`

Usage: `shortcuts run "homekit-scene" <<< "Movie Night"`

## Exporting Your Shortcuts

Once created, you can export your shortcuts to share:
```bash
# Sign and export a shortcut
shortcuts sign --mode anyone --input "homekit-lights-on" --output "homekit-lights-on.shortcut"
```

## Testing

```bash
# List all HomeKit shortcuts
shortcuts list | grep homekit

# Run a shortcut
shortcuts run "homekit-lights-on"

# Run with input
echo "72" | shortcuts run "homekit-thermostat-set"
```
