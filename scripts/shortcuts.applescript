-- shortcuts.applescript
-- Run and manage macOS Shortcuts from the CLI
-- Uses Shortcuts Events (AppleScript) for reliable execution

on run argv
    if (count of argv) < 1 then
        return "Usage: macjuice shortcuts <command> [args...]
Commands: list, run <name>, search <query>"
    end if

    set cmd to item 1 of argv

    if cmd is "list" then
        return listShortcuts()
    else if cmd is "run" then
        if (count of argv) < 2 then
            return "Usage: macjuice shortcuts run <name>"
        end if
        return runShortcut(item 2 of argv)
    else if cmd is "search" then
        if (count of argv) < 2 then
            return "Usage: macjuice shortcuts search <query>"
        end if
        return searchShortcuts(item 2 of argv)
    else
        return "Unknown command: " & cmd
    end if
end run

-- List all shortcuts
on listShortcuts()
    tell application "Shortcuts Events"
        set allShortcuts to name of every shortcut
    end tell
    if (count of allShortcuts) is 0 then
        return "No shortcuts found."
    end if
    set output to {}
    repeat with s in allShortcuts
        set end of output to s as text
    end repeat
    return my joinList(output, linefeed)
end listShortcuts

-- Run a shortcut by name
on runShortcut(shortcutName)
    tell application "Shortcuts Events"
        set allNames to name of every shortcut
    end tell
    if allNames does not contain shortcutName then
        return "ERROR: Shortcut not found: " & shortcutName & linefeed & "Run 'macjuice shortcuts list' to see available shortcuts."
    end if
    try
        tell application "Shortcuts Events"
            run shortcut shortcutName
        end tell
        return "OK: Ran " & shortcutName
    on error errMsg
        return "ERROR: " & errMsg
    end try
end runShortcut

-- Search shortcuts by name
on searchShortcuts(query)
    tell application "Shortcuts Events"
        set allShortcuts to name of every shortcut
    end tell
    set matches to {}
    set queryLower to my toLowerCase(query)
    repeat with s in allShortcuts
        set sLower to my toLowerCase(s as text)
        if sLower contains queryLower then
            set end of matches to s as text
        end if
    end repeat
    if (count of matches) is 0 then
        return "No shortcuts found matching: " & query
    end if
    return my joinList(matches, linefeed)
end searchShortcuts

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList

-- Helper: Convert to lowercase
on toLowerCase(theText)
    set lowText to do shell script "echo " & quoted form of theText & " | tr '[:upper:]' '[:lower:]'"
    return lowText
end toLowerCase
