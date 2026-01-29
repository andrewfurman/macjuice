#!/bin/bash
# run_all.sh — Discover and run all macjuice test suites

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

overall=0

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    [[ -f "$test_file" ]] || continue
    echo ""
    bash "$test_file"
    rc=$?
    if [[ $rc -ne 0 ]]; then
        overall=1
    fi
done

echo ""
if [[ $overall -eq 0 ]]; then
    echo "=== ALL SUITES PASSED ==="
else
    echo "=== SOME SUITES FAILED ==="
fi

exit $overall
