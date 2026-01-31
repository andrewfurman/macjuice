#!/bin/bash
# messages-db.sh - Read iMessage/SMS history via SQLite (chat.db)
# Much faster and more reliable than AppleScript for reading messages.
#
# REQUIREMENT: Full Disk Access for Terminal.app (or whichever terminal runs this)
#   System Settings > Privacy & Security > Full Disk Access > + > /Applications/Utilities/Terminal.app
#
# Sending still uses AppleScript (messages.applescript) — SQLite is read-only.

DB="$HOME/Library/Messages/chat.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ ! -r "$DB" ]]; then
    echo -e "${RED}ERROR:${NC} Cannot read Messages database at $DB"
    echo ""
    echo "To fix this, grant Full Disk Access to your terminal:"
    echo "  1. Open System Settings > Privacy & Security > Full Disk Access"
    echo "  2. Click the + button"
    echo "  3. Add /Applications/Utilities/Terminal.app (or your terminal app)"
    echo "  4. Restart your terminal"
    echo ""
    echo "See: https://github.com/andrewfurman/macjuice#permissions"
    exit 1
fi

CMD="$1"
shift

# Escape single quotes for safe SQL interpolation
sql_escape() {
    echo "$1" | sed "s/'/''/g"
}

case "$CMD" in
    chats)
        # List all chats with last message time and participant info
        COUNT="${1:-30}"
        sqlite3 -separator '|' "$DB" "
            SELECT
                c.chat_identifier,
                COALESCE(c.display_name, '') as display_name,
                datetime(MAX(m.date)/1000000000 + 978307200, 'unixepoch', 'localtime') as last_msg,
                COUNT(m.ROWID) as msg_count,
                REPLACE(SUBSTR(
                    (SELECT m2.text FROM message m2
                     JOIN chat_message_join cmj2 ON m2.ROWID = cmj2.message_id
                     WHERE cmj2.chat_id = c.ROWID AND m2.text IS NOT NULL
                     ORDER BY m2.date DESC LIMIT 1),
                    1, 60), CHAR(10), ' ') as last_text
            FROM chat c
            LEFT JOIN chat_message_join cmj ON c.ROWID = cmj.chat_id
            LEFT JOIN message m ON cmj.message_id = m.ROWID
            GROUP BY c.ROWID
            HAVING msg_count > 0
            ORDER BY MAX(m.date) DESC
            LIMIT $COUNT;
        " 2>&1 | while IFS='|' read -r identifier display_name last_msg msg_count last_text; do
            if [[ -n "$display_name" ]]; then
                echo "[$last_msg] $display_name ($identifier) — $msg_count msgs — $last_text"
            else
                echo "[$last_msg] $identifier — $msg_count msgs — $last_text"
            fi
        done
        ;;

    read)
        # Read messages from a specific chat (by phone, email, or display name)
        CHAT="$1"
        COUNT="${2:-20}"
        if [[ -z "$CHAT" ]]; then
            echo "Usage: macjuice messages read <chat> [count]"
            echo "  <chat> can be a phone number, email, or group name"
            exit 1
        fi
        CHAT_ESC=$(sql_escape "$CHAT")
        sqlite3 -separator '|' "$DB" "
            SELECT
                datetime(m.date/1000000000 + 978307200, 'unixepoch', 'localtime') as time,
                CASE WHEN m.is_from_me = 1 THEN 'Me' ELSE COALESCE(h.id, 'Unknown') END as sender,
                m.text
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE (c.display_name LIKE '%${CHAT_ESC}%'
               OR c.chat_identifier LIKE '%${CHAT_ESC}%'
               OR h.id LIKE '%${CHAT_ESC}%')
               AND m.text IS NOT NULL AND m.text != ''
            ORDER BY m.date DESC
            LIMIT $COUNT;
        " 2>&1 | while IFS='|' read -r time sender text; do
            echo "[$time] $sender: $text"
        done | tac
        ;;

    recent)
        # Recent messages across all chats
        COUNT="${1:-20}"
        sqlite3 -separator '|' "$DB" "
            SELECT
                datetime(m.date/1000000000 + 978307200, 'unixepoch', 'localtime') as time,
                COALESCE(NULLIF(c.display_name, ''), h.id, 'Unknown') as chat,
                CASE WHEN m.is_from_me = 1 THEN 'Me' ELSE COALESCE(h.id, 'Unknown') END as sender,
                REPLACE(SUBSTR(m.text, 1, 80), CHAR(10), ' ') as text
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE m.text IS NOT NULL AND m.text != ''
            ORDER BY m.date DESC
            LIMIT $COUNT;
        " 2>&1 | while IFS='|' read -r time chat sender text; do
            echo "[$time] $chat | $sender: $text"
        done
        ;;

    search)
        # Search messages by text content
        QUERY="$1"
        COUNT="${2:-20}"
        if [[ -z "$QUERY" ]]; then
            echo "Usage: macjuice messages search <query> [count]"
            exit 1
        fi
        QUERY_ESC=$(sql_escape "$QUERY")
        sqlite3 -separator '|' "$DB" "
            SELECT
                datetime(m.date/1000000000 + 978307200, 'unixepoch', 'localtime') as time,
                COALESCE(NULLIF(c.display_name, ''), h.id, 'Unknown') as chat,
                CASE WHEN m.is_from_me = 1 THEN 'Me' ELSE COALESCE(h.id, 'Unknown') END as sender,
                REPLACE(SUBSTR(m.text, 1, 100), CHAR(10), ' ') as text
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE m.text LIKE '%${QUERY_ESC}%'
            ORDER BY m.date DESC
            LIMIT $COUNT;
        " 2>&1 | while IFS='|' read -r time chat sender text; do
            echo "[$time] $chat | $sender: $text"
        done
        ;;

    info)
        # Show database stats
        TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM message;")
        CHATS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM chat;")
        HANDLES=$(sqlite3 "$DB" "SELECT COUNT(*) FROM handle;")
        FIRST=$(sqlite3 "$DB" "SELECT datetime(MIN(date)/1000000000 + 978307200, 'unixepoch', 'localtime') FROM message WHERE date > 0;")
        LAST=$(sqlite3 "$DB" "SELECT datetime(MAX(date)/1000000000 + 978307200, 'unixepoch', 'localtime') FROM message;")
        SIZE=$(du -h "$DB" | cut -f1)
        echo "Messages Database Info:"
        echo "  Total messages: $TOTAL"
        echo "  Total chats:    $CHATS"
        echo "  Total contacts: $HANDLES"
        echo "  First message:  $FIRST"
        echo "  Last message:   $LAST"
        echo "  Database size:  $SIZE"
        ;;

    *)
        echo "Usage: macjuice messages <command> [args]"
        echo ""
        echo "Read commands (SQLite — fast):"
        echo "  chats [count]          List chats with last message (default: 30)"
        echo "  read <chat> [count]    Read messages from a chat (default: 20)"
        echo "  recent [count]         Recent messages across all chats (default: 20)"
        echo "  search <query> [count] Search message text (default: 20)"
        echo "  info                   Show database stats"
        echo ""
        echo "Write commands (AppleScript):"
        echo "  send <to> <message>    Send a message (phone, email, or contact name)"
        echo ""
        echo "Requires Full Disk Access for Terminal.app"
        exit 1
        ;;
esac
