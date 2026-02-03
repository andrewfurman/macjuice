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

# 4. mail list output is either "No messages" or pipe-delimited message rows (4+ fields)
assert_output_matches \
    "mail list output format is valid" \
    "(No messages found|.*\|.*\|.*\|)" \
    "$MACJUICE" mail list

# 5. mail draft exits 0
assert_exit_zero \
    "mail draft exits 0" \
    "$MACJUICE" mail draft "test@example.com" "macjuice test draft" "This is an automated test draft from macjuice."

# 6. mail draft output confirms success
assert_output_matches \
    "mail draft output confirms draft saved" \
    "OK:.*Draft saved" \
    "$MACJUICE" mail draft "test@example.com" "macjuice test draft" "This is an automated test draft from macjuice."

# 7. mail help includes draft command
assert_output_matches \
    "mail help includes draft command" \
    "draft.*Save a draft" \
    "$MACJUICE" mail --help

# 8. mail draft with --cc exits 0
assert_exit_zero \
    "mail draft with --cc exits 0" \
    "$MACJUICE" mail draft "test@example.com" "macjuice cc test" "Testing CC" --cc "cc1@example.com"

# 9. mail draft with --cc output shows cc recipient
assert_output_matches \
    "mail draft with --cc shows cc in output" \
    "cc:cc1@example.com" \
    "$MACJUICE" mail draft "test@example.com" "macjuice cc test" "Testing CC" --cc "cc1@example.com"

# 10. mail draft with multiple comma-separated --cc exits 0
assert_exit_zero \
    "mail draft with multiple --cc exits 0" \
    "$MACJUICE" mail draft "test@example.com" "macjuice multi-cc test" "Testing multi CC" --cc "cc1@example.com,cc2@example.com"

# 11. mail draft with multiple --cc shows cc in output
assert_output_matches \
    "mail draft with multiple --cc shows all in output" \
    "cc:cc1@example.com,cc2@example.com" \
    "$MACJUICE" mail draft "test@example.com" "macjuice multi-cc test" "Testing multi CC" --cc "cc1@example.com,cc2@example.com"

# 12. mail draft with --bcc exits 0
assert_exit_zero \
    "mail draft with --bcc exits 0" \
    "$MACJUICE" mail draft "test@example.com" "macjuice bcc test" "Testing BCC" --bcc "bcc1@example.com"

# 13. mail draft with --bcc output shows bcc recipient
assert_output_matches \
    "mail draft with --bcc shows bcc in output" \
    "bcc:bcc1@example.com" \
    "$MACJUICE" mail draft "test@example.com" "macjuice bcc test" "Testing BCC" --bcc "bcc1@example.com"

# 14. mail draft with both --cc and --bcc exits 0
assert_exit_zero \
    "mail draft with --cc and --bcc exits 0" \
    "$MACJUICE" mail draft "test@example.com" "macjuice cc+bcc test" "Testing CC and BCC" --cc "cc1@example.com,cc2@example.com" --bcc "bcc1@example.com"

# 15. mail draft with both --cc and --bcc shows both in output
assert_output_matches \
    "mail draft with --cc and --bcc shows both in output" \
    "cc:.*bcc:" \
    "$MACJUICE" mail draft "test@example.com" "macjuice cc+bcc test" "Testing CC and BCC" --cc "cc1@example.com,cc2@example.com" --bcc "bcc1@example.com"

# 16. mail help includes reply command
assert_output_matches \
    "mail help includes reply command" \
    "reply.*Reply to a message" \
    "$MACJUICE" mail --help

# 17. mail help includes reply CC/BCC options
assert_output_matches \
    "mail help shows reply --cc option" \
    "cc.*recipients" \
    "$MACJUICE" mail --help

# 18. mail help includes reply --bcc option
assert_output_matches \
    "mail help shows reply --bcc option" \
    "bcc.*recipients" \
    "$MACJUICE" mail --help

# 19. mail help includes delete-draft command
assert_output_matches \
    "mail help includes delete-draft command" \
    "delete-draft.*Delete a draft" \
    "$MACJUICE" mail --help

# 20. mail list Drafts exits 0 (verifies Drafts mailbox is accessible)
assert_exit_zero \
    "mail list Drafts exits 0" \
    "$MACJUICE" mail list Drafts

# End-to-end delete-draft testing is covered by test_mail_draft.sh

print_summary "Mail"
