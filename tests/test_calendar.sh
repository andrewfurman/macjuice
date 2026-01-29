#!/bin/bash
# test_calendar.sh — Calendar integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Calendar queries can be slow (iterates all calendars, some may be syncing).
# Use a longer timeout than the default if not explicitly overridden.
_TIMEOUT="${MACJUICE_TEST_TIMEOUT:-120}"
_timeout_hint="timed out after ${_TIMEOUT}s — grant Automation permission if macOS prompted"

echo "=== Calendar Tests ==="

# 1. calendar list outputs bracket format (fast — validates basic connectivity)
assert_output_matches \
    "calendar list shows calendars in bracket format" \
    "\[.*\]" \
    "$MACJUICE" calendar list

# 2. calendar today exits 0
assert_exit_zero \
    "calendar today exits 0" \
    "$MACJUICE" calendar today

# 3. calendar today output is either "No events" or pipe-delimited event rows
assert_output_matches \
    "calendar today output format is valid" \
    "(No events found|.*\|.*)" \
    "$MACJUICE" calendar today

print_summary "Calendar"
