#!/usr/bin/env python3
"""List recent photos from Apple Photos via SQLite — fast, supports date filtering."""

import sqlite3
import sys
import os
from photos_search import DB_PATH, apple_ts_to_str, date_to_apple_ts, parse_relative_date


def main():
    count = 20
    since_ts = None

    # Parse args
    i = 0
    args = sys.argv[1:]
    while i < len(args):
        arg = args[i]
        if arg == "--since" and i + 1 < len(args):
            i += 1
            val = args[i]
            ts = date_to_apple_ts(val)
            if ts is None:
                ts = parse_relative_date(val)
            if ts is None:
                print(f"Error: Invalid date '{val}'. Use YYYY-MM-DD, today, yesterday, 3d, 1w, 2m", file=sys.stderr)
                sys.exit(1)
            since_ts = ts
        else:
            try:
                count = int(arg)
            except ValueError:
                print(f"Error: Invalid count '{arg}'", file=sys.stderr)
                sys.exit(1)
        i += 1

    if not os.path.exists(DB_PATH):
        print(f"Error: Photos database not found at {DB_PATH}", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    conn.execute("PRAGMA query_only = ON")

    date_clause = ""
    params = []

    if since_ts is not None:
        date_clause = "AND a.ZDATECREATED >= ?"
        params.append(since_ts)

    params.append(count)

    sql = f"""
        SELECT a.ZFILENAME, a.ZDATECREATED, a.ZLATITUDE, a.ZLONGITUDE,
               a.ZUNIFORMTYPEIDENTIFIER, attr.ZTITLE
        FROM ZASSET a
        LEFT JOIN ZADDITIONALASSETATTRIBUTES attr ON attr.ZASSET = a.Z_PK
        WHERE a.ZTRASHEDSTATE = 0
          {date_clause}
        ORDER BY a.ZDATECREATED DESC
        LIMIT ?
    """
    rows = conn.execute(sql, params).fetchall()
    conn.close()

    if not rows:
        print("No photos found.")
        return

    since_msg = ""
    if since_ts is not None:
        since_msg = f" (since {apple_ts_to_str(since_ts)})"

    print(f"Found {len(rows)} photo(s){since_msg}:\n")
    for filename, date_ts, lat, lon, uti, title in rows:
        media_type = "img"
        if uti and ("movie" in uti or "video" in uti):
            media_type = "vid"
        elif uti and "gif" in uti:
            media_type = "gif"

        line = f"  [{media_type}] {filename or '(no name)'}  |  {apple_ts_to_str(date_ts)}"
        if title:
            line += f"  |  {title}"
        if lat and lon and lat != 0 and lon != 0:
            line += f"  |  ({lat:.4f}, {lon:.4f})"
        print(line)


if __name__ == "__main__":
    main()
