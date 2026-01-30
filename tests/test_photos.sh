#!/bin/bash
# test_photos.sh — Photos integration tests for macjuice
# Running these tests will trigger the macOS Automation permission prompt
# for Photos if it hasn't been granted yet.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Photos Tests ==="

# 1. photos albums exits 0
assert_exit_zero \
    "photos albums exits 0" \
    "$MACJUICE" photos albums

# 2. photos albums output is valid
assert_output_matches \
    "photos albums output format is valid" \
    "(items)|No albums found" \
    "$MACJUICE" photos albums

# 3. photos recent exits 0
assert_exit_zero \
    "photos recent exits 0" \
    "$MACJUICE" photos recent 5

# 4. photos recent returns results
assert_output_matches \
    "photos recent output format is valid" \
    "(\.heic|\.jpg|\.jpeg|\.png|\.mov|No photos)" \
    "$MACJUICE" photos recent 5

# 5. photos search exits 0
assert_exit_zero \
    "photos search exits 0" \
    "$MACJUICE" photos search "test_nonexistent_query_xyz"

# 6. photos search with no match returns message
assert_output_matches \
    "photos search with no match returns message" \
    "No photos found" \
    "$MACJUICE" photos search "test_nonexistent_query_xyz"

print_summary "Photos"
