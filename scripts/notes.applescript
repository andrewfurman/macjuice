-- notes.applescript
-- Apple Notes integration for apple-cli

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript notes.applescript <command> [args...]"
    end if

    set cmd to item 1 of argv

    if cmd is "list" then
        return listNotes()
    else if cmd is "folders" then
        return listFolders()
    else if cmd is "create" then
        if (count of argv) > 2 then
            return createNote(item 2 of argv, item 3 of argv)
        else
            return "Usage: notes.applescript create <title> <body>"
        end if
    else if cmd is "read" then
        if (count of argv) > 1 then
            return readNote(item 2 of argv)
        else
            return "Usage: notes.applescript read <note-name>"
        end if
    else if cmd is "search" then
        if (count of argv) > 1 then
            return searchNotes(item 2 of argv)
        else
            return "Usage: notes.applescript search <query>"
        end if
    else
        return "Unknown command: " & cmd
    end if
end run

-- List all notes
on listNotes()
    tell application "Notes"
        set output to {}
        set maxNotes to 50

        repeat with n in notes
            if (count of output) ≥ maxNotes then exit repeat
            set noteInfo to (id of n) & " | " & (modification date of n as text) & " | " & (name of n)
            set end of output to noteInfo
        end repeat

        return joinList(output, linefeed)
    end tell
end listNotes

-- List all folders
on listFolders()
    tell application "Notes"
        set output to {}
        repeat with f in folders
            set folderInfo to (name of f) & " (" & (count of notes in f) & " notes)"
            set end of output to folderInfo
        end repeat
        return joinList(output, linefeed)
    end tell
end listFolders

-- Create a new note
on createNote(noteTitle, noteBody)
    tell application "Notes"
        tell folder "Notes"
            set newNote to make new note with properties {name:noteTitle, body:noteBody}
            return "OK: Created note '" & noteTitle & "'"
        end tell
    end tell
end createNote

-- Read a note by name
on readNote(noteName)
    tell application "Notes"
        try
            set theNote to first note whose name is noteName
            set output to "Title: " & (name of theNote) & linefeed
            set output to output & "Modified: " & (modification date of theNote as text) & linefeed
            set output to output & "Created: " & (creation date of theNote as text) & linefeed
            set output to output & linefeed & (plaintext of theNote)
            return output
        on error
            return "Note not found: " & noteName
        end try
    end tell
end readNote

-- Search notes
on searchNotes(query)
    tell application "Notes"
        set output to {}
        set maxResults to 20

        repeat with n in notes
            if (count of output) ≥ maxResults then exit repeat
            if (name of n) contains query or (plaintext of n) contains query then
                set noteInfo to (name of n) & " | " & (modification date of n as text)
                set end of output to noteInfo
            end if
        end repeat

        if (count of output) is 0 then
            return "No notes found matching: " & query
        end if
        return joinList(output, linefeed)
    end tell
end searchNotes

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList
