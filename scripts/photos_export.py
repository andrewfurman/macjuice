#!/usr/bin/env python3
"""Export Apple Photos matching a search query — SQLite search + targeted AppleScript export."""

import sqlite3
import subprocess
import sys
import os

# Reuse search logic from photos_search
from photos_search import (
    DB_PATH,
    search_metadata,
    search_ocr,
    MAX_RESULTS,
)


def export_by_uuid(uuids, dest_folder):
    """Use AppleScript to export specific media items by UUID."""
    if not uuids:
        return 0

    # Build AppleScript that references items by id (avoids loading all media items)
    uuid_refs = "\n".join(
        f'        set end of itemsToExport to media item id "{uid}"'
        for uid in uuids
    )

    script = f"""
tell application "Photos"
    set itemsToExport to {{}}
    try
{uuid_refs}
    on error errMsg
        return "ERROR: " & errMsg
    end try
    if (count of itemsToExport) is 0 then
        return "No items to export"
    end if
    export itemsToExport to POSIX file "{dest_folder}" as alias
    return "OK"
end tell
"""

    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        timeout=120,
    )

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())

    output = result.stdout.strip()
    if output.startswith("ERROR:"):
        raise RuntimeError(output)

    return len(uuids)


def get_uuids_for_pks(conn, pks):
    """Get UUIDs for a list of primary keys."""
    if not pks:
        return []
    placeholders = ",".join("?" for _ in pks)
    sql = f"SELECT ZUUID FROM ZASSET WHERE Z_PK IN ({placeholders})"
    rows = conn.execute(sql, list(pks)).fetchall()
    return [row[0] for row in rows if row[0]]


def main():
    if len(sys.argv) < 3:
        print("Usage: photos_export.py <query> <destination-folder>", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]
    dest_folder = os.path.abspath(sys.argv[2])

    if not os.path.isdir(dest_folder):
        print(f"Error: Destination folder does not exist: {dest_folder}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(DB_PATH):
        print(f"Error: Photos database not found at {DB_PATH}", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    conn.execute("PRAGMA query_only = ON")

    # Search (same as photos_search.py)
    meta_results = search_metadata(conn, query)
    existing_pks = {r["pk"] for r in meta_results}
    remaining = MAX_RESULTS - len(meta_results)
    ocr_results = search_ocr(conn, query, existing_pks, remaining)
    all_results = meta_results + ocr_results

    if not all_results:
        print(f"No photos found matching: {query}")
        conn.close()
        sys.exit(0)

    print(f"Found {len(all_results)} photo(s) matching \"{query}\"")
    for r in all_results:
        print(f"  {r['filename']}  |  {r['date']}")

    # Get UUIDs and export
    all_pks = [r["pk"] for r in all_results]
    uuids = get_uuids_for_pks(conn, all_pks)
    conn.close()

    if not uuids:
        print("Error: Could not find UUIDs for matched photos", file=sys.stderr)
        sys.exit(1)

    print(f"\nExporting {len(uuids)} items to {dest_folder}...")
    try:
        count = export_by_uuid(uuids, dest_folder)
        print(f"OK: Exported {count} items to {dest_folder}")
    except RuntimeError as e:
        print(f"Export error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
