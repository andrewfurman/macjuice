#!/bin/bash
# test_messages.sh — Messages (iMessage) integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Messages Tests ==="

# 1. messages chats exits 0
assert_exit_zero \
    "messages chats exits 0" \
    "$MACJUICE" messages chats

# 2. messages chats returns chat names or "No chats found"
assert_output_matches \
    "messages chats output is valid" \
    "(No chats found|.+)" \
    "$MACJUICE" messages chats

# 3. messages recent exits 0
assert_exit_zero \
    "messages recent exits 0" \
    "$MACJUICE" messages recent

# 4. messages recent output is pipe-delimited, empty, or no-chats message
assert_output_matches \
    "messages recent output format is valid" \
    "(No chats found|^$|.*\|.*\|.*)" \
    "$MACJUICE" messages recent

# 5. messages send to a nonexistent recipient returns error (does NOT actually send)
assert_output_matches \
    "messages send to fake recipient returns error" \
    "(ERROR|Could not find chat)" \
    "$MACJUICE" messages send "testuser@apple.com" "macjuice test — ignore"

print_summary "Messages"
