-- messages.applescript
-- Apple Messages (iMessage/SMS) integration for apple-cli

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript messages.applescript <command> [args...]"
    end if

    set cmd to item 1 of argv

    if cmd is "chats" then
        return listChats()
    else if cmd is "send" then
        if (count of argv) > 2 then
            return sendMessage(item 2 of argv, item 3 of argv)
        else
            return "Usage: messages.applescript send <recipient> <message>"
        end if
    else if cmd is "read" then
        if (count of argv) > 1 then
            set msgCount to 10
            if (count of argv) > 2 then set msgCount to (item 3 of argv) as integer
            return readChat(item 2 of argv, msgCount)
        else
            return "Usage: messages.applescript read <chat-name> [count]"
        end if
    else if cmd is "recent" then
        set msgCount to 20
        if (count of argv) > 1 then set msgCount to (item 2 of argv) as integer
        return recentMessages(msgCount)
    else if cmd is "search" then
        if (count of argv) > 1 then
            return searchMessages(item 2 of argv)
        else
            return "Usage: messages.applescript search <query>"
        end if
    else if cmd is "unread" then
        return unreadCount()
    else
        return "Unknown command: " & cmd
    end if
end run

-- List all chats
on listChats()
    tell application "Messages"
        set output to {}
        set maxChats to 50
        set allChats to every chat

        repeat with i from 1 to (count of allChats)
            if i > maxChats then exit repeat
            set c to item i of allChats

            set chatName to name of c
            set chatId to id of c

            -- Get participant info if no name
            if chatName is missing value then
                try
                    set chatParticipants to participants of c
                    if (count of chatParticipants) > 0 then
                        set participantNames to {}
                        repeat with p in chatParticipants
                            set end of participantNames to (name of p)
                        end repeat
                        set chatName to my joinList(participantNames, ", ")
                    else
                        set chatName to chatId
                    end if
                on error
                    set chatName to chatId
                end try
            end if

            set chatInfo to chatName
            set end of output to chatInfo
        end repeat

        if (count of output) is 0 then
            return "No chats found"
        end if
    end tell
    return my joinList(output, linefeed)
end listChats

-- Send a message
on sendMessage(recipient, messageText)
    tell application "Messages"
        -- Try to find existing chat first
        set targetChat to missing value

        -- Check if recipient is a phone number or email
        if recipient starts with "+" or recipient starts with "1" or (recipient does not contain "@" and recipient does not contain " ") then
            -- Looks like a phone number, try to send via service
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant recipient of targetService
            send messageText to targetBuddy
            return "OK: Sent to " & recipient
        else
            -- Recipient looks like a name — try contact lookup first
            try
                tell application "Contacts"
                    set matchedPeople to (every person whose name contains recipient)
                    set matchCount to count of matchedPeople
                    if matchCount > 1 then
                        -- Multiple contacts found — show details so user can pick
                        set detailLines to {"ERROR: Multiple contacts match \"" & recipient & "\". Please specify which one by using their phone number directly:" & linefeed}
                        repeat with i from 1 to matchCount
                            set p to item i of matchedPeople
                            set personInfo to (i as text) & ") " & (name of p)

                            -- Get address
                            try
                                if (count of addresses of p) > 0 then
                                    set addr to item 1 of addresses of p
                                    set addrParts to {}
                                    try
                                        if street of addr is not missing value then set end of addrParts to street of addr
                                    end try
                                    try
                                        if city of addr is not missing value then set end of addrParts to city of addr
                                    end try
                                    try
                                        if state of addr is not missing value then set end of addrParts to state of addr
                                    end try
                                    try
                                        if zip of addr is not missing value then set end of addrParts to zip of addr
                                    end try
                                    if (count of addrParts) > 0 then
                                        set personInfo to personInfo & linefeed & "   Address: " & my joinList(addrParts, ", ")
                                    end if
                                end if
                            end try

                            -- Get email
                            try
                                if (count of emails of p) > 0 then
                                    set personInfo to personInfo & linefeed & "   Email: " & (value of item 1 of emails of p)
                                end if
                            end try

                            -- Get phone(s)
                            try
                                if (count of phones of p) > 0 then
                                    set phoneList to {}
                                    repeat with ph in phones of p
                                        set phoneLabel to label of ph
                                        if phoneLabel is "_$!<Mobile>!$_" then set phoneLabel to "mobile"
                                        if phoneLabel is "_$!<Home>!$_" then set phoneLabel to "home"
                                        if phoneLabel is "_$!<Work>!$_" then set phoneLabel to "work"
                                        set end of phoneList to (value of ph) & " (" & phoneLabel & ")"
                                    end repeat
                                    set personInfo to personInfo & linefeed & "   Phone: " & my joinList(phoneList, ", ")
                                end if
                            end try

                            set end of detailLines to personInfo
                        end repeat
                        return my joinList(detailLines, linefeed)
                    else if matchCount is 1 then
                        set p to item 1 of matchedPeople
                        -- Prefer mobile phone, fall back to any phone
                        set phoneNumber to missing value
                        repeat with ph in phones of p
                            set phoneNumber to value of ph
                            if label of ph is "mobile" or label of ph is "_$!<Mobile>!$_" then
                                exit repeat
                            end if
                        end repeat
                        if phoneNumber is not missing value then
                            -- Send to the looked-up phone number
                            tell application "Messages"
                                set targetService to 1st account whose service type = iMessage
                                set targetBuddy to participant phoneNumber of targetService
                                send messageText to targetBuddy
                            end tell
                            return "OK: Sent to " & (name of p) & " (" & phoneNumber & ")"
                        end if
                    end if
                end tell
            end try

            -- Fall through: search existing chats (original logic)
            tell application "Messages"
                repeat with c in chats
                    set chatName to name of c
                    if chatName is not missing value and chatName contains recipient then
                        set targetChat to c
                        exit repeat
                    end if

                    -- Also check participant names
                    repeat with p in participants of c
                        if (name of p) contains recipient then
                            set targetChat to c
                            exit repeat
                        end if
                    end repeat

                    if targetChat is not missing value then exit repeat
                end repeat

                if targetChat is not missing value then
                    send messageText to targetChat
                    return "OK: Sent to " & recipient
                else
                    return "ERROR: Could not find chat for: " & recipient & linefeed & "Tip: Use phone number with country code (e.g., +15551234567)"
                end if
            end tell
        end if
