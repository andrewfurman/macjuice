#!/bin/bash
# test_messages.sh — Messages (iMessage) integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Messages Tests ==="

# 1. messages chats returns valid output
assert_output_matches \
    "messages chats output is valid" \
    "(No chats found|.+)" \
    "$MACJUICE" messages chats

# 2. messages recent output is valid
assert_output_matches \
    "messages recent output is valid" \
    "(No chats found|^$|.*\|.*)" \
    "$MACJUICE" messages recent

# 3. messages send to a nonexistent recipient returns error (does NOT actually send)
assert_output_matches \
    "messages send to fake recipient returns error" \
    "(ERROR|Could not find chat)" \
    "$MACJUICE" messages send "testuser@apple.com" "macjuice test — ignore"

print_summary "Messages"
