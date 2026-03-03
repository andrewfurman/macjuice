#!/bin/bash
# mail-db.sh - Fast mail search/list via Apple Mail's Envelope Index SQLite database
# Returns exit code 1 when SQLite is unavailable so the caller can fall back to AppleScript.
#
# Apple Mail stores metadata in ~/Library/Mail/V*/MailData/Envelope Index
# This is dramatically faster than iterating via AppleScript whose clauses.
#
# REQUIREMENT: Full Disk Access for your terminal app
#   System Settings > Privacy & Security > Full Disk Access

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Core Data epoch offset: seconds between Unix epoch (1970-01-01) and Apple epoch (2001-01-01)
CORE_DATA_EPOCH=978307200

# Find the Envelope Index database
find_mail_db() {
    local db_path=""
    # Try common macOS Mail data versions (newest first)
    for version in V10 V11 V9 V8 V7 V6 V5; do
        local candidate="$HOME/Library/Mail/${version}/MailData/Envelope Index"
        if [[ -r "$candidate" ]]; then
            db_path="$candidate"
            break
        fi
    done
    echo "$db_path"
}

# Copy database to temp file to avoid locking issues with Mail.app
setup_temp_db() {
    local src_db="$1"
    local tmp_db="/tmp/macjuice_mail_index_$$.db"

    # Copy the database and its WAL/SHM files if they exist
    cp "$src_db" "$tmp_db" 2>/dev/null || return 1
    [[ -f "${src_db}-wal" ]] && cp "${src_db}-wal" "${tmp_db}-wal" 2>/dev/null
    [[ -f "${src_db}-shm" ]] && cp "${src_db}-shm" "${tmp_db}-shm" 2>/dev/null

    echo "$tmp_db"
}

# Clean up temp database files
cleanup_temp_db() {
    local tmp_db="$1"
    [[ -n "$tmp_db" && -f "$tmp_db" ]] && rm -f "$tmp_db" "${tmp_db}-wal" "${tmp_db}-shm" 2>/dev/null
}

# Escape single quotes for safe SQL interpolation
sql_escape() {
    echo "$1" | sed "s/'/''/g"
}

# Validate that the database has the expected schema (messages, subjects, addresses tables)
validate_schema() {
    local db="$1"
    local tables
    tables=$(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('messages','subjects','addresses','mailboxes');" 2>/dev/null)
    # We need at least messages and subjects tables
    if echo "$tables" | grep -q "messages" && echo "$tables" | grep -q "subjects"; then
        return 0
    fi
    return 1
}

# Check if the recipients table exists (for to: searches)
has_recipients_table() {
    local db="$1"
    sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='recipients';" 2>/dev/null | grep -q "recipients"
}

# List recent messages from a mailbox via SQLite
# Output format matches AppleScript: message_id | date | sender | subject
do_list() {
    local mailbox_name="$1"
    local limit="${2:-20}"
    local src_db
    src_db=$(find_mail_db)

    if [[ -z "$src_db" ]]; then
        return 1  # Signal caller to fall back to AppleScript
    fi

    local tmp_db
    tmp_db=$(setup_temp_db "$src_db")
    if [[ -z "$tmp_db" || ! -f "$tmp_db" ]]; then
        return 1
    fi

    # Validate schema before querying
    if ! validate_schema "$tmp_db"; then
        cleanup_temp_db "$tmp_db"
        return 1
    fi

    # Map common mailbox names to URL patterns
    local mailbox_filter=""
    case "$mailbox_name" in
        INBOX|inbox|Inbox)
            mailbox_filter="mb.url LIKE '%INBOX%'"
            ;;
        Drafts|drafts)
            mailbox_filter="(mb.url LIKE '%Drafts%' OR mb.url LIKE '%drafts%')"
            ;;
        Sent|sent|"Sent Messages"|"Sent Mail")
            mailbox_filter="(mb.url LIKE '%Sent%' OR mb.url LIKE '%sent%')"
            ;;
        Trash|trash)
            mailbox_filter="(mb.url LIKE '%Trash%' OR mb.url LIKE '%trash%' OR mb.url LIKE '%Deleted%')"
            ;;
        Junk|junk|Spam|spam)
            mailbox_filter="(mb.url LIKE '%Junk%' OR mb.url LIKE '%junk%' OR mb.url LIKE '%Spam%')"
            ;;
        Archive|archive)
            mailbox_filter="(mb.url LIKE '%Archive%' OR mb.url LIKE '%archive%' OR mb.url LIKE '%All Mail%')"
            ;;
        *)
            # For custom mailbox names, do a broad LIKE match
            local escaped_name
            escaped_name=$(sql_escape "$mailbox_name")
            mailbox_filter="mb.url LIKE '%${escaped_name}%'"
            ;;
    esac

    local result
    result=$(sqlite3 -separator ' | ' "$tmp_db" "
        SELECT
            m.ROWID,
            datetime(m.date_sent + $CORE_DATA_EPOCH, 'unixepoch', 'localtime'),
            COALESCE(a.comment, '') || ' <' || COALESCE(a.address, '') || '>',
            COALESCE(s.subject, '(no subject)')
        FROM messages m
        LEFT JOIN subjects s ON m.subject = s.ROWID
        LEFT JOIN addresses a ON m.sender = a.ROWID
        JOIN mailboxes mb ON m.mailbox = mb.ROWID
        WHERE $mailbox_filter
        ORDER BY m.date_sent DESC
        LIMIT $limit;
    " 2>&1)
    local sql_exit=$?

    cleanup_temp_db "$tmp_db"

    # If SQLite itself failed (bad schema, locked, etc.), fall back
    if [[ $sql_exit -ne 0 ]]; then
        return 1
    fi

    if [[ -z "$result" ]]; then
        echo "No messages found in $mailbox_name"
        return 0
    fi

    echo "$result"
    return 0
}

