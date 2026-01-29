#!/bin/bash
# install.sh - Install macjuice CLI
# https://github.com/andrewfurman/macjuice

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                    macjuice installer                     ║"
echo "║       CLI for Apple apps on macOS via AppleScript         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACJUICE_BIN="$SCRIPT_DIR/macjuice"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error:${NC} macjuice only works on macOS."
    exit 1
fi

# Make the main script executable
echo -e "${BLUE}Making macjuice executable...${NC}"
chmod +x "$MACJUICE_BIN"
chmod +x "$SCRIPT_DIR/scripts/home-setup.sh"

# Determine install location
INSTALL_DIR="/usr/local/bin"
if [[ ! -d "$INSTALL_DIR" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
fi

# Check if we can write to install dir
if [[ ! -w "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Note:${NC} Installing to $INSTALL_DIR requires sudo."
    NEEDS_SUDO=true
else
    NEEDS_SUDO=false
fi

# Create symlink
echo -e "${BLUE}Installing macjuice to $INSTALL_DIR...${NC}"
SYMLINK_PATH="$INSTALL_DIR/macjuice"

if [[ -L "$SYMLINK_PATH" ]] || [[ -f "$SYMLINK_PATH" ]]; then
    echo -e "${YELLOW}Removing existing installation...${NC}"
    if $NEEDS_SUDO; then
        sudo rm -f "$SYMLINK_PATH"
    else
        rm -f "$SYMLINK_PATH"
    fi
fi

if $NEEDS_SUDO; then
    sudo ln -s "$MACJUICE_BIN" "$SYMLINK_PATH"
else
    ln -s "$MACJUICE_BIN" "$SYMLINK_PATH"
fi

# Verify installation
if command -v macjuice &> /dev/null; then
    echo -e "${GREEN}✓ macjuice installed successfully!${NC}"
else
    # Check if install dir is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo -e "${YELLOW}Note:${NC} Add $INSTALL_DIR to your PATH:"
        echo ""
        echo "  # Add to ~/.zshrc or ~/.bashrc:"
        echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        echo ""
    fi
    echo -e "${GREEN}✓ macjuice installed to $SYMLINK_PATH${NC}"
fi

echo ""
echo -e "${CYAN}Quick start:${NC}"
echo ""
echo "  macjuice --help              # Show all commands"
echo "  macjuice mail accounts       # List email accounts"
echo "  macjuice notes list          # List notes"
echo "  macjuice calendar today      # Today's events"
echo "  macjuice music now           # Current track"
echo "  macjuice contacts search \"John\""
echo "  macjuice reminders all       # All reminders"
echo ""
echo -e "${YELLOW}HomeKit setup:${NC}"
echo "  macjuice home setup          # Configure HomeKit shortcuts"
echo ""
echo -e "${BLUE}Permissions:${NC}"
echo "On first use, macOS will ask for Automation permissions."
echo "Grant access to allow macjuice to control apps."
echo ""
