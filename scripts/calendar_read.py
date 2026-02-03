#!/usr/bin/env python3
"""Read Apple Calendar events via SQLite — fast, no CalDAV sync."""

import sqlite3
import sys
import os
from datetime import datetime, timedelta

# Apple's Core Data epoch offset: 2001-01-01 00:00:00 UTC
APPLE_EPOCH = 978307200

DB_PATH = os.path.expanduser(
    "~/Library/Group Containers/group.com.apple.calendar/Calendar.sqlitedb"
)


def to_apple(dt):
    """Convert a datetime to Apple Core Data timestamp."""
    return dt.timestamp() - APPLE_EPOCH


def from_apple(ts):
    """Convert Apple Core Data timestamp to local datetime."""
    if ts is None:
        return None
    try:
        return datetime.fromtimestamp(ts + APPLE_EPOCH)
    except (OSError, OverflowError, ValueError):
        return None


def format_duration(start_dt, end_dt):
    """Format duration between two datetimes as e.g. '1h30m'."""
    if start_dt is None or end_dt is None:
        return ""
    mins = int((end_dt - start_dt).total_seconds() / 60)
    if mins <= 0:
        return ""
    if mins >= 60:
        h = mins // 60
        m = mins % 60
        return f"{h}h{m}m" if m else f"{h}h"
    return f"{mins}m"


def format_event(summary, start_dt, end_dt, cal_name, loc_name, all_day):
    """Format one event line matching the AppleScript output style."""
    if all_day:
        date_str = start_dt.strftime("%m/%d/%Y") + " all-day"
    else:
        date_str = start_dt.strftime("%m/%d/%Y %I:%M %p").lstrip("0")

    dur = ""
    if not all_day:
        dur = format_duration(start_dt, end_dt)
        if dur:
            dur = f" ({dur})"

    loc = ""
    if loc_name:
        loc = f" @ {loc_name}"

    return f"{date_str} | {summary}{dur}{loc} [{cal_name}]"


def get_connection():
    if not os.path.exists(DB_PATH):
        print(f"Error: Calendar database not found at {DB_PATH}", file=sys.stderr)
        sys.exit(1)
    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    conn.execute("PRAGMA query_only = ON")
    return conn


def events_in_range(conn, start_dt, end_dt):
    """Query OccurrenceCache for events in [start_dt, end_dt)."""
    start_apple = to_apple(start_dt)
    end_apple = to_apple(end_dt)

    sql = """
        SELECT ci.summary,
               oc.occurrence_date,
               oc.occurrence_start_date,
               oc.occurrence_end_date,
               c.title AS cal_name,
               l.title AS loc_name,
               ci.all_day
        FROM OccurrenceCache oc
        JOIN CalendarItem ci ON oc.event_id = ci.ROWID
        JOIN Calendar c ON oc.calendar_id = c.ROWID
        LEFT JOIN Location l ON ci.location_id = l.ROWID
        WHERE oc.day >= ? AND oc.day < ?
        ORDER BY oc.occurrence_date, ci.summary
    """
    rows = conn.execute(sql, (start_apple, end_apple)).fetchall()

    lines = []
    for summary, occ_date, occ_start, occ_end, cal_name, loc_name, all_day in rows:
        # occurrence_start_date may be NULL; fall back to occurrence_date
        start_ts = occ_start if occ_start is not None else occ_date
        end_ts = occ_end

        start = from_apple(start_ts)
        end = from_apple(end_ts)
        if start is None:
            continue

        lines.append(format_event(summary or "(No title)", start, end,
                                  cal_name or "Unknown", loc_name, bool(all_day)))
    return lines


def cmd_list(conn):
    """List all calendars."""
    sql = "SELECT ROWID, title FROM Calendar ORDER BY title"
    rows = conn.execute(sql).fetchall()
    if not rows:
        print("No calendars found")
        return
    for rowid, title in rows:
        print(f"{title}")


def cmd_today(conn):
    """Show today's events."""
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow = today + timedelta(days=1)
    lines = events_in_range(conn, today, tomorrow)
    if not lines:
        print("No events today")
        return
    for line in lines:
        print(line)


def cmd_week(conn):
    """Show this week's events (next 7 days)."""
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    end = today + timedelta(days=7)
    lines = events_in_range(conn, today, end)
    if not lines:
        print("No events this week")
        return
    for line in lines:
        print(line)


def cmd_upcoming(conn, days):
    """Show upcoming events for N days."""
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    end = today + timedelta(days=days)
    lines = events_in_range(conn, today, end)
    if not lines:
        print(f"No events in the next {days} days")
        return
    for line in lines:
        print(line)


def cmd_search(conn, query):
    """Search events by title (next 90 days)."""
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    end = today + timedelta(days=90)
    start_apple = to_apple(today)
    end_apple = to_apple(end)
    pattern = f"%{query}%"

    sql = """
        SELECT ci.summary,
               oc.occurrence_date,
               oc.occurrence_start_date,
               oc.occurrence_end_date,
               c.title AS cal_name,
               l.title AS loc_name,
               ci.all_day
        FROM OccurrenceCache oc
        JOIN CalendarItem ci ON oc.event_id = ci.ROWID
        JOIN Calendar c ON oc.calendar_id = c.ROWID
        LEFT JOIN Location l ON ci.location_id = l.ROWID
        WHERE oc.day >= ? AND oc.day < ?
          AND ci.summary LIKE ? COLLATE NOCASE
        ORDER BY oc.occurrence_date, ci.summary
        LIMIT 30
    """
    rows = conn.execute(sql, (start_apple, end_apple, pattern)).fetchall()

    if not rows:
        print(f"No events found matching: {query}")
        return

    for summary, occ_date, occ_start, occ_end, cal_name, loc_name, all_day in rows:
        start_ts = occ_start if occ_start is not None else occ_date
        end_ts = occ_end
        start = from_apple(start_ts)
        end = from_apple(end_ts)
        if start is None:
            continue
        print(format_event(summary or "(No title)", start, end,
                           cal_name or "Unknown", loc_name, bool(all_day)))


def main():
    if len(sys.argv) < 2:
        print("Usage: calendar_read.py <command> [args...]", file=sys.stderr)
        print("Commands: list, today, week, upcoming [days], search <query>",
              file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    conn = get_connection()

    try:
        if cmd == "list":
            cmd_list(conn)
        elif cmd == "today":
            cmd_today(conn)
        elif cmd == "week":
            cmd_week(conn)
        elif cmd == "upcoming":
            days = 7
            if len(sys.argv) > 2:
                try:
                    days = int(sys.argv[2])
                except ValueError:
                    print("Error: days must be a number", file=sys.stderr)
                    sys.exit(1)
            cmd_upcoming(conn, days)
        elif cmd == "search":
            if len(sys.argv) < 3:
                print("Usage: calendar_read.py search <query>", file=sys.stderr)
                sys.exit(1)
            cmd_search(conn, sys.argv[2])
        else:
            print(f"Unknown command: {cmd}", file=sys.stderr)
            sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
