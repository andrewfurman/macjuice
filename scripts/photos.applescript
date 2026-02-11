-- photos.applescript
-- Apple Photos integration for macjuice

on run argv
    if (count of argv) < 1 then
        return "Usage: macjuice photos <command> [args...]
Commands: recent [count], search <query>, albums, export <name> <folder>, import <file-path> [album]"
    end if

    set cmd to item 1 of argv

    if cmd is "recent" then
        if (count of argv) > 1 then
            return listRecent(item 2 of argv as integer)
        else
            return listRecent(20)
        end if
    else if cmd is "search" then
        if (count of argv) > 1 then
            return searchPhotos(item 2 of argv)
        else
            return "Usage: macjuice photos search <query>"
        end if
    else if cmd is "albums" then
        return listAlbums()
    else if cmd is "export" then
        if (count of argv) > 2 then
            return exportByName(item 2 of argv, item 3 of argv)
        else
            return "Usage: macjuice photos export <name-or-keyword> <destination-folder>"
        end if
    else if cmd is "import" then
        if (count of argv) > 1 then
            if (count of argv) > 2 then
                return importPhoto(item 2 of argv, item 3 of argv)
            else
                return importPhoto(item 2 of argv, "")
            end if
        else
            return "Usage: macjuice photos import <file-path> [album-name]"
        end if
    else if cmd is "export-recent" then
        if (count of argv) > 2 then
            return exportRecent(item 2 of argv as integer, item 3 of argv)
        else
            return "Usage: macjuice photos export-recent <count> <destination-folder>"
        end if
    else
        return "Unknown command: " & cmd
    end if
end run

-- List recent photos with metadata
on listRecent(maxCount)
    tell application "Photos"
        set recentItems to media items 1 thru maxCount
        set output to {}
        repeat with item_ in recentItems
            set itemDate to date of item_ as text
            set itemName to filename of item_
            set itemDesc to ""
            try
                set itemDesc to description of item_
                if itemDesc is missing value then set itemDesc to ""
            end try
            set itemLine to itemName & " | " & itemDate
            if itemDesc is not "" then
                set itemLine to itemLine & " | " & itemDesc
            end if
            set end of output to itemLine
        end repeat
    end tell
    if (count of output) is 0 then
        return "No photos found."
    end if
    return my joinList(output, linefeed)
end listRecent

-- Search photos by filename or description
on searchPhotos(query)
    tell application "Photos"
        set allItems to media items
        set output to {}
        set maxResults to 30
        set queryLower to my toLowerCase(query)

        repeat with item_ in allItems
            if (count of output) ≥ maxResults then exit repeat
            set itemName to filename of item_
            set itemDesc to ""
            try
                set itemDesc to description of item_
                if itemDesc is missing value then set itemDesc to ""
            end try
            set nameLower to my toLowerCase(itemName)
            set descLower to my toLowerCase(itemDesc)
            if nameLower contains queryLower or descLower contains queryLower then
                set itemDate to date of item_ as text
                set itemLine to itemName & " | " & itemDate
                if itemDesc is not "" then
                    set itemLine to itemLine & " | " & itemDesc
                end if
                set end of output to itemLine
            end if
        end repeat
    end tell
    if (count of output) is 0 then
        return "No photos found matching: " & query
    end if
    return my joinList(output, linefeed)
end searchPhotos

-- List all albums
on listAlbums()
    tell application "Photos"
        set albumList to {}
        repeat with alb in albums
            set albName to name of alb
            set albCount to count of media items of alb
            set end of albumList to albName & " (" & albCount & " items)"
        end repeat
    end tell
    if (count of albumList) is 0 then
        return "No albums found."
    end if
    return my joinList(albumList, linefeed)
end listAlbums

-- Export photos matching a keyword to a folder
on exportByName(query, destFolder)
    set destPath to POSIX file destFolder as alias
    tell application "Photos"
        set allItems to media items
        set matchedItems to {}
        set queryLower to my toLowerCase(query)

        repeat with item_ in allItems
            set itemName to filename of item_
            set itemDesc to ""
            try
                set itemDesc to description of item_
                if itemDesc is missing value then set itemDesc to ""
            end try
            set nameLower to my toLowerCase(itemName)
            set descLower to my toLowerCase(itemDesc)
            if nameLower contains queryLower or descLower contains queryLower then
                set end of matchedItems to item_
            end if
        end repeat

        if (count of matchedItems) is 0 then
            return "No photos found matching: " & query
        end if

        export matchedItems to destPath
        return "OK: Exported " & (count of matchedItems) & " items matching '" & query & "' to " & destFolder
    end tell
end exportByName

-- Export N most recent photos to a folder
on exportRecent(maxCount, destFolder)
    set destPath to POSIX file destFolder as alias
    tell application "Photos"
        set recentItems to media items 1 thru maxCount
        export recentItems to destPath
        return "OK: Exported " & maxCount & " recent items to " & destFolder
    end tell
end exportRecent

-- Import a photo file into Apple Photos, optionally into a specific album
on importPhoto(filePath, albumName)
    set posixFile to POSIX file filePath
    tell application "Photos"
        if albumName is "" then
            import {posixFile}
            return "OK: Imported " & filePath & " into Apple Photos"
        else
            -- Find or create the album
            set targetAlbum to missing value
            try
                set targetAlbum to album albumName
            end try
            if targetAlbum is missing value then
                set targetAlbum to make new album named albumName
            end if
            import {posixFile} into targetAlbum
            return "OK: Imported " & filePath & " into album '" & albumName & "'"
        end if
    end tell
end importPhoto

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
