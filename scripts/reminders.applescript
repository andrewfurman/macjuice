-- reminders.applescript
-- Apple Reminders integration for macjuice

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript reminders.applescript <command> [args...]"
    end if

    set cmd to item 1 of argv

    if cmd is "lists" then
        return listReminderLists()
    else if cmd is "list" then
        set listName to "Reminders"
        if (count of argv) > 1 then set listName to item 2 of argv
        return listReminders(listName)
    else if cmd is "all" then
        return allReminders()
    else if cmd is "today" then
        return todayReminders()
    else if cmd is "overdue" then
        return overdueReminders()
    else if cmd is "add" or cmd is "create" then
        if (count of argv) > 1 then
            set reminderTitle to item 2 of argv
            set listName to "Reminders"
            set dueDate to missing value
            if (count of argv) > 2 then set listName to item 3 of argv
            if (count of argv) > 3 then set dueDate to item 4 of argv
            return addReminder(reminderTitle, listName, dueDate)
        else
            return "Usage: reminders.applescript add <title> [list] [due-date]"
        end if
    else if cmd is "complete" or cmd is "done" then
        if (count of argv) > 1 then
            return completeReminder(item 2 of argv)
        else
            return "Usage: reminders.applescript complete <title>"
        end if
    else if cmd is "delete" then
        if (count of argv) > 1 then
            return deleteReminder(item 2 of argv)
        else
            return "Usage: reminders.applescript delete <title>"
        end if
    else if cmd is "search" then
        if (count of argv) > 1 then
            return searchReminders(item 2 of argv)
        else
            return "Usage: reminders.applescript search <query>"
        end if
    else
        return "Unknown command: " & cmd
    end if
end run

-- List all reminder lists
on listReminderLists()
    tell application "Reminders"
        set output to {}
        repeat with reminderList in lists
            set listInfo to (name of reminderList) & " (" & (count of (reminders of reminderList whose completed is false)) & " incomplete)"
            set end of output to listInfo
        end repeat
    end tell
    return my joinList(output, linefeed)
end listReminderLists

-- List reminders in a specific list
on listReminders(listName)
    tell application "Reminders"
        try
            set targetList to list listName
        on error
            return "List not found: " & listName
        end try

        set output to {}
        set incompleteReminders to (reminders of targetList whose completed is false)

        repeat with r in incompleteReminders
            set rTitle to name of r
            set rLine to "☐ " & rTitle

            -- Add due date if present
            try
                set rDue to due date of r
                if rDue is not missing value then
                    set rLine to rLine & " (due: " & (short date string of rDue) & ")"
                end if
            end try

            -- Add priority indicator
            try
                set rPriority to priority of r
                if rPriority is 1 then
                    set rLine to "❗" & rLine
                else if rPriority is 5 then
                    set rLine to "❕" & rLine
                end if
            end try

            set end of output to rLine
        end repeat

        if (count of output) is 0 then
            return "No incomplete reminders in: " & listName
        end if
    end tell
    return my joinList(output, linefeed)
end listReminders

-- List all incomplete reminders across all lists
on allReminders()
    tell application "Reminders"
        set output to {}
        set maxReminders to 50

        repeat with reminderList in lists
            set listName to name of reminderList
            set incompleteReminders to (reminders of reminderList whose completed is false)

            repeat with r in incompleteReminders
                if (count of output) ≥ maxReminders then exit repeat
                set rTitle to name of r
                set rLine to "☐ " & rTitle & " [" & listName & "]"

                -- Add due date if present
                try
                    set rDue to due date of r
                    if rDue is not missing value then
                        set rLine to rLine & " (due: " & (short date string of rDue) & ")"
                    end if
                end try

                set end of output to rLine
            end repeat

            if (count of output) ≥ maxReminders then exit repeat
        end repeat

        if (count of output) is 0 then
            return "No incomplete reminders"
        end if
    end tell
    return my joinList(output, linefeed)
end allReminders

-- List reminders due today
on todayReminders()
    tell application "Reminders"
        set output to {}
        set todayStart to current date
        set time of todayStart to 0
        set todayEnd to todayStart + (24 * 60 * 60)

        repeat with reminderList in lists
            set listName to name of reminderList
            try
                set todayReminders to (reminders of reminderList whose completed is false and due date ≥ todayStart and due date < todayEnd)
                repeat with r in todayReminders
                    set rTitle to name of r
                    set rDue to due date of r
                    set timeStr to time string of rDue
                    set rLine to "☐ " & rTitle & " @ " & timeStr & " [" & listName & "]"
                    set end of output to rLine
                end repeat
            end try
        end repeat

        if (count of output) is 0 then
            return "No reminders due today"
        end if
    end tell
    return my joinList(output, linefeed)
end todayReminders

-- List overdue reminders
on overdueReminders()
    tell application "Reminders"
        set output to {}
        set now to current date

        repeat with reminderList in lists
            set listName to name of reminderList
            try
                set overdueList to (reminders of reminderList whose completed is false and due date < now and due date is not missing value)
                repeat with r in overdueList
                    set rTitle to name of r
                    set rDue to due date of r
                    set rLine to "⚠️ " & rTitle & " (was due: " & (short date string of rDue) & ") [" & listName & "]"
                    set end of output to rLine
                end repeat
            end try
        end repeat

        if (count of output) is 0 then
            return "No overdue reminders"
        end if
    end tell
    return my joinList(output, linefeed)
