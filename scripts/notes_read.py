#!/usr/bin/env python3
"""Fast Apple Notes reader via SQLite — bypasses AppleScript hangs."""

import sqlite3
import gzip
import os
import sys
import re
from datetime import datetime, timezone

NOTES_DB = os.path.expanduser(
    "~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite"
)

# Apple's Core Data epoch offset (Jan 1, 2001)
APPLE_EPOCH = 978307200


def get_db():
    if not os.path.exists(NOTES_DB):
        print("Error: Notes database not found", file=sys.stderr)
        sys.exit(1)
    return sqlite3.connect(NOTES_DB)


def extract_plaintext(data_blob):
    """Extract readable text from a Notes protobuf/gzip blob."""
    if not data_blob:
        return ""
    try:
        data = gzip.decompress(data_blob)
    except Exception:
        data = data_blob

    text = data.decode("utf-8", errors="replace")
    
    # Extract printable runs — the note content is typically the first
    # large block of readable text in the protobuf
    runs = []
    current = []
    for c in text:
        if c.isprintable() or c in "\n\t":
            current.append(c)
        else:
            if current:
                s = "".join(current)
                if len(s.strip()) >= 3 and re.search(r'[a-zA-Z]{2,}', s):
                    runs.append(s.strip())
                current = []
    if current:
        s = "".join(current)
        if len(s.strip()) >= 3 and re.search(r'[a-zA-Z]{2,}', s):
            runs.append(s.strip())
    
    # The first substantial run is usually the note title + body
    # Filter out short garbage runs (protobuf field names, etc.)
    content_runs = [r for r in runs if len(r) >= 5 or '\n' in r]
    
    if content_runs:
        # Take the first run which contains the actual note text
        # Stop when we hit garbage (runs that are mostly non-word chars)
        result = []
        for run in content_runs:
            # Check if run is mostly readable text
            alpha_ratio = sum(1 for c in run if c.isalpha() or c.isspace() or c in '.,;:!?-\'\"()') / max(len(run), 1)
            if alpha_ratio > 0.5:
                result.append(run)
            elif result:
                # Once we've found content and hit garbage, stop
                break
        return "\n".join(result)
    
    return ""


def apple_date(ts):
    """Convert Apple Core Data timestamp to readable string."""
    if ts is None:
        return "unknown"
    dt = datetime.fromtimestamp(ts + APPLE_EPOCH, tz=timezone.utc)
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def list_notes(limit=50):
    db = get_db()
    cur = db.cursor()
    cur.execute(
        """
        SELECT n.ZTITLE1, datetime(n.ZMODIFICATIONDATE1 + ?, 'unixepoch') as modified,
               n.Z_PK
        FROM ZICCLOUDSYNCINGOBJECT n
        WHERE n.ZTITLE1 IS NOT NULL AND n.ZTITLE1 != ''
          AND n.ZMARKEDFORDELETION != 1
        ORDER BY n.ZMODIFICATIONDATE1 DESC
        LIMIT ?
        """,
        (APPLE_EPOCH, limit),
    )
    for row in cur.fetchall():
        print(f"{row[2]} | {row[1]} | {row[0]}")
    db.close()


def list_folders():
    db = get_db()
    cur = db.cursor()
    cur.execute(
        """
        SELECT ZTITLE2, Z_PK
        FROM ZICCLOUDSYNCINGOBJECT
        WHERE ZTITLE2 IS NOT NULL AND ZTITLE2 != ''
          AND Z_ENT IN (SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME = 'ICFolder')
        ORDER BY ZTITLE2
        """
    )
    rows = cur.fetchall()
    if not rows:
        # Fallback: try different column
        cur.execute(
            """
            SELECT DISTINCT ZNAME, Z_PK FROM ZICCLOUDSYNCINGOBJECT
            WHERE ZNAME IS NOT NULL AND ZNAME != ''
            ORDER BY ZNAME
            """
        )
        rows = cur.fetchall()
    for row in rows:
        print(f"{row[0]}")
    db.close()


