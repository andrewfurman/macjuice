#!/bin/bash
# test_photos.sh — Photos integration tests for macjuice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Photos queries can be slow on large libraries.
_TIMEOUT="${MACJUICE_TEST_TIMEOUT:-120}"
_timeout_hint="timed out after ${_TIMEOUT}s — grant Automation permission if macOS prompted"

echo "=== Photos Tests ==="

# 1. photos albums returns valid output
assert_output_matches \
    "photos albums output is valid" \
    "(items)|No albums found" \
    "$MACJUICE" photos albums

# 2. photos search with no match returns message
assert_output_matches \
    "photos search with no match returns message" \
    "No photos found" \
    "$MACJUICE" photos search "test_nonexistent_query_xyz"

print_summary "Photos"
