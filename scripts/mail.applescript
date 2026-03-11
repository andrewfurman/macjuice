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
            set accountFilter to ""
            if (count of argv) > 2 then set accountFilter to item 3 of argv
            return searchMessages(item 2 of argv, accountFilter)
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
    else if cmd is "forward" then
        -- forward <message-id> <to> [--from=email] [--cc=emails] [--bcc=emails] [--body=text] [attachment ...]
        if (count of argv) > 2 then
            set senderAddr to ""
            set ccAddr to ""
            set bccAddr to ""
            set bodyText to ""
            set attachments to {}
            if (count of argv) > 3 then
                repeat with i from 4 to (count of argv)
                    set arg to item i of argv
                    if arg starts with "--from=" then
                        set senderAddr to text 8 thru -1 of arg
                    else if arg starts with "--cc=" then
                        set ccAddr to text 6 thru -1 of arg
                    else if arg starts with "--bcc=" then
                        set bccAddr to text 7 thru -1 of arg
                    else if arg starts with "--body=" then
                        set bodyText to text 8 thru -1 of arg
                    else
                        set end of attachments to arg
                    end if
                end repeat
            end if
            return forwardMessage(item 2 of argv, item 3 of argv, bodyText, senderAddr, ccAddr, bccAddr, attachments)
        else
            return "Usage: mail.applescript forward <message-id> <to> [--from=email] [--cc=emails] [--bcc=emails] [--body=text] [attachment ...]"
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
    else if cmd is "attachments" then
        if (count of argv) > 1 then
            return listAttachments(item 2 of argv)
        else
            return "Usage: mail.applescript attachments <message-id>"
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
        with timeout of 30 seconds
            set accountList to {}
            repeat with acc in accounts
                set end of accountList to (name of acc) & " (" & (email addresses of acc as text) & ")"
            end repeat
        end timeout
    end tell
    return my joinList(accountList, linefeed)
end listAccounts

-- List messages in a mailbox
on listMessages(mailboxName)
    tell application "Mail"
        with timeout of 30 seconds
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
        end timeout
    end tell
    return my joinList(output, linefeed)
end listMessages

-- Helper: Check if an account matches the filter string (email or account name)
on accountMatchesFilter(acc, filterStr)
    if filterStr is "" then return true
    tell application "Mail"
        with timeout of 30 seconds
            set accName to name of acc
            set accEmails to email addresses of acc
        end timeout
    end tell
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to ","
    set filterItems to text items of filterStr
    set AppleScript's text item delimiters to oldDelimiters
    repeat with f in filterItems
        set f to f as text
        repeat while f starts with " "
            if (count of f) > 1 then
                set f to text 2 thru -1 of f
            else
                set f to ""
            end if
        end repeat
        repeat while f ends with " "
            if (count of f) > 1 then
                set f to text 1 thru -2 of f
            else
                set f to ""
            end if
        end repeat
        if f is not "" then
            if accName contains f then return true
            repeat with e in accEmails
                if (e as text) contains f then return true
            end repeat
        end if
    end repeat
    return false
end accountMatchesFilter

