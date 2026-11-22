# Sticky Note

A small native macOS app for the thoughts that belong on a paper sticky.

Open **Sticky Note** from Spotlight, write in a small editor over your current app, and place the note on your desktop. Notes stay below regular app windows. Everything is saved on your Mac.

## First version

- Classic yellow paper with a quiet menu-bar icon.
- Plain text and clickable checkboxes. Use the Checkbox button or **Shift–Command–L**. Return continues a checklist; Return on an empty checkbox ends it.
- **Command–Return** or **Escape** places the note on the desktop and returns to the previous app.
- Click the note text or pencil to edit it. Drag the top strip to move it. Drag the folded bottom-right corner to resize it.
- An explicit trash button deletes a note immediately. Closing the editor, switching apps, or quitting does not delete notes.
- Autosave, saved positions, and restoration when the app next opens.
- Notes on the primary display and one desktop Space. A menu command moves all notes to the current desktop.
- No accounts, network calls, sync, runtime dependencies, or global keyboard shortcut.

## Build and install

Requires macOS 14 or later and Apple's Swift Command Line Tools. Full Xcode is not required.

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/install.sh
```

The build produces `dist/Sticky Note.app`. The installer copies it to `~/Applications/Sticky Note.app` and registers it with Launch Services and Spotlight. After installation, open Spotlight, type **Sticky Note**, and press Return. If indexing is delayed, open the app once from `~/Applications`.

Launching the app again creates a new note. If an editor is already open, its text is saved and placed first. New drafts that were never given text are discarded. A note that once contained text remains until explicitly deleted, even if later emptied.

The app is signed locally with an ad-hoc signature. A paid Apple Developer account is not needed for this local build. It is not a notarized download distribution.

## Desktop behavior

Notes attach to the Space active on the primary display when the app starts. They do not follow you to every Space. To change their desktop, use **Move Notes to This Desktop** in the menu bar.

macOS does not provide a public API for storing and restoring a particular numbered Space across relaunches. After quitting or restarting your Mac, launch Sticky Note on the intended desktop. This version does not enable automatic launch at login.

Saved positions are relative to the primary display's usable area. They are clamped back on screen when the display arrangement changes. Secondary displays are not note destinations in this version.

## Local data

`~/Library/Application Support/StickyNote/notes.json` stores note text and placement. The menu has an **Open Notes Data Folder** action. Notes are written atomically; unreadable or newer-format files are not silently replaced. The app remains open and reports failed saves.

Checkboxes are stored as ordinary Unicode text (`☐` and `☑`); pasted `- [ ]` and `- [x]` lines also work. Copy text into Obsidian whenever a note becomes worth keeping.

For development with isolated data, launch the executable with `--data-directory /path/to/test-data`. `--restore-only` restores saved cards without opening a new editor on startup.

## Project layout

- `Sources/NoteCore`: notes, checkboxes, geometry, and JSON persistence.
- `Sources/StickyNote`: AppKit app lifecycle, capture editor, and desktop paper windows.
- `Tests/NoteCoreTests`: executable checks that work with Command Line Tools alone.
- `scripts`: app packaging, original programmatic icon, tests, and per-user installation.
- `PLAN.md`: agreed scope, implementation choices, and validation checklist.

## Validation

The executable test suite checks Unicode round trips, explicit deletion, corrupt-file preservation, unknown data formats, display changes, invalid geometry, and checkbox toggling.

Before publishing a new version, also check: Spotlight launch and reopen; typing and checkbox continuation; editor dismissal and focus return; desktop checkbox clicks; Show Desktop; dragging and resizing; Space isolation; relaunch persistence; and multi-monitor reconnect behavior.
