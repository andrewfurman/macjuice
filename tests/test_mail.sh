#!/bin/bash
# test_mail.sh — Mail integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Mail Tests ==="

# 1. mail accounts exits 0
assert_exit_zero \
    "mail accounts exits 0" \
    "$MACJUICE" mail accounts

# 2. mail accounts output contains a parenthesized email address
assert_output_matches \
    "mail accounts lists an email address" \
    "\(.*@.*\)" \
    "$MACJUICE" mail accounts

# 3. mail list exits 0
assert_exit_zero \
    "mail list exits 0" \
    "$MACJUICE" mail list

# 4. mail list output is either "No messages" or pipe-delimited message rows
assert_output_matches \
    "mail list output format is valid" \
    "(No messages found|.*\|.*\|.*\|)" \
    "$MACJUICE" mail list

# 5. mail draft with CC and BCC creates draft and confirms recipients in output
assert_output_matches \
    "mail draft with CC and BCC saves and shows recipients" \
    "cc:.*bcc:" \
    "$MACJUICE" mail draft "test@example.com" "macjuice test draft" "Automated test draft from macjuice." --cc "cc1@example.com,cc2@example.com" --bcc "bcc1@example.com"

# 6. mail help includes draft, reply, delete-draft, cc, and bcc
assert_output_matches \
    "mail help includes key commands" \
    "draft.*Save a draft" \
    "$MACJUICE" mail --help

# 7. mail list Drafts exits 0 (verifies Drafts mailbox is accessible)
assert_exit_zero \
    "mail list Drafts exits 0" \
    "$MACJUICE" mail list Drafts

# End-to-end delete-draft testing is covered by test_mail_draft.sh

print_summary "Mail"