end sendMessage

-- Read messages from a specific chat
on readChat(chatIdentifier, msgCount)
    tell application "Messages"
        set targetChat to missing value

        -- Find chat by name or participant
        repeat with c in chats
            set chatName to name of c
            if chatName is not missing value and chatName contains chatIdentifier then
                set targetChat to c
                exit repeat
            end if

            -- Check participant names
            repeat with p in participants of c
                if (name of p) contains chatIdentifier then
                    set targetChat to c
                    exit repeat
                end if
            end repeat

            if targetChat is not missing value then exit repeat
        end repeat

        if targetChat is missing value then
            return "Chat not found: " & chatIdentifier
        end if

        set output to {}
        set chatMessages to messages of targetChat

        -- Get last N messages
        set totalMsgs to count of chatMessages
        set startIdx to totalMsgs - msgCount + 1
        if startIdx < 1 then set startIdx to 1

        repeat with i from startIdx to totalMsgs
            set msg to item i of chatMessages
            set msgDate to date sent of msg
            set msgSender to sender of msg
            set msgText to text of msg

            -- Format sender
            set senderName to "Unknown"
            if msgSender is not missing value then
                set senderName to name of msgSender
                if senderName is missing value then
                    set senderName to handle of msgSender
                end if
            end if

            -- Format date (just time if today)
            set dateStr to (msgDate as text)

            set msgLine to "[" & dateStr & "] " & senderName & ": " & msgText
            set end of output to msgLine
        end repeat

        if (count of output) is 0 then
            return "No messages in chat: " & chatIdentifier
        end if
    end tell
    return my joinList(output, linefeed)
end readChat

-- Get recent messages across all chats
on recentMessages(msgCount)
    tell application "Messages"
        set output to {}
        set collected to 0

        repeat with c in chats
            if collected ≥ msgCount then exit repeat
            try
                set chatName to name of c
                if chatName is missing value then
                    set chatParticipants to participants of c
                    if (count of chatParticipants) > 0 then
                        set chatName to name of item 1 of chatParticipants
                    else
                        set chatName to "Unknown"
                    end if
                end if

                set chatMessages to messages of c
                set msgTotal to count of chatMessages
                if msgTotal > 0 then
                    -- Get last message from this chat
                    set msg to item msgTotal of chatMessages
                    set msgDate to date sent of msg
                    set msgText to text of msg

                    -- Truncate long messages
                    if (length of msgText) > 50 then
                        set msgText to (text 1 thru 50 of msgText) & "..."
                    end if

                    set msgLine to chatName & " | " & (msgDate as text) & " | " & msgText
                    set end of output to msgLine
                    set collected to collected + 1
                end if
            end try
        end repeat
    end tell
    return my joinList(output, linefeed)
end recentMessages

-- Search messages
on searchMessages(query)
    tell application "Messages"
        set output to {}
        set maxResults to 20

        repeat with c in chats
            if (count of output) ≥ maxResults then exit repeat

            set chatName to name of c
            if chatName is missing value then set chatName to "Unknown"

            repeat with msg in messages of c
                if (count of output) ≥ maxResults then exit repeat

                set msgText to text of msg
                if msgText contains query then
                    set msgDate to date sent of msg
                    set msgLine to chatName & " | " & (msgDate as text) & " | " & msgText
                    set end of output to msgLine
                end if
            end repeat
        end repeat

        if (count of output) is 0 then
            return "No messages found matching: " & query
        end if
    end tell
    return my joinList(output, linefeed)
end searchMessages

-- Get unread count (approximation - Messages doesn't expose this well)
on unreadCount()
    tell application "System Events"
        tell process "Messages"
            -- Try to get badge count from Dock
            try
                set dockBadge to value of attribute "AXStatusLabel" of application process "Messages"
                if dockBadge is not "" and dockBadge is not missing value then
                    return "Unread: " & dockBadge
                end if
            end try
        end tell
    end tell
    return "Unread: Unable to determine (check Messages app)"
end unreadCount

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList
