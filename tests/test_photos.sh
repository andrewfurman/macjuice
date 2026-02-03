#!/bin/bash
# test_photos.sh — Photos integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "=== Photos Tests ==="

# 1. photos albums returns valid output
assert_output_matches \
    "photos albums output is valid" \
    "(items)|No albums found" \
    "$MACJUICE" photos albums

# 2. photos recent returns valid output
assert_output_matches \
    "photos recent output is valid" \
    "(\.heic|\.jpg|\.jpeg|\.png|\.mov|No photos)" \
    "$MACJUICE" photos recent 5

# 3. photos search with no match returns message
assert_output_matches \
    "photos search with no match returns message" \
    "No photos found" \
    "$MACJUICE" photos search "test_nonexistent_query_xyz"

print_summary "Photos"
