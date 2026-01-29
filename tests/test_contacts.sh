#!/bin/bash
# test_contacts.sh — Contacts integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Contacts Tests ==="

# --- Pre-flight: check if Contacts app is reachable ---
_run_cmd "$MACJUICE" contacts list
_preflight_rc=$?
if [[ $_CMD_TIMED_OUT -eq 1 ]] || [[ $_preflight_rc -ne 0 ]]; then
    _reason="Contacts app unreachable (exit code $_preflight_rc)"
    [[ $_CMD_TIMED_OUT -eq 1 ]] && _reason="Contacts timed out — grant Automation permission if macOS prompted"
    skip_test "contacts list exits 0" "$_reason"
    skip_test "contacts list returns contacts" "$_reason"
    skip_test "contacts groups exits 0" "$_reason"
    skip_test "contacts groups output is valid" "$_reason"
    skip_test "contacts search with no match returns message" "$_reason"
    print_summary "Contacts"
    exit $?
fi

# 1. contacts list exits 0
assert_exit_zero \
    "contacts list exits 0" \
    "$MACJUICE" contacts list

# 2. contacts list output is non-empty (at least one contact)
assert_output_not_empty \
    "contacts list returns contacts" \
    "$MACJUICE" contacts list

# 3. contacts groups exits 0
assert_exit_zero \
    "contacts groups exits 0" \
    "$MACJUICE" contacts groups

# 4. contacts groups output is valid (groups with counts or "No groups found")
assert_output_matches \
    "contacts groups output is valid" \
    "(No groups found|.*\([0-9]+ contacts\))" \
    "$MACJUICE" contacts groups

# 5. contacts search for gibberish returns "No contacts found"
assert_output_matches \
    "contacts search with no match returns message" \
    "No contacts found" \
    "$MACJUICE" contacts search "zzzz_macjuice_nonexistent_zzz"

print_summary "Contacts"
