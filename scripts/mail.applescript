-- mail.applescript
-- Apple Mail integration for apple-cli

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript mail.applescript <command> [args...]"
    end if

    set cmd to item 1 of argv

    if cmd is "accounts" then
        return listAccounts()
    else if cmd is "list" then
        if (count of argv) > 1 then
            return listMessages(item 2 of argv)
        else
            return listMessages("INBOX")
        end if
    else if cmd is "search" then
        if (count of argv) > 1 then
            return searchMessages(item 2 of argv)
        else
            return "Usage: mail.applescript search <query>"
        end if
    else if cmd is "read" then
        if (count of argv) > 1 then
            return readMessage(item 2 of argv)
        else
            return "Usage: mail.applescript read <message-id>"
        end if
    else if cmd is "draft" then
        if (count of argv) > 3 then
            -- Parse optional flags: --from=, --cc=, --bcc=, and attachment paths
            set senderAddr to ""
            set ccAddr to ""
            set bccAddr to ""
            set attachments to {}
            if (count of argv) > 4 then
                repeat with i from 5 to (count of argv)
                    set arg to item i of argv
                    if arg starts with "--from=" then
                        set senderAddr to text 8 thru -1 of arg
                    else if arg starts with "--cc=" then
                        set ccAddr to text 6 thru -1 of arg
                    else if arg starts with "--bcc=" then
                        set bccAddr to text 7 thru -1 of arg
                    else
                        set end of attachments to arg
                    end if
                end repeat
            end if
            return draftMessage(item 2 of argv, item 3 of argv, item 4 of argv, senderAddr, ccAddr, bccAddr, attachments)
        else
            return "Usage: mail.applescript draft <to> <subject> <body> [--from=email] [--cc=email] [--bcc=email] [attachment ...]"
        end if
    else if cmd is "reply" then
        -- reply <message-id> <body> [--from=email] [--cc=emails] [--bcc=emails]
        if (count of argv) > 2 then
            set senderAddr to ""
            set ccAddr to ""
            set bccAddr to ""
            if (count of argv) > 3 then
                repeat with i from 4 to (count of argv)
                    set arg to item i of argv
                    if arg starts with "--from=" then
                        set senderAddr to text 8 thru -1 of arg
                    else if arg starts with "--cc=" then
                        set ccAddr to text 6 thru -1 of arg
                    else if arg starts with "--bcc=" then
                        set bccAddr to text 7 thru -1 of arg
                    end if
                end repeat
            end if
            return replyMessage(item 2 of argv, item 3 of argv, senderAddr, ccAddr, bccAddr)
        else
            return "Usage: mail.applescript reply <message-id> <body> [--from=email] [--cc=emails] [--bcc=emails]"
        end if
    else if cmd is "delete-draft" then
        if (count of argv) > 1 then
            return deleteDraft(item 2 of argv)
        else
            return "Usage: mail.applescript delete-draft <message-id>"
        end if
    else if cmd is "send" then
        if (count of argv) > 3 then
            set senderAddr to ""
            set attachStart to 5
            if (count of argv) > 4 then
                if item 5 of argv starts with "--from=" then
                    set senderAddr to text 8 thru -1 of item 5 of argv
                    set attachStart to 6
                end if
            end if
            set attachments to {}
            if (count of argv) ≥ attachStart then
                repeat with i from attachStart to (count of argv)
                    set end of attachments to item i of argv
                end repeat
            end if
            return sendMessage(item 2 of argv, item 3 of argv, item 4 of argv, senderAddr, attachments)
        else
            return "Usage: mail.applescript send <to> <subject> <body> [--from=email] [attachment1] ..."
        end if
    else
        return "Unknown command: " & cmd
    end if
end run

-- List all mail accounts
on listAccounts()
    tell application "Mail"
        set accountList to {}
        repeat with acc in accounts
            set end of accountList to (name of acc) & " (" & (email addresses of acc as text) & ")"
        end repeat
    end tell
    return my joinList(accountList, linefeed)
end listAccounts