-- Search messages across all mailboxes with prefix support
-- Prefixes: from:, to:, subject:, body: (plain query searches all fields)
-- Three-phase approach: 1) subject+sender (fast), 2) recipients (to: only), 3) body content (slow)
on searchMessages(query, accountFilter)
    -- Parse query prefix
    set searchMode to "general"
    set searchTerm to query
    set queryLen to count of query

    if queryLen > 5 and query starts with "from:" then
        set searchMode to "from"
        set searchTerm to text 6 thru -1 of query
    else if queryLen > 3 and query starts with "to:" then
        set searchMode to "to"
        set searchTerm to text 4 thru -1 of query
    else if queryLen > 8 and query starts with "subject:" then
        set searchMode to "subject"
        set searchTerm to text 9 thru -1 of query
    else if queryLen > 5 and query starts with "body:" then
        set searchMode to "body"
        set searchTerm to text 6 thru -1 of query
    end if

    set output to {}
    set seenIds to {}
    set maxResults to 25

    tell application "Mail"
        with timeout of 15 seconds
            set allAccounts to accounts
        end timeout
    end tell

    -- Phase 1: Fast search via whose clause (subject/sender) across ALL mailboxes
    if searchMode is not "to" and searchMode is not "body" then
        tell application "Mail"
            with timeout of 30 seconds
            repeat with acc in allAccounts
                if (count of output) ≥ maxResults then exit repeat
                if my accountMatchesFilter(acc, accountFilter) then
                    repeat with mb in mailboxes of acc
                        if (count of output) ≥ maxResults then exit repeat
                        try
                            with timeout of 10 seconds
                                if searchMode is "from" then
                                    set foundMsgs to (messages of mb whose sender contains searchTerm)
                                else if searchMode is "subject" then
                                    set foundMsgs to (messages of mb whose subject contains searchTerm)
                                else
                                    set foundMsgs to (messages of mb whose subject contains searchTerm or sender contains searchTerm)
                                end if
                            end timeout
                            repeat with msg in foundMsgs
                                if (count of output) ≥ maxResults then exit repeat
                                set msgId to id of msg as text
                                if seenIds does not contain msgId then
                                    set end of seenIds to msgId
                                    set msgLine to msgId & " | " & (date sent of msg as text) & " | " & (sender of msg) & " | " & (subject of msg)
                                    set end of output to msgLine
                                end if
                            end repeat
                        end try
                    end repeat
                end if
            end repeat
            end timeout
        end tell
    end if

    -- Phase 2: Recipient search (to: prefix only, manual iteration)
    if searchMode is "to" then
        tell application "Mail"
            with timeout of 30 seconds
            repeat with acc in allAccounts
                if (count of output) ≥ maxResults then exit repeat
                if my accountMatchesFilter(acc, accountFilter) then
                    repeat with mb in mailboxes of acc
                        if (count of output) ≥ maxResults then exit repeat
                        try
                            set msgCount to count of messages of mb
                            if msgCount > 200 then set msgCount to 200
                            if msgCount > 0 then
                                with timeout of 10 seconds
                                    set msgs to messages 1 thru msgCount of mb
                                end timeout
                                repeat with msg in msgs
                                    if (count of output) ≥ maxResults then exit repeat
                                    try
                                        set matched to false
                                        repeat with recip in to recipients of msg
                                            try
                                                if (address of recip) contains searchTerm then set matched to true
                                            end try
                                            if not matched then
                                                try
                                                    if (name of recip) contains searchTerm then set matched to true
                                                end try
                                            end if
                                            if matched then exit repeat
                                        end repeat
                                        if matched then
                                            set msgId to id of msg as text
                                            if seenIds does not contain msgId then
                                                set end of seenIds to msgId
                                                set msgLine to msgId & " | " & (date sent of msg as text) & " | " & (sender of msg) & " | " & (subject of msg)
                                                set end of output to msgLine
                                            end if
                                        end if
                                    end try
                                end repeat
                            end if
                        end try
                    end repeat
                end if
            end repeat
            end timeout
        end tell
    end if

    -- Phase 3: Body content search (slow - only for body: prefix or general with no Phase 1 results)
    if searchMode is "body" or (searchMode is "general" and (count of output) is 0) then
        tell application "Mail"
            with timeout of 30 seconds
            repeat with acc in allAccounts
                if (count of output) ≥ maxResults then exit repeat
                if my accountMatchesFilter(acc, accountFilter) then
                    repeat with mb in mailboxes of acc
                        if (count of output) ≥ maxResults then exit repeat
                        try
                            with timeout of 15 seconds
                                set foundMsgs to (messages of mb whose content contains searchTerm)
                            end timeout
                            repeat with msg in foundMsgs
                                if (count of output) ≥ maxResults then exit repeat
                                set msgId to id of msg as text
                                if seenIds does not contain msgId then
                                    set end of seenIds to msgId
                                    set msgLine to msgId & " | " & (date sent of msg as text) & " | " & (sender of msg) & " | " & (subject of msg)
                                    set end of output to msgLine
                                end if
                            end repeat
                        end try
                    end repeat
                end if
            end repeat
            end timeout
        end tell
    end if

    if (count of output) is 0 then
        return "No messages found matching: " & query
    end if
    return my joinList(output, linefeed)
end searchMessages

-- Read a specific message
on readMessage(messageId)
    tell application "Mail"
        with timeout of 30 seconds
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
        end timeout
    end tell
end readMessage

-- Create a draft message and save it to the Drafts folder
-- When --from is specified, saves to that account's Drafts folder (not iCloud default)
on draftMessage(toAddr, subjectText, bodyText, senderAddr, ccAddr, bccAddr, attachmentPaths)
    tell application "Mail"
        with timeout of 30 seconds
            activate
            -- Create outgoing message with sender in initial properties so Mail routes to correct account
            if senderAddr is not "" then
                set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, sender:senderAddr, visible:true}
            else
                set newMessage to make new outgoing message with properties {subject:subjectText, content:bodyText, visible:true}
            end if
            tell newMessage
                -- Set To recipients (supports comma-separated list)
                set toList to my splitCommaList(toAddr)
                repeat with addr in toList
                    make new to recipient at end of to recipients with properties {address:addr}
                end repeat
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
        end timeout
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
        with timeout of 30 seconds
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
        end timeout
    end tell
