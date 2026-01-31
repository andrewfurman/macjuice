#!/bin/bash
# messages-db.sh - Read messages via SQLite (faster + works on modern macOS)
# Requires Full Disk Access for Terminal/osascript

DB="$HOME/Library/Messages/chat.db"

if [[ ! -r "$DB" ]]; then
    echo "ERROR: Cannot read Messages database."
    echo "Grant Full Disk Access: System Settings > Privacy & Security > Full Disk Access > add Terminal"
    exit 1
fi

CMD="$1"
shift

case "$CMD" in
    read)
        # Read messages from a specific chat
        CHAT="$1"
        COUNT="${2:-10}"
        sqlite3 "$DB" "
            SELECT
                datetime(m.date/1000000000 + 978307200, 'unixepoch', 'localtime') as time,
                CASE WHEN m.is_from_me = 1 THEN 'Me' ELSE COALESCE(h.id, 'Unknown') END as sender,
                m.text
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE c.display_name LIKE '%${CHAT}%'
               OR c.chat_identifier LIKE '%${CHAT}%'
               OR h.id LIKE '%${CHAT}%'
            ORDER BY m.date DESC
            LIMIT $COUNT;
        " 2>&1 | while IFS='|' read -r time sender text; do
            echo "[$time] $sender: $text"
        done | tac
        ;;

    recent)
        # Recent messages across all chats
        COUNT="${1:-20}"
        sqlite3 "$DB" "
            SELECT
                datetime(m.date/1000000000 + 978307200, 'unixepoch', 'localtime') as time,
                COALESCE(c.display_name, h.id, 'Unknown') as chat,
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
        # Search messages
        QUERY="$1"
        sqlite3 "$DB" "
            SELECT
                datetime(m.date/1000000000 + 978307200, 'unixepoch', 'localtime') as time,
                COALESCE(c.display_name, h.id, 'Unknown') as chat,
                CASE WHEN m.is_from_me = 1 THEN 'Me' ELSE COALESCE(h.id, 'Unknown') END as sender,
                REPLACE(SUBSTR(m.text, 1, 100), CHAR(10), ' ') as text
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE m.text LIKE '%${QUERY}%'
            ORDER BY m.date DESC
            LIMIT 20;
        " 2>&1 | while IFS='|' read -r time chat sender text; do
            echo "[$time] $chat | $sender: $text"
        done
        ;;

    *)
        echo "Usage: messages-db.sh <read|recent|search> [args]"
        echo "  read <chat> [count]   Read messages from a chat"
        echo "  recent [count]        Recent messages across all chats"
        echo "  search <query>        Search message text"
        ;;
esac