# Search messages via SQLite
# Supports prefixes: from:, to:, subject:, body: (body falls back to AppleScript)
# Output format matches AppleScript: message_id | date | sender | subject
do_search() {
    local query="$1"
    local account_filter="$2"
    local limit=25

    # Parse prefix
    local search_mode="general"
    local search_term="$query"

    if [[ "$query" == from:* ]]; then
        search_mode="from"
        search_term="${query#from:}"
    elif [[ "$query" == to:* ]]; then
        search_mode="to"
        search_term="${query#to:}"
    elif [[ "$query" == subject:* ]]; then
        search_mode="subject"
        search_term="${query#subject:}"
    elif [[ "$query" == body:* ]]; then
        # Body content is not stored in the Envelope Index
        # Fall back to AppleScript for body searches
        return 1
    fi

    local src_db
    src_db=$(find_mail_db)
    if [[ -z "$src_db" ]]; then
        return 1
    fi

    local tmp_db
    tmp_db=$(setup_temp_db "$src_db")
    if [[ -z "$tmp_db" || ! -f "$tmp_db" ]]; then
        return 1
    fi

    # Validate schema before querying
    if ! validate_schema "$tmp_db"; then
        cleanup_temp_db "$tmp_db"
        return 1
    fi

    local escaped_term
    escaped_term=$(sql_escape "$search_term")

    # Build the WHERE clause based on search mode
    local where_clause=""
    local extra_joins=""
    case "$search_mode" in
        from)
            where_clause="(a.address LIKE '%${escaped_term}%' OR a.comment LIKE '%${escaped_term}%')"
            ;;
        to)
            # Recipients are in a separate table - check if it exists
            if has_recipients_table "$tmp_db"; then
                extra_joins="LEFT JOIN recipients r ON m.ROWID = r.message_id
                             LEFT JOIN addresses ra ON r.address_id = ra.ROWID"
                where_clause="(ra.address LIKE '%${escaped_term}%' OR ra.comment LIKE '%${escaped_term}%')"
            else
                # No recipients table - fall back to AppleScript for to: searches
                cleanup_temp_db "$tmp_db"
                return 1
            fi
            ;;
        subject)
            where_clause="s.subject LIKE '%${escaped_term}%'"
            ;;
        general)
            # Search subject, sender address, and sender name
            where_clause="(s.subject LIKE '%${escaped_term}%' OR a.address LIKE '%${escaped_term}%' OR a.comment LIKE '%${escaped_term}%')"
            ;;
    esac

    # Add account filter if specified
    local account_clause=""
    if [[ -n "$account_filter" ]]; then
        # account_filter is comma-separated list of email addresses or account names
        # We match against the mailbox URL which contains the account identifier
        local account_conditions=""
        IFS=',' read -ra ACCOUNTS <<< "$account_filter"
        for acct in "${ACCOUNTS[@]}"; do
            # Trim whitespace
            acct=$(echo "$acct" | xargs)
            local escaped_acct
            escaped_acct=$(sql_escape "$acct")
            if [[ -n "$account_conditions" ]]; then
                account_conditions="$account_conditions OR"
            fi
            account_conditions="$account_conditions mb.url LIKE '%${escaped_acct}%'"
        done
        if [[ -n "$account_conditions" ]]; then
            account_clause="AND ($account_conditions)"
        fi
    fi

    local result
    result=$(sqlite3 -separator ' | ' "$tmp_db" "
        SELECT DISTINCT
            m.ROWID,
            datetime(m.date_sent + $CORE_DATA_EPOCH, 'unixepoch', 'localtime'),
            COALESCE(a.comment, '') || ' <' || COALESCE(a.address, '') || '>',
            COALESCE(s.subject, '(no subject)')
        FROM messages m
        LEFT JOIN subjects s ON m.subject = s.ROWID
        LEFT JOIN addresses a ON m.sender = a.ROWID
        LEFT JOIN mailboxes mb ON m.mailbox = mb.ROWID
        $extra_joins
        WHERE $where_clause
        $account_clause
        ORDER BY m.date_sent DESC
        LIMIT $limit;
    " 2>&1)
    local sql_exit=$?

    cleanup_temp_db "$tmp_db"

    # If SQLite itself failed, fall back to AppleScript
    if [[ $sql_exit -ne 0 ]]; then
        return 1
    fi

    if [[ -z "$result" ]]; then
        echo "No messages found matching: $query"
        return 0
    fi

    echo "$result"
    return 0
}

# Main dispatch
CMD="$1"
shift

case "$CMD" in
    list)
        MAILBOX="${1:-INBOX}"
        do_list "$MAILBOX"
        exit $?
        ;;
    search)
        QUERY="$1"
        ACCOUNT_FILTER="$2"
        if [[ -z "$QUERY" ]]; then
            echo -e "${RED}Error:${NC} search requires a query"
            exit 1
        fi
        do_search "$QUERY" "$ACCOUNT_FILTER"
        exit $?
        ;;
    *)
        echo "Usage: mail-db.sh <list|search> [args]"
        exit 1
        ;;
esac