end draftMessage

-- Create an HTML draft: compose window with recipients, then paste RTF from clipboard
-- Clipboard must already be loaded with RTF content before calling this
on htmlDraftMessage(toAddr, subjectText, senderAddr, ccAddr, bccAddr)
    tell application "Mail"
        with timeout of 30 seconds
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
        end timeout
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
        with timeout of 30 seconds
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
        end timeout
    end tell
end sendMessage

-- Delete a draft message by ID
on deleteDraft(messageId)
    tell application "Mail"
        with timeout of 30 seconds
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
        end timeout
    end tell
end deleteDraft

-- Reply-all to an existing message (saves as draft, preserves quoted thread)
on replyMessage(messageId, bodyText, senderAddr, ccAddr, bccAddr)
    tell application "Mail"
        with timeout of 30 seconds
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
                        -- We use clipboard paste because setting the content property
                        -- directly wipes the HTML-formatted quoted thread
                        set oldClipboard to the clipboard
                        set the clipboard to bodyText & linefeed & linefeed
                        tell application "Mail"
                            activate
                        end tell
                        delay 1
                        tell application "System Events"
                            tell process "Mail"
                                set frontmost to true
                                delay 0.5
                                keystroke "v" using command down
                            end tell
                        end tell
                        delay 1
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
        end timeout
    end tell
end replyMessage

-- Attach files to an existing draft message
-- Opens the draft as a compose window, adds attachments, and leaves open for review
on attachToDraft(messageId, filePaths)
    tell application "Mail"
        with timeout of 30 seconds
            activate
            -- Find the draft message across all accounts/mailboxes
            set foundMsg to missing value
            set foundSubj to ""
            set foundContent to ""
            set foundSender to ""
            set foundToAddrs to {}
            set foundCcAddrs to {}
            set foundBccAddrs to {}
            repeat with acc in accounts
                repeat with mb in mailboxes of acc
                    try
                        set msg to (first message of mb whose id is (messageId as integer))
                        set foundMsg to msg
                        set foundSubj to subject of msg
                        set foundContent to content of msg
                        set foundSender to sender of msg
                        -- Collect recipients
                        repeat with r in to recipients of msg
                            set end of foundToAddrs to address of r
                        end repeat
                        repeat with r in cc recipients of msg
                            set end of foundCcAddrs to address of r
                        end repeat
                        repeat with r in bcc recipients of msg
                            set end of foundBccAddrs to address of r
                        end repeat
                        exit repeat
                    end try
                end repeat
                if foundMsg is not missing value then exit repeat
            end repeat

            if foundMsg is missing value then
                return "Draft not found: " & messageId
            end if

            -- Create a new outgoing message with the same properties + attachments
            set newMessage to make new outgoing message with properties {subject:foundSubj, content:foundContent, sender:foundSender, visible:true}
            tell newMessage
                repeat with addr in foundToAddrs
                    make new to recipient at end of to recipients with properties {address:addr}
                end repeat
                repeat with addr in foundCcAddrs
                    make new cc recipient at end of cc recipients with properties {address:addr}
                end repeat
                repeat with addr in foundBccAddrs
                    make new bcc recipient at end of bcc recipients with properties {address:addr}
                end repeat
                -- Add the new attachments
                set attachCount to count of filePaths
                set attachedCount to 0
                repeat with filePath in filePaths
                    try
                        set attachFile to POSIX file (filePath as text) as alias
                        make new attachment with properties {file name:attachFile} at after the last paragraph
                        delay 1
                        set attachedCount to attachedCount + 1
                    end try
                end repeat
            end tell

            -- Wait for attachments to fully load
            if attachedCount > 0 then
                delay (attachedCount * 1 + 2)
            end if

            -- Delete the old draft
            delete foundMsg
        end timeout
    end tell

    -- Save with Cmd+S
    tell application "System Events"
        tell process "Mail"
            set frontmost to true
            delay 0.3
            keystroke "s" using command down
        end tell
    end tell
    delay 2

    -- Compose window left open for user to review and send
    return "OK: Attached " & attachedCount & " of " & attachCount & " file(s) — new draft created with attachments, old draft removed"
end attachToDraft

