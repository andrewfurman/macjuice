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
    else if cmd is "html-draft" then
        -- html-draft <to> <subject> [--from=email] [--cc=emails] [--bcc=emails]
        -- Clipboard must already contain RTF (loaded by Python helper before this call)
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
            return htmlDraftMessage(item 2 of argv, item 3 of argv, senderAddr, ccAddr, bccAddr)
        else
            return "Usage: mail.applescript html-draft <to> <subject> [--from=email] [--cc=emails] [--bcc=emails]"
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
    else if cmd is "attach" then
        -- attach <message-id> <file1> [file2] ...
        if (count of argv) > 2 then
            set filePaths to {}
            repeat with i from 3 to (count of argv)
                set end of filePaths to item i of argv
            end repeat
            return attachToDraft(item 2 of argv, filePaths)
        else
            return "Usage: mail.applescript attach <message-id> <file1> [file2] ..."
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
                set inbox to missing value
                try
                    set inbox to mailbox "INBOX" of acc
                end try
                if inbox is missing value then
                    try
                        set inbox to mailbox "Inbox" of acc
                    end try
                end if
                if inbox is missing value then error "no inbox"
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
-- When --from is specified, saves to that account's Drafts folder (not iCloud default)
on draftMessage(toAddr, subjectText, bodyText, senderAddr, ccAddr, bccAddr, attachmentPaths)
    tell application "Mail"
        activate
        -- Create outgoing message with sender in initial properties so Mail routes to correct account
        if senderAddr is not "" then
            set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, sender:senderAddr, visible:true}
        else
            set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, visible:true}
        end if
        tell newMessage
            make new to recipient at end of to recipients with properties {address:toAddr}
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
                delay 1
            end repeat
        end tell
        -- Wait for compose window to fully render
        set attachCount to count of attachmentPaths
        if attachCount > 0 then
            delay (attachCount * 1 + 2)
        else
            delay 2
        end if
    end tell
    -- Save with Cmd+S then close with Cmd+W
    -- Note: sender property correctly sets the From dropdown, but draft saves to iCloud Drafts
    -- (this is an Apple Mail limitation — the From address IS correct when user opens the draft)
    tell application "System Events"
        tell process "Mail"
            set frontmost to true
            delay 0.3
            keystroke "s" using command down
        end tell
    end tell
    delay 2
    tell application "System Events"
        tell process "Mail"
            keystroke "w" using command down
        end tell
    end tell
    delay 1
    -- Handle save dialog in case it still appears
    tell application "System Events"
        tell process "Mail"
            try
                click button "Don't Save" of sheet 1 of (first window whose subrole is "AXStandardWindow")
            end try
        end tell
    end tell
    delay 0.5
    tell application "Mail"
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

-- Create an HTML draft: compose window with recipients, then paste RTF from clipboard
-- Clipboard must already be loaded with RTF content before calling this
on htmlDraftMessage(toAddr, subjectText, senderAddr, ccAddr, bccAddr)
    tell application "Mail"
        activate
        if senderAddr is not "" then
            set newMessage to make new outgoing message with properties {subject:subjectText, content:"PLACEHOLDER_BODY", sender:senderAddr, visible:true}
        else
            set newMessage to make new outgoing message with properties {subject:subjectText, content:"PLACEHOLDER_BODY", visible:true}
        end if
        tell newMessage
            set toList to my splitCommaList(toAddr)
            repeat with addr in toList
                make new to recipient at end of to recipients with properties {address:addr}
            end repeat
            if ccAddr is not "" then
                set ccList to my splitCommaList(ccAddr)
                repeat with addr in ccList
                    make new cc recipient at end of cc recipients with properties {address:addr}
                end repeat
            end if
            if bccAddr is not "" then
                set bccList to my splitCommaList(bccAddr)
                repeat with addr in bccList
                    make new bcc recipient at end of bcc recipients with properties {address:addr}
                end repeat
            end if
        end tell
    end tell

    -- Wait for compose window to fully render
    delay 1.5

    -- Click into body and paste (all in one System Events block so front window = compose window)
    tell application "System Events"
        tell process "Mail"
            set frontmost to true
            delay 0.3
            try
                click scroll area 1 of front window
            end try
            delay 0.3
            keystroke "a" using command down
            delay 0.2
            keystroke "v" using command down
        end tell
    end tell

    delay 0.5

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
    return "OK: HTML draft opened for " & toAddr & fromNote & extras