-- List messages in a mailbox
on listMessages(mailboxName)
    tell application "Mail"
        set output to {}
        set maxMessages to 20

        repeat with acc in accounts
            try
                set mb to mailbox mailboxName of acc
                set msgCount to count of messages of mb
                if msgCount is 0 then error "empty"
                if msgCount > maxMessages then set msgCount to maxMessages
                set msgs to messages 1 thru msgCount of mb
                repeat with msg in msgs
                    set msgLine to (id of msg as text) & " | " & (date sent of msg as text) & " | " & (sender of msg) & " | " & (subject of msg)
                    set end of output to msgLine
                end repeat
            end try
        end repeat

        if (count of output) is 0 then
            return "No messages found in " & mailboxName
        end if
    end tell
    return my joinList(output, linefeed)
end listMessages

-- Search messages
on searchMessages(query)
    tell application "Mail"
        set output to {}
        set maxResults to 20

        repeat with acc in accounts
            try
                set inbox to mailbox "INBOX" of acc
                set foundMsgs to (messages of inbox whose subject contains query or sender contains query)
                repeat with msg in foundMsgs
                    if (count of output) ≥ maxResults then exit repeat
                    set msgLine to (id of msg as text) & " | " & (sender of msg) & " | " & (subject of msg)
                    set end of output to msgLine
                end repeat
            end try
        end repeat

        if (count of output) is 0 then
            return "No messages found matching: " & query
        end if
    end tell
    return my joinList(output, linefeed)
end searchMessages

-- Read a specific message
on readMessage(messageId)
    tell application "Mail"
        repeat with acc in accounts
            repeat with mb in mailboxes of acc
                try
                    set msg to (first message of mb whose id is messageId)
                    set output to "From: " & (sender of msg) & linefeed
                    set output to output & "To: " & (address of to recipient of msg) & linefeed
                    set output to output & "Subject: " & (subject of msg) & linefeed
                    set output to output & "Date: " & (date sent of msg as text) & linefeed
                    set output to output & linefeed & (content of msg)
                    return output
                end try
            end repeat
        end repeat
        return "Message not found: " & messageId
    end tell
end readMessage

-- Create a draft message and save it to the Drafts folder
on draftMessage(toAddr, subjectText, bodyText, senderAddr, ccAddr, bccAddr, attachmentPaths)
    tell application "Mail"
        activate
        -- Track which windows exist before creating the compose window
        set windowIdsBefore to {}
        repeat with w in windows
            try
                set end of windowIdsBefore to id of w
            end try
        end repeat
        set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, visible:true}
        tell newMessage
            make new to recipient at end of to recipients with properties {address:toAddr}
            -- Set sender if specified
            if senderAddr is not "" then
                set sender to senderAddr
            end if
            -- Set CC if specified (supports comma-separated list)
            if ccAddr is not "" then
                set ccList to my splitCommaList(ccAddr)
                repeat with addr in ccList
                    make new cc recipient at end of cc recipients with properties {address:addr}
                end repeat
            end if
            -- Set BCC if specified (supports comma-separated list)
            if bccAddr is not "" then
                set bccList to my splitCommaList(bccAddr)
                repeat with addr in bccList
                    make new bcc recipient at end of bcc recipients with properties {address:addr}
                end repeat
            end if
            repeat with attachPath in attachmentPaths
                set attachFile to POSIX file (attachPath as text) as alias
                make new attachment with properties {file name:attachFile} at after the last paragraph
            end repeat
        end tell
        -- Find the NEW compose window and close it to trigger save-as-draft dialog
        delay 1
        set composeWindowName to ""
        repeat with w in windows
            try
                set wId to id of w
                if windowIdsBefore does not contain wId then
                    set composeWindowName to name of w
                    close w
                    exit repeat
                end if
            end try
        end repeat
    end tell
    -- Click "Save" in the save-as-draft dialog sheet
    delay 1
    tell application "System Events"
        tell process "Mail"
            set frontmost to true
            -- Find the window with the sheet dialog and click Save
            repeat with w in windows
                try
                    click button "Save" of sheet 1 of w
                    exit repeat
                end try
            end repeat
        end tell
    end tell
    delay 1
    tell application "Mail"
        -- Build status message
        set fromNote to ""
        if senderAddr is not "" then
            set fromNote to " from " & senderAddr
        end if
        set extras to ""
        if ccAddr is not "" then
            set extras to extras & " cc:" & ccAddr
        end if
        if bccAddr is not "" then
            set extras to extras & " bcc:" & bccAddr
        end if
        set attachCount to count of attachmentPaths
        if attachCount > 0 then
            set extras to extras & " (" & attachCount & " attachments)"
        end if
        return "OK: Draft saved to Drafts for " & toAddr & fromNote & extras
    end tell