on listAttachments(messageId)
    tell application "Mail"
        with timeout of 30 seconds
            set foundMsg to missing value
            repeat with acc in accounts
                repeat with mb in mailboxes of acc
                    try
                        set msg to (first message of mb whose id is (messageId as integer))
                        set foundMsg to msg
                        exit repeat
                    end try
                end repeat
                if foundMsg is not missing value then exit repeat
            end repeat

            if foundMsg is missing value then
                return "Message not found: " & messageId
            end if

            set attList to mail attachments of foundMsg
            if (count of attList) is 0 then
                return "No attachments on message: " & subject of foundMsg
            end if

            set output to {}
            repeat with att in attList
                set attName to name of att
                set attSize to MIME type of att
                set end of output to attName & " (" & attSize & ")"
            end repeat
            return my joinList(output, linefeed)
        end timeout
    end tell
end listAttachments

-- Forward a message (saves as draft with forwarded content)
on forwardMessage(messageId, toAddr, bodyText, senderAddr, ccAddr, bccAddr, attachmentPaths)
    tell application "Mail"
        with timeout of 30 seconds
            -- Find the original message by ID
            repeat with acc in accounts
                repeat with mb in mailboxes of acc
                    try
                        set origMsg to (first message of mb whose id is messageId)
                        -- Use forward to create the forwarded message
                        set fwdMsg to forward origMsg with opening window
                        -- Set To recipients (supports comma-separated list)
                        set toList to my splitCommaList(toAddr)
                        tell fwdMsg
                            repeat with addr in toList
                                make new to recipient at end of to recipients with properties {address:addr}
                            end repeat
                        end tell
                        -- Set sender if specified
                        if senderAddr is not "" then
                            set sender of fwdMsg to senderAddr
                        end if
                        -- Add CC recipients (supports comma-separated list)
                        if ccAddr is not "" then
                            set ccList to my splitCommaList(ccAddr)
                            tell fwdMsg
                                repeat with addr in ccList
                                    make new cc recipient at end of cc recipients with properties {address:addr}
                                end repeat
                            end tell
                        end if
                        -- Add BCC recipients (supports comma-separated list)
                        if bccAddr is not "" then
                            set bccList to my splitCommaList(bccAddr)
                            tell fwdMsg
                                repeat with addr in bccList
                                    make new bcc recipient at end of bcc recipients with properties {address:addr}
                                end repeat
                            end tell
                        end if
                        -- Add attachments
                        tell fwdMsg
                            repeat with attachPath in attachmentPaths
                                set attachFile to POSIX file (attachPath as text) as alias
                                make new attachment with properties {file name:attachFile} at after the last paragraph
                                delay 1
                            end repeat
                        end tell
                        -- Wait for compose window to fully load with forwarded content
                        set attachCount to count of attachmentPaths
                        if attachCount > 0 then
                            delay (attachCount * 1 + 2)
                        else
                            delay 2
                        end if
                        -- Insert body text by typing line-by-line into the body area
                        if bodyText is not "" then
                            tell application "Mail"
                                activate
                            end tell
                            delay 0.5
                            -- Split body text by linefeeds
                            set {oldTID, AppleScript's text item delimiters} to {AppleScript's text item delimiters, linefeed}
                            set bodyLines to text items of bodyText
                            set AppleScript's text item delimiters to oldTID

                            tell application "System Events"
                                tell process "Mail"
                                    set frontmost to true
                                    delay 0.3
                                    -- Tab past header fields (To, CC, BCC, Subject) into body
                                    repeat 6 times
                                        keystroke tab
                                        delay 0.15
                                    end repeat
                                    delay 0.3
                                    -- Move cursor to the very top of the body
                                    key code 126 using {command down} -- Cmd+Up to go to top
                                    delay 0.3
                                    -- Type each line with Return between them
                                    repeat with i from 1 to count of bodyLines
                                        set thisLine to item i of bodyLines
                                        if thisLine is not "" then
                                            keystroke thisLine
                                        end if
                                        if i < (count of bodyLines) then
                                            key code 36 -- Return
                                        end if
                                    end repeat
                                    -- Add two trailing returns to separate from forwarded content
                                    key code 36
                                    key code 36
                                end tell
                            end tell
                            delay 0.5
                        end if
                        -- Build status message
                        set extras to ""
                        if ccAddr is not "" then
                            set extras to extras & " cc:" & ccAddr
                        end if
                        if bccAddr is not "" then
                            set extras to extras & " bcc:" & bccAddr
                        end if
                        if attachCount > 0 then
                            set extras to extras & " (" & attachCount & " attachments)"
                        end if
                        return "OK: Forward draft opened (to " & toAddr & ", fwd: " & subject of origMsg & ")" & extras
                    end try
                end repeat
            end repeat
            return "Message not found: " & messageId
        end timeout
    end tell
end forwardMessage

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
