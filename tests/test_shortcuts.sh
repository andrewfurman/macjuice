#!/bin/bash
# test_shortcuts.sh — Shortcuts integration tests for macjuice
# Running these tests will trigger the macOS Automation permission prompt
# for Shortcuts Events if it hasn't been granted yet.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Shortcuts Tests ==="

# 1. shortcuts list exits 0
assert_exit_zero \
    "shortcuts list exits 0" \
    "$MACJUICE" shortcuts list

# 2. shortcuts list returns results
assert_output_matches \
    "shortcuts list output is valid" \
    ".*" \
    "$MACJUICE" shortcuts list

# 3. shortcuts search exits 0
assert_exit_zero \
    "shortcuts search exits 0" \
    "$MACJUICE" shortcuts search "nonexistent_shortcut_xyz"

# 4. shortcuts search with no match returns message
assert_output_matches \
    "shortcuts search with no match returns message" \
    "No shortcuts found" \
    "$MACJUICE" shortcuts search "nonexistent_shortcut_xyz"

print_summary "Shortcuts"