end draftMessage

-- Send a new message
on sendMessage(toAddr, subjectText, bodyText, senderAddr, attachmentPaths)
    tell application "Mail"
        set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, visible:true}
        tell newMessage
            make new to recipient at end of to recipients with properties {address:toAddr}
            if senderAddr is not "" then
                set sender to senderAddr
            end if
            repeat with attachPath in attachmentPaths
                set attachFile to POSIX file (attachPath as text) as alias
                make new attachment with properties {file name:attachFile} at after the last paragraph
            end repeat
        end tell
        send newMessage
        set attachCount to count of attachmentPaths
        if attachCount > 0 then
            return "OK: Message sent to " & toAddr & " with " & attachCount & " attachments"
        else
            return "OK: Message sent to " & toAddr
        end if
    end tell
end sendMessage

-- Delete a draft message by ID
on deleteDraft(messageId)
    tell application "Mail"
        repeat with acc in accounts
            repeat with mb in mailboxes of acc
                try
                    set msg to (first message of mb whose id is messageId)
                    set subj to subject of msg
                    delete msg
                    return "OK: Draft deleted (subject: " & subj & ")"
                end try
            end repeat
        end repeat
        return "Message not found: " & messageId
    end tell
end deleteDraft

-- Reply-all to an existing message (saves as draft, preserves quoted thread)
on replyMessage(messageId, bodyText, senderAddr, ccAddr, bccAddr)
    tell application "Mail"
        -- Find the original message by ID (same pattern as readMessage)
        repeat with acc in accounts
            repeat with mb in mailboxes of acc
                try
                    set origMsg to (first message of mb whose id is messageId)
                    -- Use reply-all so all To/CC recipients are included
                    set replyMsg to reply origMsg with opening window and reply to all
                    if senderAddr is not "" then
                        set sender of replyMsg to senderAddr
                    end if
                    -- Add additional CC recipients (supports comma-separated list)
                    if ccAddr is not "" then
                        set ccList to my splitCommaList(ccAddr)
                        tell replyMsg
                            repeat with addr in ccList
                                make new cc recipient at end of cc recipients with properties {address:addr}
                            end repeat
                        end tell
                    end if
                    -- Add BCC recipients (supports comma-separated list)
                    if bccAddr is not "" then
                        set bccList to my splitCommaList(bccAddr)
                        tell replyMsg
                            repeat with addr in bccList
                                make new bcc recipient at end of bcc recipients with properties {address:addr}
                            end repeat
                        end tell
                    end if
                    -- Wait for compose window to fully load with quoted content
                    delay 1.5
                    -- Use clipboard paste to insert body text at cursor position
                    -- The cursor starts at the top of the reply body, so pasting here
                    -- preserves the quoted thread below
                    set oldClipboard to the clipboard
                    set the clipboard to bodyText & linefeed & linefeed
                    tell application "System Events"
                        tell process "Mail"
                            set frontmost to true
                            keystroke "v" using command down
                        end tell
                    end tell
                    delay 0.5
                    set the clipboard to oldClipboard
                    -- Save as draft
                    delay 0.5
                    close window 1 saving yes
                    -- Build status message
                    set extras to ""
                    if ccAddr is not "" then
                        set extras to extras & " cc:" & ccAddr
                    end if
                    if bccAddr is not "" then
                        set extras to extras & " bcc:" & bccAddr
                    end if
                    return "OK: Reply-all draft saved (to " & sender of origMsg & ", re: " & subject of origMsg & ")" & extras
                end try
            end repeat
        end repeat
        return "Message not found: " & messageId
    end tell
end replyMessage

-- Helper: Split comma-separated string into a list, trimming whitespace
on splitCommaList(theString)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ","
    set theItems to text items of theString
    set AppleScript's text item delimiters to oldDelimiters
    set trimmedList to {}
    repeat with anItem in theItems
        -- Trim leading/trailing spaces
        set trimmed to anItem as text
        repeat while trimmed starts with " "
            set trimmed to text 2 thru -1 of trimmed
        end repeat
        repeat while trimmed ends with " "
            set trimmed to text 1 thru -2 of trimmed
        end repeat
        if trimmed is not "" then
            set end of trimmedList to trimmed
        end if
    end repeat
    return trimmedList
end splitCommaList

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList
