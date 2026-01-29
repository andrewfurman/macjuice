-- calendar.applescript
-- Apple Calendar integration for macjuice

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript calendar.applescript <command> [args...]"
    end if

    set cmd to item 1 of argv

    if cmd is "list" then
        return listCalendars()
    else if cmd is "today" then
        return todayEvents()
    else if cmd is "week" then
        return weekEvents()
    else if cmd is "upcoming" then
        set days to 7
        if (count of argv) > 1 then set days to (item 2 of argv) as integer
        return upcomingEvents(days)
    else if cmd is "search" then
        if (count of argv) > 1 then
            return searchEvents(item 2 of argv)
        else
            return "Usage: calendar.applescript search <query>"
        end if
    else if cmd is "create" then
        if (count of argv) > 3 then
            set eventTitle to item 2 of argv
            set eventDate to item 3 of argv
            set eventDuration to item 4 of argv
            set calName to "Calendar"
            if (count of argv) > 4 then set calName to item 5 of argv
            return createEvent(eventTitle, eventDate, eventDuration, calName)
        else
            return "Usage: calendar.applescript create <title> <date> <duration> [calendar]"
        end if
    else if cmd is "delete" then
        if (count of argv) > 1 then
            return deleteEvent(item 2 of argv)
        else
            return "Usage: calendar.applescript delete <event-title>"
        end if
    else
        return "Unknown command: " & cmd
    end if
end run

-- List all calendars
on listCalendars()
    tell application "Calendar"
        with timeout of 5 seconds
        set output to {}
        repeat with cal in calendars
            set calInfo to (name of cal) & " [" & (name of cal) & "]"
            set end of output to calInfo
        end repeat
        end timeout
    end tell
    return my joinList(output, linefeed)
end listCalendars

-- Get today's events
on todayEvents()
    set todayStart to current date
    set time of todayStart to 0
    set todayEnd to todayStart + (24 * 60 * 60)

    return getEventsInRange(todayStart, todayEnd)
end todayEvents

-- Get this week's events
on weekEvents()
    set todayStart to current date
    set time of todayStart to 0
    set weekEnd to todayStart + (7 * 24 * 60 * 60)

    return getEventsInRange(todayStart, weekEnd)
end weekEvents

-- Get upcoming events for N days
on upcomingEvents(days)
    set todayStart to current date
    set time of todayStart to 0
    set futureEnd to todayStart + (days * 24 * 60 * 60)

    return getEventsInRange(todayStart, futureEnd)
end upcomingEvents

-- Get events in a date range
on getEventsInRange(startDate, endDate)
    tell application "Calendar"
        with timeout of 5 seconds
        set output to {}

        repeat with cal in calendars
            try
                set calEvents to (every event of cal whose start date ≥ startDate and start date ≤ endDate)
                repeat with evt in calEvents
                    set evtStart to start date of evt
                    set evtEnd to end date of evt
                    set evtTitle to summary of evt

                    -- Format time
                    set timeStr to my formatDateTime(evtStart)

                    -- Calculate duration
                    set durationMins to ((evtEnd - evtStart) / 60) as integer
                    if durationMins ≥ 60 then
                        set durationStr to (durationMins div 60) & "h"
                        if durationMins mod 60 > 0 then
                            set durationStr to durationStr & (durationMins mod 60) & "m"
                        end if
                    else
                        set durationStr to durationMins & "m"
                    end if

                    -- Get location if available
                    set locStr to ""
                    try
                        if location of evt is not missing value and location of evt is not "" then
                            set locStr to " @ " & (location of evt)
                        end if
                    end try

                    set evtLine to timeStr & " | " & evtTitle & " (" & durationStr & ")" & locStr & " [" & (name of cal) & "]"
                    set end of output to {startDate:evtStart, eventLine:evtLine}
                end repeat
            end try
        end repeat

        -- Sort by date (simple bubble sort)
        set sortedOutput to my sortEventsByDate(output)

        -- Extract just the display strings
        set outputLines to {}
        repeat with item_ref in sortedOutput
            set end of outputLines to eventLine of item_ref
        end repeat

        if (count of outputLines) is 0 then
            return "No events found"
        end if
        end timeout
    end tell
    return my joinList(outputLines, linefeed)
end getEventsInRange

