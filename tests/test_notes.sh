#!/bin/bash
# test_notes.sh — Notes integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Notes search iterates all notes checking plaintext — can be slow with many notes.
_TIMEOUT="${MACJUICE_TEST_TIMEOUT:-120}"
_timeout_hint="timed out after ${_TIMEOUT}s — grant Automation permission if macOS prompted"

echo "=== Notes Tests ==="

# 1. notes list output is pipe-delimited (id | date | name)
assert_output_matches \
    "notes list output is valid" \
    ".*\|.*\|.*" \
    "$MACJUICE" notes list

# 2. notes folders shows note counts
assert_output_matches \
    "notes folders shows note counts" \
    ".*\([0-9]+ notes\)" \
    "$MACJUICE" notes folders

# 3. notes search for gibberish returns "No notes found"
assert_output_matches \
    "notes search with no match returns message" \
    "No notes found" \
    "$MACJUICE" notes search "zzzz_macjuice_nonexistent_zzz"

print_summary "Notes"