end htmlDraftMessage

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
                    -- Collect existing To/CC/BCC addresses to avoid duplicates
                    set existingAddrs to {}
                    tell replyMsg
                        repeat with r in to recipients
                            set end of existingAddrs to address of r
                        end repeat
                        repeat with r in cc recipients
                            set end of existingAddrs to address of r
                        end repeat
                        repeat with r in bcc recipients
                            set end of existingAddrs to address of r
                        end repeat
                    end tell
                    -- Add BCC recipients, skipping any already in To/CC/BCC
                    if bccAddr is not "" then
                        set bccList to my splitCommaList(bccAddr)
                        tell replyMsg
                            repeat with addr in bccList
                                set addrText to addr as text
                                if existingAddrs does not contain addrText then
                                    make new bcc recipient at end of bcc recipients with properties {address:addrText}
                                end if
                            end repeat
                        end tell
                    end if
                    -- Wait for compose window to fully load with quoted content
                    delay 2
                    -- Insert body text via clipboard paste at cursor position
                    -- (cursor starts at top of reply body, above quoted thread)
                    -- Setting the content property directly wipes the HTML-formatted
                    -- quoted thread, so clipboard paste is the reliable approach
                    set oldClipboard to the clipboard
                    set the clipboard to bodyText & linefeed & linefeed
                    tell application "Mail"
                        activate
                    end tell
                    delay 0.5
                    tell application "System Events"
                        tell process "Mail"
                            set frontmost to true
                            delay 0.3
                            keystroke "v" using command down
                        end tell
                    end tell
                    delay 0.5
                    set the clipboard to oldClipboard
                    -- Build status message
                    set extras to ""
                    if ccAddr is not "" then
                        set extras to extras & " cc:" & ccAddr
                    end if
                    if bccAddr is not "" then
                        set extras to extras & " bcc:" & bccAddr
                    end if
                    return "OK: Reply-all draft opened (to " & sender of origMsg & ", re: " & subject of origMsg & ")" & extras
                end try
            end repeat
        end repeat
        return "Message not found: " & messageId
    end tell
end replyMessage

-- Attach files to an existing draft message
-- Opens the draft as a compose window, adds attachments, and leaves open for review
on attachToDraft(messageId, filePaths)
    tell application "Mail"
        activate
        -- Find the draft message across all accounts/mailboxes
        set foundMsg to missing value
        set foundSubj to ""
        repeat with acc in accounts
            repeat with mb in mailboxes of acc
                try
                    set msg to (first message of mb whose id is (messageId as integer))
                    set foundMsg to msg
                    set foundSubj to subject of msg
                    exit repeat
                end try
            end repeat
            if foundMsg is not missing value then exit repeat
        end repeat

        if foundMsg is missing value then
            return "Draft not found: " & messageId
        end if

        -- Open the draft (opens as editable compose window)
        open foundMsg
        delay 3
    end tell

    -- Attach each file using pbcopy + paste approach
    -- pbcopy with file references puts files on clipboard as attachable objects
    set attachCount to count of filePaths
    set attachedCount to 0
    repeat with filePath in filePaths
        set filePathStr to filePath as text
        -- Use osascript to set the clipboard to the file reference
        -- This puts the file on the pasteboard in a way Mail recognizes as attachment
        try
            do shell script "osascript -e 'set the clipboard to (POSIX file \"" & filePathStr & "\" as alias)'"
            delay 0.5

            -- Paste into Mail compose window
            tell application "Mail"
                activate
            end tell
            delay 0.3
            tell application "System Events"
                tell process "Mail"
                    set frontmost to true
                    delay 0.2
                    keystroke "v" using command down
                end tell
            end tell
            delay 2
            set attachedCount to attachedCount + 1
        on error errMsg
            -- File not found or clipboard failed, skip
        end try
    end repeat

    -- Wait for all attachments to fully load
    delay (attachedCount + 2)

    -- Compose window left open for user to review and send
    return "OK: Attached " & attachedCount & " of " & attachCount & " file(s) to draft: " & foundSubj & " — compose window left open for review"
end attachToDraft

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
