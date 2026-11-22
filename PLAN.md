# Sticky Note — version 0.1

## Agreed behavior

1. Launch by typing “Sticky Note” in Spotlight. A small editor appears over the current app and follows the user across Spaces and full-screen apps while writing.
2. Use classic yellow paper, plain text, and checkboxes.
3. Save locally and place individual notes behind app windows on the desktop.
4. Keep notes on one Space and the primary display.
5. Remove notes only with an explicit delete button.
6. Let the user copy durable information into Obsidian.
7. Add a global capture shortcut later only if it becomes useful.

## Implementation

Use Swift Package Manager and AppKit with no third-party libraries. Build an application bundle using the existing Command Line Tools. Install under the user's Applications folder, with no system-wide installation.

Each desktop note is a borderless paper window at a desktop window level. Stationary window collection behavior keeps it out of ordinary Mission Control movement. All note windows attach to a single desktop anchor. A separate floating editor joins all Spaces, including full-screen apps, without taking the saved desktop notes with it.

Save note IDs, bodies, and positions in one versioned JSON document using atomic replacement. Preserve unreadable files and surface errors rather than initializing over existing data. Store positions relative to the primary display and clamp them when screens change.

Handle application reopen events to make Spotlight launch a new capture while the app is already running. Use a menu-bar status item for new notes, accessing existing notes, moving the notes' desktop, and quitting.

## Validation priorities

- Persistence and deletion must survive relaunches.
- The native Show Desktop gesture/shortcut must leave the notes visible.
- Notes must not appear over ordinary windows or on every Space.
- New capture from a different Space must not move existing notes.
- The editor must accept text immediately and return focus when finished.
- A failed save must not silently dismiss or discard typed text.
- Main-display changes must not leave notes offscreen.

## Known platform boundary

Restoring a specific Space number after the app quits is not supported by public macOS APIs. The app anchors to the primary display's current Space on startup. A menu command deliberately moves all notes to a different current Space. Multi-monitor reconnection also needs testing on physical work displays.

## Later, only if needed

Configurable global capture shortcut, launch at login, additional paper colors, and improved placement when many notes accumulate. Rich text, sync, folders, reminders, and Obsidian integration are outside version 0.1.