end overdueReminders

-- Add a new reminder
on addReminder(reminderTitle, listName, dueDateStr)
    tell application "Reminders"
        -- Find or create the list
        try
            set targetList to list listName
        on error
            -- List doesn't exist, use default
            set targetList to default list
            set listName to name of targetList
        end try

        -- Create reminder properties
        set reminderProps to {name:reminderTitle}

        -- Parse and set due date if provided
        if dueDateStr is not missing value and dueDateStr is not "" then
            set parsedDate to my parseRelativeDate(dueDateStr)
            if parsedDate is not missing value then
                set reminderProps to reminderProps & {due date:parsedDate}
            end if
        end if

        -- Create the reminder
        tell targetList
            make new reminder with properties reminderProps
        end tell

        set resultMsg to "OK: Added '" & reminderTitle & "' to " & listName
        if dueDateStr is not missing value and dueDateStr is not "" then
            set resultMsg to resultMsg & " (due: " & dueDateStr & ")"
        end if
        return resultMsg
    end tell
end addReminder

-- Complete a reminder by title
on completeReminder(reminderTitle)
    tell application "Reminders"
        repeat with reminderList in lists
            try
                set matchingReminders to (reminders of reminderList whose name is reminderTitle and completed is false)
                if (count of matchingReminders) > 0 then
                    set r to item 1 of matchingReminders
                    set completed of r to true
                    return "OK: Completed '" & reminderTitle & "'"
                end if
            end try
        end repeat

        -- Try partial match
        repeat with reminderList in lists
            try
                set matchingReminders to (reminders of reminderList whose name contains reminderTitle and completed is false)
                if (count of matchingReminders) > 0 then
                    set r to item 1 of matchingReminders
                    set rName to name of r
                    set completed of r to true
                    return "OK: Completed '" & rName & "'"
                end if
            end try
        end repeat

        return "Reminder not found: " & reminderTitle
    end tell
end completeReminder

-- Delete a reminder by title
on deleteReminder(reminderTitle)
    tell application "Reminders"
        repeat with reminderList in lists
            try
                set matchingReminders to (reminders of reminderList whose name contains reminderTitle)
                if (count of matchingReminders) > 0 then
                    set r to item 1 of matchingReminders
                    set rName to name of r
                    delete r
                    return "OK: Deleted '" & rName & "'"
                end if
            end try
        end repeat

        return "Reminder not found: " & reminderTitle
    end tell
end deleteReminder

-- Search reminders
on searchReminders(query)
    tell application "Reminders"
        set output to {}
        set maxResults to 20

        repeat with reminderList in lists
            if (count of output) ≥ maxResults then exit repeat
            set listName to name of reminderList

            try
                set matchingReminders to (reminders of reminderList whose name contains query)
                repeat with r in matchingReminders
                    if (count of output) ≥ maxResults then exit repeat
                    set rTitle to name of r
                    set rCompleted to completed of r

                    if rCompleted then
                        set rLine to "☑ " & rTitle & " [" & listName & "] (completed)"
                    else
                        set rLine to "☐ " & rTitle & " [" & listName & "]"
                    end if

                    set end of output to rLine
                end repeat
            end try
        end repeat

        if (count of output) is 0 then
            return "No reminders found matching: " & query
        end if
    end tell
    return my joinList(output, linefeed)
end searchReminders

-- Helper: Parse relative date strings like "tomorrow", "next week", "5pm"
on parseRelativeDate(dateStr)
    set now to current date
    set lowerStr to my toLowerCase(dateStr)

    if lowerStr is "today" then
        return now
    else if lowerStr is "tomorrow" then
        return now + (24 * 60 * 60)
    else if lowerStr contains "next week" then
        return now + (7 * 24 * 60 * 60)
    else if lowerStr contains "pm" or lowerStr contains "am" then
        -- Try to parse time like "5pm" or "10am"
        try
            set targetDate to now
            set timeStr to dateStr
            -- Remove am/pm and parse
            if lowerStr contains "pm" then
                set hourNum to (text 1 thru ((offset of "p" in lowerStr) - 1) of lowerStr) as integer
                if hourNum < 12 then set hourNum to hourNum + 12
                set time of targetDate to hourNum * 60 * 60
            else if lowerStr contains "am" then
                set hourNum to (text 1 thru ((offset of "a" in lowerStr) - 1) of lowerStr) as integer
                set time of targetDate to hourNum * 60 * 60
            end if
            return targetDate
        on error
            return missing value
        end try
    else
        -- Try standard date parsing
        try
            return date dateStr
        on error
            return missing value
        end try
    end if
end parseRelativeDate

-- Helper: Convert to lowercase
on toLowerCase(str)
    set lowercaseChars to "abcdefghijklmnopqrstuvwxyz"
    set uppercaseChars to "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    set resultStr to ""

    repeat with c in (characters of str)
        set c to c as text
        if uppercaseChars contains c then
            set idx to offset of c in uppercaseChars
            set resultStr to resultStr & (character idx of lowercaseChars)
        else
            set resultStr to resultStr & c
        end if
    end repeat

    return resultStr
end toLowerCase

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList
