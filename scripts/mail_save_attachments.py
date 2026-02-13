#!/usr/bin/env python3
"""Save attachments from an Apple Mail message to a directory.

Uses AppleScript to get the raw MIME source, then Python's email module
to parse and extract attachments. This two-step approach is needed because
Apple Mail's AppleScript `save` command doesn't work on individual
mail attachment objects.

Usage: python3 mail_save_attachments.py <message-id> <save-directory>
"""

import email
import os
import subprocess
import sys
import tempfile


def get_message_source(message_id: str) -> str:
    """Use AppleScript to get the raw MIME source of a message."""
    # Create a temp file for the source (can be multi-MB)
    tmp = tempfile.NamedTemporaryFile(suffix=".eml", delete=False)
    tmp_path = tmp.name
    tmp.close()

    script = f'''
set msgSrc to ""
tell application "Mail"
    repeat with acc in accounts
        repeat with mb in mailboxes of acc
            try
                set msg to (first message of mb whose id is {message_id})
                set msgSrc to source of msg
                exit repeat
            end try
        end repeat
        if msgSrc is not "" then exit repeat
    end repeat
end tell

if msgSrc is "" then
    return "ERROR:Message not found: {message_id}"
end if

set tmpPath to POSIX file "{tmp_path}"
try
    set fh to open for access tmpPath with write permission
    set eof of fh to 0
    write msgSrc to fh
    close access fh
    return "OK:" & "{tmp_path}"
on error errMsg
    try
        close access fh
    end try
    return "ERROR:" & errMsg
end try
'''
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True, text=True, timeout=120
    )
    output = result.stdout.strip()
    if output.startswith("ERROR:"):
        print(output[6:], file=sys.stderr)
        os.unlink(tmp_path)
        sys.exit(1)
    return tmp_path


def extract_attachments(eml_path: str, save_dir: str) -> list[str]:
    """Parse MIME source and save all attachments."""
    os.makedirs(save_dir, exist_ok=True)

    with open(eml_path, "rb") as f:
        msg = email.message_from_binary_file(f)

    saved = []
    for part in msg.walk():
        filename = part.get_filename()
        if filename:
            data = part.get_payload(decode=True)
            if data:
                path = os.path.join(save_dir, filename)
                with open(path, "wb") as out:
                    out.write(data)
                saved.append((filename, len(data), path))
    return saved


def main():
    if len(sys.argv) < 3:
        print("Usage: mail_save_attachments.py <message-id> <save-directory>")
        sys.exit(1)

    message_id = sys.argv[1]
    save_dir = sys.argv[2]

    eml_path = get_message_source(message_id)
    try:
        saved = extract_attachments(eml_path, save_dir)
        if not saved:
            print("No attachments found on message")
        else:
            for filename, size, path in saved:
                print(f"{filename} ({size} bytes) → {path}")
            print(f"\nTotal: {len(saved)} attachments saved to {save_dir}")
    finally:
        os.unlink(eml_path)


if __name__ == "__main__":
    main()
