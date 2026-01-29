-- music.applescript
-- Apple Music integration for apple-cli

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript music.applescript <command> [args...]"
    end if

    set cmd to item 1 of argv

    if cmd is "play" then
        return musicPlay()
    else if cmd is "pause" then
        return musicPause()
    else if cmd is "toggle" then
        return musicToggle()
    else if cmd is "next" then
        return musicNext()
    else if cmd is "previous" then
        return musicPrevious()
    else if cmd is "now" then
        return musicNowPlaying()
    else if cmd is "volume" then
        if (count of argv) > 1 then
            return setVolume(item 2 of argv)
        else
            return getVolume()
        end if
    else if cmd is "search" then
        if (count of argv) > 1 then
            return searchMusic(item 2 of argv)
        else
            return "Usage: music.applescript search <query>"
        end if
    else if cmd is "playlists" then
        return listPlaylists()
    else
        return "Unknown command: " & cmd
    end if
end run

-- Play
on musicPlay()
    tell application "Music"
        play
        return "OK: Playing"
    end tell
end musicPlay

-- Pause
on musicPause()
    tell application "Music"
        pause
        return "OK: Paused"
    end tell
end musicPause

-- Toggle play/pause
on musicToggle()
    tell application "Music"
        playpause
        return "OK: Toggled playback"
    end tell
end musicToggle

-- Next track
on musicNext()
    tell application "Music"
        next track
        delay 0.5
        return musicNowPlaying()
    end tell
end musicNext

-- Previous track
on musicPrevious()
    tell application "Music"
        previous track
        delay 0.5
        return musicNowPlaying()
    end tell
end musicPrevious

-- Now playing info
on musicNowPlaying()
    tell application "Music"
        if player state is playing then
            set trackName to name of current track
            set artistName to artist of current track
            set albumName to album of current track
            set trackDuration to duration of current track
            set playerPos to player position

            set output to "▶ " & trackName & linefeed
            set output to output & "  Artist: " & artistName & linefeed
            set output to output & "  Album: " & albumName & linefeed
            set output to output & "  Position: " & (round playerPos) & "s / " & (round trackDuration) & "s"
            return output
        else if player state is paused then
            set trackName to name of current track
            set artistName to artist of current track
            return "⏸ " & trackName & " - " & artistName & " (paused)"
        else
            return "⏹ Not playing"
        end if
    end tell
end musicNowPlaying

-- Get volume
on getVolume()
    tell application "Music"
        return "Volume: " & (sound volume as text) & "%"
    end tell
end getVolume

-- Set volume (0-100)
on setVolume(level)
    tell application "Music"
        set sound volume to (level as integer)
        return "OK: Volume set to " & level & "%"
    end tell
end setVolume

-- List playlists
on listPlaylists()
    tell application "Music"
        set output to {}
        repeat with p in playlists
            set playlistInfo to (name of p) & " (" & (count of tracks of p) & " tracks)"
            set end of output to playlistInfo
        end repeat
        return joinList(output, linefeed)
    end tell
end listPlaylists

-- Search library
on searchMusic(query)
    tell application "Music"
        set output to {}
        set maxResults to 20

        set foundTracks to (every track of library playlist 1 whose name contains query or artist contains query)
        repeat with t in foundTracks
            if (count of output) ≥ maxResults then exit repeat
            set trackInfo to (name of t) & " - " & (artist of t) & " [" & (album of t) & "]"
            set end of output to trackInfo
        end repeat

        if (count of output) is 0 then
            return "No tracks found matching: " & query
        end if
        return joinList(output, linefeed)
    end tell
end searchMusic

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList
