#!/bin/bash
# test_duplicate_contact_send.sh — Verify disambiguation error when sending
# a message to a name that matches multiple contacts.
#
# This test creates two "John Smith" contacts with different phone numbers,
# attempts to send a message by name, asserts that the multiple-match error
# is returned with contact details, and then cleans up the test contacts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Duplicate Contact Send Tests ==="

# --- Unique marker so we only delete contacts we created ---
_TAG="macjuicetest"
_FIRST="John"
_LAST1="Smith${_TAG}A"
_LAST2="Smith${_TAG}B"
_PHONE1="+15550001111"
_PHONE2="+15550002222"
_EMAIL1="johnsmitha_${_TAG}@example.com"
_EMAIL2="johnsmithb_${_TAG}@example.com"

# --- Helper: create a contact via osascript ---
create_contact() {
    local first="$1" last="$2" phone="$3" email="$4"
    osascript -e "
        tell application \"Contacts\"
            set newPerson to make new person with properties {first name:\"$first\", last name:\"$last\"}
            make new phone at end of phones of newPerson with properties {label:\"mobile\", value:\"$phone\"}
            make new email at end of emails of newPerson with properties {label:\"home\", value:\"$email\"}
            save
        end tell
    " 2>/dev/null
}

# --- Helper: delete contacts whose last name matches a pattern ---
cleanup_contacts() {
    osascript -e "
        tell application \"Contacts\"
            set victims to every person whose last name contains \"${_TAG}\"
            repeat with v in victims
                delete v
            end repeat
            save
        end tell
    " 2>/dev/null
}

# --- Setup: ensure Contacts.app is running, clean leftovers, create two John Smiths ---
open -a Contacts 2>/dev/null
sleep 2
cleanup_contacts >/dev/null
create_contact "$_FIRST" "$_LAST1" "$_PHONE1" "$_EMAIL1" >/dev/null
create_contact "$_FIRST" "$_LAST2" "$_PHONE2" "$_EMAIL2" >/dev/null

# Small delay to let Contacts.app sync
sleep 1

# --- Test 1: sending to the shared name triggers the multiple-match error ---
assert_output_matches \
    "duplicate name returns multiple-match error" \
    "ERROR.*Multiple contacts match" \
    "$MACJUICE" messages send "${_FIRST} Smith${_TAG}" "macjuice duplicate test — ignore"

# --- Test 2: the error output includes both phone numbers ---
_run_cmd "$MACJUICE" messages send "${_FIRST} Smith${_TAG}" "macjuice duplicate test — ignore"
_dup_output="$_CMD_OUTPUT"

_check_pass=0
if echo "$_dup_output" | grep -qF "$_PHONE1" && echo "$_dup_output" | grep -qF "$_PHONE2"; then
    echo -e "  ${_GREEN}PASS${_NC}  error output contains both phone numbers"
    ((_PASS++))
else
    echo -e "  ${_RED}FAIL${_NC}  error output contains both phone numbers"
    echo "        expected to find: $_PHONE1 and $_PHONE2"
    echo "        output:  ${_dup_output:-(empty)}"
    ((_FAIL++))
fi

# --- Test 3: the error output includes both emails ---
if echo "$_dup_output" | grep -qF "$_EMAIL1" && echo "$_dup_output" | grep -qF "$_EMAIL2"; then
    echo -e "  ${_GREEN}PASS${_NC}  error output contains both emails"
    ((_PASS++))
else
    echo -e "  ${_RED}FAIL${_NC}  error output contains both emails"
    echo "        expected to find: $_EMAIL1 and $_EMAIL2"
    echo "        output:  ${_dup_output:-(empty)}"
    ((_FAIL++))
fi

# --- Test 4: the error lists both contact names ---
if echo "$_dup_output" | grep -qF "$_LAST1" && echo "$_dup_output" | grep -qF "$_LAST2"; then
    echo -e "  ${_GREEN}PASS${_NC}  error output contains both contact names"
    ((_PASS++))
else
    echo -e "  ${_RED}FAIL${_NC}  error output contains both contact names"
    echo "        expected to find: $_LAST1 and $_LAST2"
    echo "        output:  ${_dup_output:-(empty)}"
    ((_FAIL++))
fi

# --- Cleanup: remove the test contacts ---
cleanup_contacts >/dev/null

print_summary "Duplicate Contact Send"
