#!/usr/bin/env python3
"""Search Apple Photos library via SQLite — filename, title, description, OCR text,
people/faces, keywords, and date filtering."""

import sqlite3
import sys
import os
import plistlib
import re
from datetime import datetime, timezone, timedelta

# Apple's Core Data epoch: 2001-01-01 00:00:00 UTC
APPLE_EPOCH = datetime(2001, 1, 1, tzinfo=timezone.utc)

DB_PATH = os.path.expanduser(
    "~/Pictures/Photos Library.photoslibrary/database/Photos.sqlite"
)
MAX_RESULTS = 30

# Optional: LZFSE decompression for OCR data
try:
    import liblzfse
    HAS_LZFSE = True
except ImportError:
    HAS_LZFSE = False


def apple_ts_to_str(ts):
    """Convert Apple Core Data timestamp to readable date string."""
    if ts is None:
        return "unknown date"
    try:
        dt = datetime.fromtimestamp(APPLE_EPOCH.timestamp() + ts)
        return dt.strftime("%Y-%m-%d %H:%M")
    except (OSError, OverflowError, ValueError):
        return "unknown date"


def date_to_apple_ts(date_str):
    """Convert a date string (YYYY-MM-DD) to Apple Core Data timestamp."""
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        return (dt - APPLE_EPOCH).total_seconds()
    except ValueError:
        return None


