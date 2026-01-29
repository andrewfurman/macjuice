#!/bin/bash
# test_reminders.sh — Reminders integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Reminders Tests ==="

# 1. reminders lists exits 0
assert_exit_zero \
    "reminders lists exits 0" \
    "$MACJUICE" reminders lists

# 2. reminders lists output contains incomplete counts
assert_output_matches \
    "reminders lists shows incomplete counts" \
    ".*incomplete\)" \
    "$MACJUICE" reminders lists

# 3. reminders today exits 0
assert_exit_zero \
    "reminders today exits 0" \
    "$MACJUICE" reminders today

# 4. reminders today output is valid
assert_output_matches \
    "reminders today output is valid" \
    "(No reminders due today|☐)" \
    "$MACJUICE" reminders today

# 5. reminders search for gibberish returns "No reminders found"
assert_output_matches \
    "reminders search with no match returns message" \
    "No reminders found" \
    "$MACJUICE" reminders search "zzzz_macjuice_nonexistent_zzz"

print_summary "Reminders"
