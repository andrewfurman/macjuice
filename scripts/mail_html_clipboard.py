#!/usr/bin/env python3
"""Load HTML content onto the macOS clipboard as RTF for pasting into Mail.app.

Usage:
    python3 mail_html_clipboard.py <html_file_or_string>

If the argument is a file path that exists, reads from that file.
Otherwise, treats the argument as raw HTML string.
"""
import sys
from AppKit import (
    NSPasteboard,
    NSData,
    NSAttributedString,
    NSRTFTextDocumentType,
    NSDocumentTypeDocumentAttribute,
)


def main():
    if len(sys.argv) < 2:
        print("Usage: mail_html_clipboard.py <html_file_or_string>", file=sys.stderr)
        sys.exit(1)

    html_input = sys.argv[1]

    # Check if it's a file path
    import os
    if os.path.isfile(html_input):
        with open(html_input, "r", encoding="utf-8") as f:
            html = f.read()
    else:
        html = html_input

    # Convert HTML to NSAttributedString
    html_data = html.encode("utf-8")
    ns_data = NSData.dataWithBytes_length_(html_data, len(html_data))
    result = NSAttributedString.alloc().initWithHTML_documentAttributes_(ns_data, None)

    if result is None:
        print("Error: Failed to parse HTML content", file=sys.stderr)
        sys.exit(1)

    attr_str = result[0]

    # Convert to RTF
    rtf_data = attr_str.RTFFromRange_documentAttributes_(
        (0, attr_str.length()),
        {NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType},
    )

    if rtf_data is None:
        print("Error: Failed to convert to RTF", file=sys.stderr)
        sys.exit(1)

    # Put on clipboard
    pb = NSPasteboard.generalPasteboard()
    pb.clearContents()
    pb.setData_forType_(rtf_data, "public.rtf")

    print("OK: HTML loaded to clipboard as RTF")


if __name__ == "__main__":
    main()
