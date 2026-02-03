#!/bin/bash
# test_cli.sh — CLI entry point tests for macjuice (no AppleScript, runs instantly)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== CLI Tests ==="

# 1. --version prints version string
assert_output_matches \
    "--version prints version" \
    "macjuice v[0-9]" \
    "$MACJUICE" --version

# 2. --help lists available apps
assert_output_matches \
    "--help lists available apps" \
    "Available apps:" \
    "$MACJUICE" --help

# 3. app-specific help lists commands
assert_output_matches \
    "app help lists commands" \
    "Commands:" \
    "$MACJUICE" mail --help

# 4. unknown app exits non-zero
_run_cmd "$MACJUICE" fakefoobar list
if [[ $? -ne 0 ]]; then
    echo -e "  ${_GREEN}PASS${_NC}  unknown app exits non-zero"
    ((_PASS++))
else
    echo -e "  ${_RED}FAIL${_NC}  unknown app exits non-zero"
    ((_FAIL++))
fi

print_summary "CLI"
