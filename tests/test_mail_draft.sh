#!/bin/bash
# test_mail_draft.sh — Test macjuice mail draft create + verify + delete
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

# 2. Wait for Mail to sync the draft to the mailbox
echo -n "Waiting for sync... "
sleep 10
echo "done"

# Verify draft exists by searching Drafts mailboxes directly via AppleScript
# This avoids IMAP sync latency by searching the local mailbox immediately
echo -n "Verifying draft in Drafts folder... "
FOUND=$(osascript -e "
tell application \"Mail\"
    repeat with acc in accounts
        try
            set mb to mailbox \"Drafts\" of acc
            set msgs to (every message of mb whose subject contains \"${TIMESTAMP}\")
            if (count of msgs) > 0 then
                return id of item 1 of msgs as text
            end if
        end try
    end repeat
    return \"\"
end tell" 2>/dev/null)

if [[ -n "$FOUND" ]]; then
    echo -e "${GREEN}PASS${NC} (id: $FOUND)"
else
    echo -e "${RED}FAIL${NC} — draft not found in Drafts mailbox"
    exit 1
fi

# Delete the test draft
echo -n "Deleting draft... "
DEL_OUTPUT=$("$MACJUICE" mail delete-draft "$FOUND" 2>&1)
if echo "$DEL_OUTPUT" | grep -q "OK:"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} — $DEL_OUTPUT"
    exit 1
fi

# Verify draft is gone
echo -n "Verifying deletion... "
STILL_THERE=$(osascript -e "
tell application \"Mail\"
    repeat with acc in accounts
        try
            set mb to mailbox \"Drafts\" of acc
            set msgs to (every message of mb whose subject contains \"${TIMESTAMP}\")
            if (count of msgs) > 0 then return \"found\"
        end try
    end repeat
    return \"gone\"
end tell" 2>/dev/null)

if [[ "$STILL_THERE" == "gone" ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} — draft still exists after deletion"
    exit 1
fi

echo ""
echo -e "${GREEN}All tests passed!${NC}"
