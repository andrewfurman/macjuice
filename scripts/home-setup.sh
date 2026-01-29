#!/bin/bash
# home-setup.sh
# Sets up HomeKit shortcuts for apple-cli integration
#
# Since Apple doesn't allow fully programmatic shortcut creation,
# this script uses a hybrid approach:
# 1. Opens Shortcuts app to the "create" screen
# 2. Provides instructions for what actions to add
# 3. For pre-made shortcuts, triggers the import dialog

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHORTCUTS_DIR="$SCRIPT_DIR/shortcuts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          apple-cli HomeKit Shortcuts Setup                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Shortcuts app is available
if ! command -v shortcuts &> /dev/null; then
    echo -e "${RED}Error: 'shortcuts' command not found.${NC}"
    echo "Make sure you're running macOS 12 (Monterey) or later."
    exit 1
fi

# List existing HomeKit shortcuts
echo -e "${YELLOW}Checking existing HomeKit shortcuts...${NC}"
existing=$(shortcuts list | grep -i "^homekit-" || true)
if [ -n "$existing" ]; then
    echo -e "${GREEN}Found existing shortcuts:${NC}"
    echo "$existing" | sed 's/^/  ✓ /'
    echo ""
fi

# Check for .shortcut files to import
if [ -d "$SHORTCUTS_DIR" ] && [ "$(ls -A "$SHORTCUTS_DIR"/*.shortcut 2>/dev/null)" ]; then
    echo -e "${YELLOW}Found shortcut files to import:${NC}"
    for file in "$SHORTCUTS_DIR"/*.shortcut; do
        filename=$(basename "$file")
        echo "  - $filename"
    done
    echo ""
    echo -e "${BLUE}Importing shortcuts...${NC}"
    echo "(Each shortcut will open an import dialog - click 'Add Shortcut' to confirm)"
    echo ""

    for file in "$SHORTCUTS_DIR"/*.shortcut; do
        filename=$(basename "$file" .shortcut)
        echo -n "  Importing $filename... "
        open "$file"
        sleep 2  # Give time for the dialog to appear
        echo -e "${GREEN}dialog opened${NC}"
    done

    echo ""
    echo -e "${YELLOW}Please confirm each import in the dialogs that appeared.${NC}"
else
    echo -e "${YELLOW}No pre-made shortcut files found.${NC}"
    echo "You'll need to create HomeKit shortcuts manually."
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}MANUAL SETUP: Create these shortcuts in Shortcuts.app${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "For full HomeKit control, create these shortcuts:"
echo ""
echo -e "${GREEN}1. homekit-lights-on${NC}"
echo "   Actions: Control [Your Lights] → Turn On"
echo ""
echo -e "${GREEN}2. homekit-lights-off${NC}"
echo "   Actions: Control [Your Lights] → Turn Off"
echo ""
echo -e "${GREEN}3. homekit-good-morning${NC}"
echo "   Actions: Control Home → Run [Good Morning scene]"
echo ""
echo -e "${GREEN}4. homekit-good-night${NC}"
echo "   Actions: Control Home → Run [Good Night scene]"
echo ""
echo -e "${GREEN}5. homekit-scene${NC} (generic scene runner)"
echo "   Actions:"
echo "   - Receive [Text] input from [Share Sheet, Quick Actions]"
echo "   - Control Home → Run scene named [Shortcut Input]"
echo ""
echo -e "${GREEN}6. homekit-device${NC} (generic device controller)"
echo "   Actions:"
echo "   - Receive [Text] input"
echo "   - Control [Your Device] → Set to [Shortcut Input]"
echo ""

# Offer to open Shortcuts app
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "Would you like to open Shortcuts app now? [Y/n] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "Opening Shortcuts app..."
    open "shortcuts://create-shortcut"
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Once you've created your shortcuts, test with:"
echo "  shortcuts run 'homekit-lights-on'"
echo ""
echo "Or via apple-cli:"
echo "  apple home run lights-on"
echo ""
