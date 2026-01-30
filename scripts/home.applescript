-- home.applescript
-- HomeKit integration via Shortcuts
-- Apple's Home app has no AppleScript support, so we use Shortcuts as a bridge

on run argv
    set cmd to item 1 of argv

    if cmd is "list" then
        return listHomeShortcuts()
    else if cmd is "run" then
        set shortcutName to item 2 of argv
        return runHomeShortcut(shortcutName)
    else if cmd is "setup-check" then
        return checkShortcutsInstalled()
    else
        return "Unknown command: " & cmd
    end if
end run

-- List all shortcuts that start with "homekit-" prefix
on listHomeShortcuts()
    set output to do shell script "shortcuts list | grep -i '^homekit-' || echo 'No HomeKit shortcuts found. Run: apple home setup'"
    return output
end listHomeShortcuts

-- Run a HomeKit shortcut by name
-- Uses Shortcuts Events (AppleScript) instead of `shortcuts run` CLI,
-- which hangs indefinitely on HomeKit actions.
on runHomeShortcut(shortcutName)
    try
        -- Try with homekit- prefix first, fall back to bare name
        tell application "Shortcuts Events"
            set allNames to name of every shortcut
        end tell
        set fullName to "homekit-" & shortcutName
        if allNames does not contain fullName then
            set fullName to shortcutName
        end if
        if allNames does not contain fullName then
            return "ERROR: Shortcut not found: " & shortcutName
        end if
        tell application "Shortcuts Events"
            run shortcut fullName
        end tell
        return "OK: Ran " & fullName
    on error errMsg
        return "ERROR: " & errMsg
    end try
end runHomeShortcut

-- Check which HomeKit shortcuts are installed
on checkShortcutsInstalled()
    set required to {"homekit-lights-on", "homekit-lights-off", "homekit-good-morning", "homekit-good-night"}
    set installed to do shell script "shortcuts list"
    set missing to {}

    repeat with shortcut in required
        if installed does not contain shortcut then
            set end of missing to shortcut
        end if
    end repeat

    if (count of missing) is 0 then
        return "OK: All HomeKit shortcuts installed"
    else
        set missingStr to ""
        repeat with m in missing
            set missingStr to missingStr & m & linefeed
        end repeat
        return "MISSING:" & linefeed & missingStr
    end if
end checkShortcutsInstalled
