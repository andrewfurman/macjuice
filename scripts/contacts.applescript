-- contacts.applescript
-- Apple Contacts integration for apple-cli

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript contacts.applescript <command> [args...]"
    end if

    set cmd to item 1 of argv

    if cmd is "list" then
        return listContacts()
    else if cmd is "search" then
        if (count of argv) > 1 then
            return searchContacts(item 2 of argv)
        else
            return "Usage: contacts.applescript search <query>"
        end if
    else if cmd is "show" then
        if (count of argv) > 1 then
            return showContact(item 2 of argv)
        else
            return "Usage: contacts.applescript show <name>"
        end if
    else if cmd is "groups" then
        return listGroups()
    else if cmd is "add" then
        -- add <first> <last> <email> <phone>
        if (count of argv) > 2 then
            set firstName to item 2 of argv
            set lastName to item 3 of argv
            set emailAddr to ""
            set phoneNum to ""
            if (count of argv) > 3 then set emailAddr to item 4 of argv
            if (count of argv) > 4 then set phoneNum to item 5 of argv
            return addContact(firstName, lastName, emailAddr, phoneNum)
        else
            return "Usage: contacts.applescript add <first> <last> [email] [phone]"
        end if
    else if cmd is "email" then
        if (count of argv) > 1 then
            return getEmail(item 2 of argv)
        else
            return "Usage: contacts.applescript email <name>"
        end if
    else if cmd is "phone" then
        if (count of argv) > 1 then
            return getPhone(item 2 of argv)
        else
            return "Usage: contacts.applescript phone <name>"
        end if
    else
        return "Unknown command: " & cmd
    end if
end run

-- List all contacts (limited)
on listContacts()
    tell application "Contacts"
        set output to {}
        set maxContacts to 50
        set allPeople to people

        repeat with i from 1 to (count of allPeople)
            if i > maxContacts then exit repeat
            set p to item i of allPeople
            set contactName to name of p
            set end of output to contactName
        end repeat
    end tell
    return my joinList(output, linefeed)
end listContacts

-- Search contacts by name
on searchContacts(query)
    tell application "Contacts"
        set output to {}
        set maxResults to 30
        set foundPeople to (every person whose name contains query)

        repeat with p in foundPeople
            if (count of output) ≥ maxResults then exit repeat
            set contactInfo to name of p

            -- Add primary email if available
            if (count of emails of p) > 0 then
                set contactInfo to contactInfo & " <" & (value of item 1 of emails of p) & ">"
            end if

            -- Add primary phone if available
            if (count of phones of p) > 0 then
                set contactInfo to contactInfo & " " & (value of item 1 of phones of p)
            end if

            set end of output to contactInfo
        end repeat

        if (count of output) is 0 then
            return "No contacts found matching: " & query
        end if
    end tell
    return my joinList(output, linefeed)
end searchContacts

-- Show detailed contact info
on showContact(contactName)
    tell application "Contacts"
        try
            set p to first person whose name is contactName
        on error
            -- Try partial match
            set matchingPeople to (every person whose name contains contactName)
            if (count of matchingPeople) is 0 then
                return "Contact not found: " & contactName
            end if
            set p to item 1 of matchingPeople
        end try

        set output to "Name: " & (name of p) & linefeed

        -- Company
        if organization of p is not missing value then
            set output to output & "Company: " & (organization of p) & linefeed
        end if

        -- Job title
        if job title of p is not missing value then
            set output to output & "Title: " & (job title of p) & linefeed
        end if

        -- Emails
        if (count of emails of p) > 0 then
            set output to output & linefeed & "Emails:" & linefeed
            repeat with e in emails of p
                set output to output & "  " & (label of e) & ": " & (value of e) & linefeed
            end repeat
        end if

        -- Phones
        if (count of phones of p) > 0 then
            set output to output & linefeed & "Phones:" & linefeed
            repeat with ph in phones of p
                set output to output & "  " & (label of ph) & ": " & (value of ph) & linefeed
            end repeat
        end if

        -- Addresses
        if (count of addresses of p) > 0 then
            set output to output & linefeed & "Addresses:" & linefeed
            repeat with addr in addresses of p
                set addrStr to ""
                if street of addr is not missing value then set addrStr to addrStr & (street of addr) & ", "
                if city of addr is not missing value then set addrStr to addrStr & (city of addr) & ", "
                if state of addr is not missing value then set addrStr to addrStr & (state of addr) & " "
                if zip of addr is not missing value then set addrStr to addrStr & (zip of addr)
                set output to output & "  " & (label of addr) & ": " & addrStr & linefeed
            end repeat
        end if

        -- Birthday
        if birth date of p is not missing value then
            set output to output & linefeed & "Birthday: " & (birth date of p as text) & linefeed
        end if

        -- Notes
        if note of p is not missing value and note of p is not "" then
            set output to output & linefeed & "Notes: " & (note of p) & linefeed
        end if

        return output
    end tell
end showContact

-- List all groups
on listGroups()
    tell application "Contacts"
        set output to {}
        repeat with g in groups
            set groupInfo to (name of g) & " (" & (count of people of g) & " contacts)"
            set end of output to groupInfo
        end repeat

        if (count of output) is 0 then
            return "No groups found"
        end if
    end tell
    return my joinList(output, linefeed)
end listGroups

-- Add a new contact
on addContact(firstName, lastName, emailAddr, phoneNum)
    tell application "Contacts"
        set newPerson to make new person with properties {first name:firstName, last name:lastName}

        if emailAddr is not "" then
            make new email at end of emails of newPerson with properties {label:"work", value:emailAddr}
        end if

        if phoneNum is not "" then
            make new phone at end of phones of newPerson with properties {label:"mobile", value:phoneNum}
        end if

        save
        return "OK: Created contact " & firstName & " " & lastName
    end tell
end addContact

-- Get email for a contact (useful for piping)
on getEmail(contactName)
    tell application "Contacts"
        try
            set p to first person whose name contains contactName
            if (count of emails of p) > 0 then
                return value of item 1 of emails of p
            else
                return "No email found for: " & contactName
            end if
        on error
            return "Contact not found: " & contactName
        end try
    end tell
end getEmail

-- Get phone for a contact (useful for piping)
on getPhone(contactName)
    tell application "Contacts"
        try
            set p to first person whose name contains contactName
            if (count of phones of p) > 0 then
                return value of item 1 of phones of p
            else
                return "No phone found for: " & contactName
            end if
        on error
            return "Contact not found: " & contactName
        end try
    end tell
end getPhone

-- Helper: Join list with delimiter
on joinList(theList, delimiter)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiter
    set theString to theList as text
    set AppleScript's text item delimiters to oldDelimiters
    return theString
end joinList
