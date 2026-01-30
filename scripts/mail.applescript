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
            return draftMessage(item 2 of argv, item 3 of argv, item 4 of argv)
        else
            return "Usage: mail.applescript draft <to> <subject> <body>"
        end if
    else if cmd is "send" then
        if (count of argv) > 3 then
            return sendMessage(item 2 of argv, item 3 of argv, item 4 of argv)
        else
            return "Usage: mail.applescript send <to> <subject> <body>"
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

-- Create a draft message (saved and opened, not sent)
on draftMessage(toAddr, subjectText, bodyText)
    tell application "Mail"
        set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, visible:true}
        tell newMessage
            make new to recipient at end of to recipients with properties {address:toAddr}
        end tell
        -- Do not send — leave as draft
        return "OK: Draft saved and opened in Mail for " & toAddr
    end tell
end draftMessage

-- Send a new message
on sendMessage(toAddr, subjectText, bodyText)
    tell application "Mail"
        set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, visible:true}
        tell newMessage
            make new to recipient at end of to recipients with properties {address:toAddr}
        end tell
        send newMessage
        return "OK: Message sent to " & toAddr
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
