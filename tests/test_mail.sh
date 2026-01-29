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

print_summary "Mail"