def parse_relative_date(text):
    """Parse relative date strings like 'today', 'yesterday', '3d', '1w', '2m'."""
    text = text.lower().strip()
    now = datetime.now(timezone.utc)

    if text == "today":
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        return (start - APPLE_EPOCH).total_seconds()
    elif text == "yesterday":
        start = (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        return (start - APPLE_EPOCH).total_seconds()

    match = re.match(r"^(\d+)\s*(d|w|m|h)$", text)
    if match:
        num = int(match.group(1))
        unit = match.group(2)
        if unit == "h":
            delta = timedelta(hours=num)
        elif unit == "d":
            delta = timedelta(days=num)
        elif unit == "w":
            delta = timedelta(weeks=num)
        elif unit == "m":
            delta = timedelta(days=num * 30)
        start = now - delta
        return (start - APPLE_EPOCH).total_seconds()

    return None


def extract_ocr_text(blob):
    """Decode NSKeyedArchiver binary plist, decompress LZFSE, extract OCR words."""
    if blob is None or not HAS_LZFSE:
        return ""
    try:
        plist = plistlib.loads(blob)
        objects = plist.get("$objects", [])

        # Find the CRDocumentOutputRegion with compressed data
        for obj in objects:
            if not isinstance(obj, dict):
                continue
            if "kCROutputRegionData" not in obj:
                continue

            data_uid = obj["kCROutputRegionData"]
            raw = objects[data_uid]
            if not isinstance(raw, bytes) or len(raw) < 4:
                continue

            # Decompress LZFSE (magic: bvx2)
            decompressed = liblzfse.decompress(raw)
            if not decompressed:
                continue

            # Extract words from CRWordOutputRegion entries
            marker = b"CRWordOutputRegion\x00"
            words = []
            start = 0
            while True:
                idx = decompressed.find(marker, start)
                if idx == -1:
                    break
                pos = idx + len(marker)
                chunk = decompressed[pos : pos + 80]
                # Find the first readable text string after the marker
                found = re.findall(rb"([\x20-\x7e]{2,})", chunk)
                if found:
                    word = found[0].decode("utf-8", errors="ignore")
                    # Skip structural strings (UUIDs, language codes, binary noise)
                    if (
                        not re.match(r"^[A-F0-9]{8}-", word)
                        and len(word) < 100
                        and not word.startswith(("k:@", "~A_", "@~A"))
                    ):
                        words.append(word)
                start = idx + len(marker)

            # Deduplicate while preserving order
            seen = set()
            unique = []
            for w in words:
                if w not in seen:
                    seen.add(w)
                    unique.append(w)
            return " ".join(unique)

    except Exception:
        pass
    return ""


def search_metadata(conn, query, since_ts=None):
    """Search filename, title, description via SQL LIKE (fast)."""
    pattern = f"%{query}%"
    date_clause = ""
    params = [pattern, pattern, pattern]

    if since_ts is not None:
        date_clause = "AND a.ZDATECREATED >= ?"
        params.append(since_ts)

    params.append(MAX_RESULTS)

    sql = f"""
        SELECT DISTINCT
            a.Z_PK,
            a.ZFILENAME,
            a.ZDATECREATED,
            attr.ZTITLE,
            d.ZLONGDESCRIPTION
        FROM ZASSET a
        LEFT JOIN ZADDITIONALASSETATTRIBUTES attr ON attr.ZASSET = a.Z_PK
        LEFT JOIN ZASSETDESCRIPTION d ON d.ZASSETATTRIBUTES = attr.Z_PK
        WHERE a.ZTRASHEDSTATE = 0
          AND (
            a.ZFILENAME LIKE ? COLLATE NOCASE
            OR attr.ZTITLE LIKE ? COLLATE NOCASE
            OR d.ZLONGDESCRIPTION LIKE ? COLLATE NOCASE
          )
          {date_clause}
        ORDER BY a.ZDATECREATED DESC
        LIMIT ?
    """
    rows = conn.execute(sql, params).fetchall()
    results = []
    for pk, filename, date_ts, title, desc in rows:
        match_field = "filename"
        if title and query.lower() in title.lower():
            match_field = "title"
        if desc and query.lower() in desc.lower():
            match_field = "description"
        context = ""
        if match_field == "title" and title:
            context = f"title: {title}"
        elif match_field == "description" and desc:
            context = f"desc: {desc[:100]}"
        results.append(
            {
                "pk": pk,
                "filename": filename or "(no filename)",
                "date": apple_ts_to_str(date_ts),
                "match": match_field,
                "context": context,
            }
        )
    return results


def search_ocr(conn, query, existing_pks, remaining, since_ts=None):
    """Search OCR text by decoding binary plist blobs with LZFSE decompression."""
    if remaining <= 0 or not HAS_LZFSE:
        if not HAS_LZFSE:
            print(
                "  (OCR search skipped — install pyliblzfse: pip3 install pyliblzfse)",
                file=sys.stderr,
            )
        return []

    date_clause = ""
    params = []
    if since_ts is not None:
        date_clause = "AND a.ZDATECREATED >= ?"
        params.append(since_ts)

    sql = f"""
        SELECT
            a.Z_PK,
            a.ZFILENAME,
            a.ZDATECREATED,
            c.ZCHARACTERRECOGNITIONDATA
        FROM ZCHARACTERRECOGNITIONATTRIBUTES c
        JOIN ZMEDIAANALYSISASSETATTRIBUTES m ON c.ZMEDIAANALYSISASSETATTRIBUTES = m.Z_PK
        JOIN ZASSET a ON m.ZASSET = a.Z_PK
        WHERE a.ZTRASHEDSTATE = 0
          AND c.ZCHARACTERRECOGNITIONDATA IS NOT NULL
          {date_clause}
    """
    results = []
    query_lower = query.lower()
    for pk, filename, date_ts, blob in conn.execute(sql, params):
        if pk in existing_pks:
            continue
        ocr_text = extract_ocr_text(blob)
        if not ocr_text:
            continue
        if query_lower in ocr_text.lower():
            # Extract a snippet around the match
            idx = ocr_text.lower().find(query_lower)
            start = max(0, idx - 30)
            end = min(len(ocr_text), idx + len(query) + 30)
            snippet = ocr_text[start:end].replace("\n", " ").strip()
            if start > 0:
                snippet = "..." + snippet
            if end < len(ocr_text):
                snippet = snippet + "..."
            results.append(
                {
                    "pk": pk,
                    "filename": filename or "(no filename)",
                    "date": apple_ts_to_str(date_ts),
                    "match": "ocr",
                    "context": f"ocr: {snippet}",
                }
            )
            if len(results) >= remaining:
                break
    return results


def search_people(conn, query, since_ts=None):
    """Search photos by person/face name."""
    pattern = f"%{query}%"
    date_clause = ""
    params = [pattern, pattern]

    if since_ts is not None:
        date_clause = "AND a.ZDATECREATED >= ?"
        params.append(since_ts)

    params.append(MAX_RESULTS)

    sql = f"""
        SELECT DISTINCT
            a.Z_PK,
            a.ZFILENAME,
            a.ZDATECREATED,
            p.ZDISPLAYNAME,
            p.ZFULLNAME
        FROM ZDETECTEDFACE df
        JOIN ZPERSON p ON df.ZPERSONFORFACE = p.Z_PK
        JOIN ZASSET a ON df.ZASSETFORFACE = a.Z_PK
        WHERE a.ZTRASHEDSTATE = 0
          AND (
            p.ZDISPLAYNAME LIKE ? COLLATE NOCASE
            OR p.ZFULLNAME LIKE ? COLLATE NOCASE
          )
          {date_clause}
        ORDER BY a.ZDATECREATED DESC
        LIMIT ?
    """
    rows = conn.execute(sql, params).fetchall()
    results = []
    for pk, filename, date_ts, display_name, full_name in rows:
        name = full_name or display_name or "unknown"
        results.append(
            {
                "pk": pk,
                "filename": filename or "(no filename)",
                "date": apple_ts_to_str(date_ts),
                "match": "person",
                "context": f"person: {name}",
            }
        )
    return results


def search_keywords(conn, query, since_ts=None):
    """Search photos by keyword tags."""
    pattern = f"%{query}%"
    date_clause = ""
    params = [pattern]

    if since_ts is not None:
        date_clause = "AND a.ZDATECREATED >= ?"
        params.append(since_ts)

    params.append(MAX_RESULTS)

    sql = f"""
        SELECT DISTINCT
            a.Z_PK,
            a.ZFILENAME,
            a.ZDATECREATED,
            k.ZTITLE
        FROM Z_1KEYWORDS jk
        JOIN ZKEYWORD k ON k.Z_PK = jk.Z_52KEYWORDS
        JOIN ZADDITIONALASSETATTRIBUTES attr ON attr.Z_PK = jk.Z_1ASSETATTRIBUTES
        JOIN ZASSET a ON attr.ZASSET = a.Z_PK
        WHERE a.ZTRASHEDSTATE = 0
          AND k.ZTITLE LIKE ? COLLATE NOCASE
          {date_clause}
        ORDER BY a.ZDATECREATED DESC
        LIMIT ?
    """
    rows = conn.execute(sql, params).fetchall()
    results = []
    for pk, filename, date_ts, keyword in rows:
        results.append(
            {
                "pk": pk,
                "filename": filename or "(no filename)",
                "date": apple_ts_to_str(date_ts),
                "match": "keyword",
                "context": f"keyword: {keyword}",
            }
        )
    return results


def list_people(conn):
    """List all named people in the Photos library."""
    sql = """
        SELECT ZDISPLAYNAME, ZFULLNAME, ZFACECOUNT
        FROM ZPERSON
        WHERE ZDISPLAYNAME IS NOT NULL AND ZDISPLAYNAME <> ''
        ORDER BY ZFACECOUNT DESC
        LIMIT 50
    """
    rows = conn.execute(sql).fetchall()
    if not rows:
        print("No named people found.")
        return
    print(f"{'Name':<30} {'Full Name':<30} {'Photos':>8}")
    print("-" * 70)
    for display, full, count in rows:
        full = full or ""
        count = count or 0
        print(f"{display:<30} {full:<30} {count:>8}")


def list_keywords(conn):
    """List all keywords in the Photos library."""
    sql = """
        SELECT k.ZTITLE, COUNT(*) as cnt
        FROM Z_1KEYWORDS jk
        JOIN ZKEYWORD k ON k.Z_PK = jk.Z_52KEYWORDS
        GROUP BY k.ZTITLE
        ORDER BY cnt DESC
        LIMIT 50
    """
    rows = conn.execute(sql).fetchall()
    if not rows:
        print("No keywords found.")
        return
    print(f"{'Keyword':<50} {'Photos':>8}")
    print("-" * 60)
    for title, count in rows:
        print(f"{title:<50} {count:>8}")


def recent_photos(conn, count=20, since_ts=None):
    """List recent photos, optionally filtered by date."""
    date_clause = ""
    params = []

    if since_ts is not None:
        date_clause = "WHERE a.ZTRASHEDSTATE = 0 AND a.ZDATECREATED >= ?"
        params.append(since_ts)
    else:
        date_clause = "WHERE a.ZTRASHEDSTATE = 0"

    params.append(count)

    sql = f"""
        SELECT a.ZFILENAME, a.ZDATECREATED, a.ZLATITUDE, a.ZLONGITUDE,
               attr.ZTITLE
        FROM ZASSET a
        LEFT JOIN ZADDITIONALASSETATTRIBUTES attr ON attr.ZASSET = a.Z_PK
        {date_clause}
        ORDER BY a.ZDATECREATED DESC
        LIMIT ?
    """
    rows = conn.execute(sql, params).fetchall()
    if not rows:
        print("No photos found.")
        return
    print(f"Found {len(rows)} photo(s):\n")
    for filename, date_ts, lat, lon, title in rows:
        line = f"  {filename or '(no name)'}  |  {apple_ts_to_str(date_ts)}"
        if title:
            line += f"  |  {title}"
        if lat and lon and lat != 0 and lon != 0:
            line += f"  |  ({lat:.4f}, {lon:.4f})"
        print(line)


def parse_args(argv):
    """Parse command line arguments with prefix-based search modifiers."""
    query = None
    search_type = "all"  # all, person, keyword, text, ocr
    since_ts = None
    list_mode = None  # people, keywords

    i = 0
    while i < len(argv):
        arg = argv[i]

        if arg == "--since" and i + 1 < len(argv):
            i += 1
            val = argv[i]
            # Try as YYYY-MM-DD
            ts = date_to_apple_ts(val)
            if ts is None:
                # Try as relative date
                ts = parse_relative_date(val)
            if ts is None:
                print(f"Error: Invalid date '{val}'. Use YYYY-MM-DD, today, yesterday, 3d, 1w, 2m", file=sys.stderr)
                sys.exit(1)
            since_ts = ts
        elif arg == "--type" and i + 1 < len(argv):
            i += 1
            search_type = argv[i]
            if search_type not in ("all", "person", "keyword", "text", "ocr"):
                print(f"Error: Invalid type '{search_type}'. Use: all, person, keyword, text, ocr", file=sys.stderr)
                sys.exit(1)
        elif arg == "--list-people":
            list_mode = "people"
        elif arg == "--list-keywords":
            list_mode = "keywords"
        elif arg.startswith("person:"):
            query = arg[7:]
            search_type = "person"
        elif arg.startswith("keyword:"):
            query = arg[8:]
            search_type = "keyword"
        elif arg.startswith("text:"):
            query = arg[5:]
            search_type = "text"
        elif arg.startswith("ocr:"):
            query = arg[4:]
            search_type = "ocr"
        elif query is None:
            query = arg
        i += 1

    return query, search_type, since_ts, list_mode


def main():
    if len(sys.argv) < 2:
        print("""Usage: macjuice photos search <query> [options]

Search modifiers (prefix-based):
  person:<name>        Search by person/face name
  keyword:<tag>        Search by keyword tag
  text:<query>         Search filename, title, description only
  ocr:<query>          Search OCR text only
  <query>              Search all fields (default)

Options:
  --since <date>       Filter by date (YYYY-MM-DD, today, yesterday, 3d, 1w, 2m)
  --type <type>        Search type: all, person, keyword, text, ocr
  --list-people        List all named people in library
  --list-keywords      List all keywords in library

Examples:
  macjuice photos search "beach"
  macjuice photos search person:Kate
  macjuice photos search keyword:vacation
  macjuice photos search ocr:receipt --since 1w
  macjuice photos search "bike" --since 2026-03-09
  macjuice photos search --list-people
  macjuice photos search --list-keywords""", file=sys.stderr)
        sys.exit(1)

    query, search_type, since_ts, list_mode = parse_args(sys.argv[1:])

    if not os.path.exists(DB_PATH):
        print(f"Error: Photos database not found at {DB_PATH}", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    conn.execute("PRAGMA query_only = ON")

    # Handle list modes
    if list_mode == "people":
        list_people(conn)
        conn.close()
        return
    elif list_mode == "keywords":
        list_keywords(conn)
        conn.close()
        return

    if query is None:
        print("Error: No search query provided", file=sys.stderr)
        sys.exit(1)

    all_results = []
    existing_pks = set()

    # Person search
    if search_type in ("all", "person"):
        person_results = search_people(conn, query, since_ts)
        all_results.extend(person_results)
        existing_pks.update(r["pk"] for r in person_results)

    # Keyword search
    if search_type in ("all", "keyword"):
        kw_results = search_keywords(conn, query, since_ts)
        # Deduplicate
        for r in kw_results:
            if r["pk"] not in existing_pks:
                all_results.append(r)
                existing_pks.add(r["pk"])

    # Metadata search (filename, title, description)
    if search_type in ("all", "text"):
        meta_results = search_metadata(conn, query, since_ts)
        for r in meta_results:
            if r["pk"] not in existing_pks:
                all_results.append(r)
                existing_pks.add(r["pk"])

    # OCR search
    if search_type in ("all", "ocr"):
        remaining = MAX_RESULTS - len(all_results)
        ocr_results = search_ocr(conn, query, existing_pks, remaining, since_ts)
        all_results.extend(ocr_results)

    conn.close()

    if not all_results:
        since_msg = ""
        if since_ts is not None:
            since_msg = f" (since {apple_ts_to_str(since_ts)})"
        print(f"No photos found matching: {query}{since_msg}")
        sys.exit(0)

    print(f"Found {len(all_results)} photo(s) matching \"{query}\":\n")
    for r in all_results:
        line = f"  {r['filename']}  |  {r['date']}  |  [{r['match']}]"
        if r["context"]:
            line += f"  {r['context']}"
        print(line)


if __name__ == "__main__":
    main()