def read_note(title):
    db = get_db()
    cur = db.cursor()
    cur.execute(
        """
        SELECT n.ZTITLE1, datetime(n.ZMODIFICATIONDATE1 + ?, 'unixepoch'),
               datetime(n.ZCREATIONDATE1 + ?, 'unixepoch'),
               nb.ZDATA
        FROM ZICCLOUDSYNCINGOBJECT n
        JOIN ZICNOTEDATA nb ON nb.Z_PK = n.ZNOTEDATA
        WHERE n.ZTITLE1 = ?
        ORDER BY n.ZMODIFICATIONDATE1 DESC
        LIMIT 1
        """,
        (APPLE_EPOCH, APPLE_EPOCH, title),
    )
    row = cur.fetchone()
    if not row:
        # Try case-insensitive / partial match
        cur.execute(
            """
            SELECT n.ZTITLE1, datetime(n.ZMODIFICATIONDATE1 + ?, 'unixepoch'),
                   datetime(n.ZCREATIONDATE1 + ?, 'unixepoch'),
                   nb.ZDATA
            FROM ZICCLOUDSYNCINGOBJECT n
            JOIN ZICNOTEDATA nb ON nb.Z_PK = n.ZNOTEDATA
            WHERE n.ZTITLE1 LIKE ?
            ORDER BY n.ZMODIFICATIONDATE1 DESC
            LIMIT 1
            """,
            (APPLE_EPOCH, APPLE_EPOCH, f"%{title}%"),
        )
        row = cur.fetchone()

    if not row:
        print(f"Note not found: {title}")
        db.close()
        return

    plaintext = extract_plaintext(row[3])
    print(f"Title: {row[0]}")
    print(f"Modified: {row[1]}")
    print(f"Created: {row[2]}")
    print()
    print(plaintext)
    db.close()


def search_notes(query, limit=20):
    db = get_db()
    cur = db.cursor()

    # First search titles
    cur.execute(
        """
        SELECT n.ZTITLE1, datetime(n.ZMODIFICATIONDATE1 + ?, 'unixepoch') as modified,
               n.ZNOTEDATA
        FROM ZICCLOUDSYNCINGOBJECT n
        WHERE n.ZTITLE1 IS NOT NULL AND n.ZTITLE1 != ''
          AND n.ZTITLE1 LIKE ?
        ORDER BY n.ZMODIFICATIONDATE1 DESC
        LIMIT ?
        """,
        (APPLE_EPOCH, f"%{query}%", limit),
    )
    results = cur.fetchall()

    if not results:
        # Search note body content
        cur.execute(
            """
            SELECT n.ZTITLE1, datetime(n.ZMODIFICATIONDATE1 + ?, 'unixepoch') as modified,
                   nb.ZDATA
            FROM ZICCLOUDSYNCINGOBJECT n
            JOIN ZICNOTEDATA nb ON nb.Z_PK = n.ZNOTEDATA
            WHERE n.ZTITLE1 IS NOT NULL AND n.ZTITLE1 != ''
            ORDER BY n.ZMODIFICATIONDATE1 DESC
            """,
            (APPLE_EPOCH,),
        )
        for row in cur.fetchall():
            plaintext = extract_plaintext(row[2])
            if query.lower() in plaintext.lower():
                results.append(row)
                if len(results) >= limit:
                    break

    if not results:
        print(f"No notes found matching: {query}")
    else:
        for row in results:
            print(f"{row[0]} | {row[1]}")

    db.close()


def main():
    if len(sys.argv) < 2:
        print("Usage: notes_read.py <command> [args...]")
        print("Commands: list, folders, read <title>, search <query>")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "list":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 50
        list_notes(limit)
    elif cmd == "folders":
        list_folders()
    elif cmd == "read":
        if len(sys.argv) < 3:
            print("Usage: notes_read.py read <title>")
            sys.exit(1)
        read_note(sys.argv[2])
    elif cmd == "search":
        if len(sys.argv) < 3:
            print("Usage: notes_read.py search <query>")
            sys.exit(1)
        search_notes(sys.argv[2])
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
