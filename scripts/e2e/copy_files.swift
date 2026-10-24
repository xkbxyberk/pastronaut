// Puts files on the clipboard the way Finder copies a selection: one pasteboard item per file.
// Usage: swift copy_files.swift <path>...  (scripts/e2e/sync_e2e.py, 1.3)
import AppKit

let urls = CommandLine.arguments.dropFirst().map { URL(fileURLWithPath: $0) as NSURL }
let pasteboard = NSPasteboard.general
pasteboard.clearContents()
guard pasteboard.writeObjects(Array(urls)) else { exit(1) }
print(pasteboard.pasteboardItems?.count ?? 0)
