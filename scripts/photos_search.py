#!/usr/bin/env python3
"""Search Apple Photos library via SQLite — filename, title, description, and OCR text."""

import sqlite3
import sys
import os
import plistlib
import re
from datetime import datetime, timezone

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


def search_metadata(conn, query):
    """Search filename, title, description via SQL LIKE (fast)."""
    pattern = f"%{query}%"
    sql = """
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
        ORDER BY a.ZDATECREATED DESC
        LIMIT ?
    """
    rows = conn.execute(sql, (pattern, pattern, pattern, MAX_RESULTS)).fetchall()
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


def search_ocr(conn, query, existing_pks, remaining):
    """Search OCR text by decoding binary plist blobs with LZFSE decompression."""
    if remaining <= 0 or not HAS_LZFSE:
        if not HAS_LZFSE:
            print(
                "  (OCR search skipped — install pyliblzfse: pip3 install pyliblzfse)",
                file=sys.stderr,
            )
        return []

    sql = """
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
    """
    results = []
    query_lower = query.lower()
    for pk, filename, date_ts, blob in conn.execute(sql):
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


def main():
    if len(sys.argv) < 2:
        print("Usage: photos_search.py <query>", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]

    if not os.path.exists(DB_PATH):
        print(f"Error: Photos database not found at {DB_PATH}", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    conn.execute("PRAGMA query_only = ON")

    # Phase 1: fast metadata search (filename, title, description)
    meta_results = search_metadata(conn, query)
    existing_pks = {r["pk"] for r in meta_results}

    # Phase 2: OCR search (slower, fills remaining slots)
    remaining = MAX_RESULTS - len(meta_results)
    ocr_results = search_ocr(conn, query, existing_pks, remaining)

    conn.close()

    all_results = meta_results + ocr_results

    if not all_results:
        print(f"No photos found matching: {query}")
        sys.exit(0)

    print(f"Found {len(all_results)} photo(s) matching \"{query}\":\n")
    for r in all_results:
        line = f"  {r['filename']}  |  {r['date']}  |  [{r['match']}]"
        if r["context"]:
            line += f"  {r['context']}"
        print(line)


if __name__ == "__main__":
    main()