-- Search events by title
on searchEvents(query)
    tell application "Calendar"
        with timeout of 5 seconds
        set output to {}
        set maxResults to 20
        set searchStart to current date
        set searchEnd to searchStart + (90 * 24 * 60 * 60) -- Search next 90 days

        repeat with cal in calendars
            if (count of output) ≥ maxResults then exit repeat
            try
                set calEvents to (every event of cal whose summary contains query and start date ≥ searchStart and start date ≤ searchEnd)
                repeat with evt in calEvents
                    if (count of output) ≥ maxResults then exit repeat
                    set evtStart to start date of evt
                    set evtTitle to summary of evt
                    set timeStr to my formatDateTime(evtStart)
                    set evtLine to timeStr & " | " & evtTitle & " [" & (name of cal) & "]"
                    set end of output to evtLine
                end repeat
            end try
        end repeat

        if (count of output) is 0 then
            return "No events found matching: " & query
        end if
        end timeout
    end tell
    return my joinList(output, linefeed)
end searchEvents

-- Create a new event
on createEvent(eventTitle, eventDateStr, durationStr, calendarName)
    tell application "Calendar"
        with timeout of 10 seconds
        -- Find the calendar
        set targetCal to missing value
        repeat with cal in calendars
            if name of cal is calendarName then
                set targetCal to cal
                exit repeat
            end if
        end repeat

        if targetCal is missing value then
            -- Use first calendar as default
            set targetCal to first calendar
        end if

        -- Parse duration (e.g., "1h", "30m", "1h30m")
        set durationMins to my parseDuration(durationStr)

        -- Parse date - expect format like "2024-02-01 10:00"
        set eventDate to my parseDateTime(eventDateStr)
        set eventEndDate to eventDate + (durationMins * 60)

        -- Create the event
        tell targetCal
            set newEvent to make new event with properties {summary:eventTitle, start date:eventDate, end date:eventEndDate}
        end tell

        return "OK: Created '" & eventTitle & "' on " & (eventDate as text) & " in " & (name of targetCal)
        end timeout
    end tell
end createEvent

-- Delete an event by title (deletes first match today or future)
on deleteEvent(eventTitle)
    tell application "Calendar"
        with timeout of 10 seconds
        set todayStart to current date
        set time of todayStart to 0

        repeat with cal in calendars
            try
                set matchingEvents to (every event of cal whose summary is eventTitle and start date ≥ todayStart)
                if (count of matchingEvents) > 0 then
                    set evt to item 1 of matchingEvents
                    set evtDate to start date of evt
                    delete evt
                    return "OK: Deleted '" & eventTitle & "' from " & (evtDate as text)
                end if
            end try
        end repeat

        return "Event not found: " & eventTitle
        end timeout
    end tell
end deleteEvent

-- Helper: Format date/time for display
on formatDateTime(theDate)
    set dateStr to short date string of theDate
    set timeStr to time string of theDate
    -- Simplify time (remove seconds)
    set timeStr to text 1 thru -4 of timeStr
    return dateStr & " " & timeStr
end formatDateTime

-- Helper: Parse duration string like "1h", "30m", "1h30m"
on parseDuration(durationStr)
    set totalMins to 0

    if durationStr contains "h" then
        set hourPart to text 1 thru ((offset of "h" in durationStr) - 1) of durationStr
        set totalMins to totalMins + ((hourPart as integer) * 60)
        if durationStr contains "m" then
            set minPart to text ((offset of "h" in durationStr) + 1) thru ((offset of "m" in durationStr) - 1) of durationStr
            set totalMins to totalMins + (minPart as integer)
        end if
    else if durationStr contains "m" then
        set minPart to text 1 thru ((offset of "m" in durationStr) - 1) of durationStr
        set totalMins to minPart as integer
    else
        -- Assume minutes if no unit
        set totalMins to durationStr as integer
    end if

    if totalMins < 1 then set totalMins to 60 -- Default 1 hour
    return totalMins
end parseDuration

-- Helper: Parse date/time string (basic parser)
on parseDateTime(dateStr)
    -- Expect format: "YYYY-MM-DD HH:MM" or similar
    -- This is a simplified parser - AppleScript's date parsing is locale-dependent
    try
        return date dateStr
    on error
        -- Return tomorrow if parsing fails
        return (current date) + (24 * 60 * 60)
    end try
end parseDateTime

-- Helper: Sort events by date
on sortEventsByDate(eventList)
    set n to count of eventList
    repeat with i from 1 to n - 1
        repeat with j from 1 to n - i
            if startDate of item j of eventList > startDate of item (j + 1) of eventList then
                set temp to item j of eventList
                set item j of eventList to item (j + 1) of eventList
                set item (j + 1) of eventList to temp
            end if
        end repeat
    end repeat
    return eventList
end sortEventsByDate

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList
