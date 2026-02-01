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
                set msgs to messages 1 thru maxMessages of mb
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
        set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, visible:true}
        tell newMessage
            make new to recipient at end of to recipients with properties {address:toAddr}
            -- Set sender if specified
            if senderAddr is not "" then
                set sender to senderAddr
            end if
            -- Set CC if specified
            if ccAddr is not "" then
                make new cc recipient at end of cc recipients with properties {address:ccAddr}
            end if
            -- Set BCC if specified
            if bccAddr is not "" then
                make new bcc recipient at end of bcc recipients with properties {address:bccAddr}
            end if
            repeat with attachPath in attachmentPaths
                set attachFile to POSIX file (attachPath as text) as alias
                make new attachment with properties {file name:attachFile} at after the last paragraph
            end repeat
        end tell
        -- Save as draft: close the compose window which triggers save-to-Drafts
        delay 0.5
        close window 1 saving yes
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

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList
