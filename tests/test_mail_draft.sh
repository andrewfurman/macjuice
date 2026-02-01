#!/bin/bash
# test_mail_draft.sh — Test macjuice mail draft command
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACJUICE="$SCRIPT_DIR/macjuice"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TIMESTAMP=$(date +%s)
SUBJECT="MacJuice Draft Test ${TIMESTAMP}"
BODY="Automated test draft created at $(date)"
TO="test-draft-${TIMESTAMP}@example.com"

echo "=== MacJuice mail draft test ==="
echo "Subject: $SUBJECT"
echo ""

# 1. Create a draft
echo -n "Creating draft... "
OUTPUT=$("$MACJUICE" mail draft "$TO" "$SUBJECT" "$BODY" 2>&1)
if echo "$OUTPUT" | grep -q "OK:"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} — $OUTPUT"
    exit 1
fi

# 2. Wait for IMAP sync
echo -n "Waiting for sync... "
sleep 2
echo "done"

# 3. Search for the draft in [Gmail]/Drafts via himalaya
echo -n "Verifying draft in Drafts folder... "
FOUND=$(himalaya envelope list -f "[Gmail]/Drafts" -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for e in data:
    if '${TIMESTAMP}' in e.get('subject',''):
        print(e['id'])
        break
" 2>/dev/null)

if [[ -n "$FOUND" ]]; then
    echo -e "${GREEN}PASS${NC} (id: $FOUND)"
else
    echo -e "${RED}FAIL${NC} — draft not found in [Gmail]/Drafts"
    exit 1
fi

# 4. Cleanup — delete the test draft
echo -n "Cleaning up... "
himalaya flag add -f "[Gmail]/Drafts" "$FOUND" -- deleted 2>/dev/null && echo "done" || echo "skipped"

echo ""
echo -e "${GREEN}All tests passed!${NC}"
