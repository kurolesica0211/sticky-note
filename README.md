# Sticky Note

A small native macOS app for the thoughts that belong on a paper sticky.

Open **Sticky Note** from Spotlight, write in a small editor over your current app, and place the note on your desktop. Notes stay below regular app windows. Everything is saved on your Mac.

## Features

- Classic yellow paper with a quiet menu-bar icon.
- The open editor follows you across desktop Spaces and full-screen apps. You can switch the app underneath it while writing; saved stickers remain on their chosen desktop.
- Text with **bold** (**Command–B**), *italic* (**Command–I**), and clickable checkboxes. Use the Checkbox button or **Shift–Command–L**. Return continues a checklist; Return on an empty checkbox ends it.
- **Command–Return** or **Escape** places the note on the desktop and returns to the previous app.
- Click the note text or pencil to edit it. Drag the top strip to move it. Drag any edge or corner to resize the editor or a desktop sticker; its size is saved.
- An explicit trash button deletes a note immediately. Closing the editor, switching apps, or quitting does not delete notes.
- Launch **Delete Sticky Note** from Spotlight for a searchable list of current notes. Type to filter, use **↑/↓** to select, **Command–Delete** to remove the selection, and **Escape** to close. This is a companion app launcher that opens a native picker; the list does not appear inside Spotlight itself. You can also open it from the menu or **Shift–Command–D** while Sticky Note is active.
- Autosave, saved positions, and restoration when the app next opens.
- Notes on the primary display and one desktop Space. A menu command moves all notes to the current desktop.
- No accounts, network calls, sync, runtime dependencies, or global keyboard shortcut.

## Download and install

Download the universal DMG or ZIP from [GitHub Releases](https://github.com/kurolesica0211/sticky-note/releases/latest). It runs on **macOS 14 or later**, on **Apple silicon and Intel**. Copy both **Sticky Note.app** and **Delete Sticky Note.app** into Applications, keeping them in the same folder. Quit any running older copy before replacing it. No developer tools are needed, and existing local notes are retained.

The release is ad-hoc signed and **not notarized**, because it is built without a paid Apple Developer signing identity. If macOS blocks an app after your first attempt to open it, use **System Settings → Privacy & Security → Open Anyway** for your trusted download. You may need to do this for each launcher. [Apple's instructions](https://support.apple.com/en-us/102445) explain the first-open process.

Open each app once from Applications if Spotlight indexing is delayed. Then use Spotlight to launch **Sticky Note** or **Delete Sticky Note**.

## Build from source

Requires macOS 14 or later and Apple's Swift Command Line Tools. Full Xcode is not required.

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/install.sh
```

The build produces both apps in `dist/`. The installer copies them to `~/Applications` and registers them with Launch Services and Spotlight. After installation, open Spotlight, type **Sticky Note**, and press Return.

Launching the app again creates a new note. If an editor is already open, its text is saved and placed first. New drafts that were never given text are discarded. A note that once contained text remains until explicitly deleted, even if later emptied.

`./scripts/build.sh --universal` builds both architectures. `./scripts/release.sh` builds the universal apps and creates the DMG, ZIP, and `SHA256SUMS.txt` in `dist/`. Packaging uses only tools included with macOS and the Swift Command Line Tools.

## Desktop behavior

Notes attach to the Space active on the primary display when the app starts. They do not follow you to every Space. To change their desktop, use **Move Notes to This Desktop** in the menu bar.

macOS does not provide a public API for storing and restoring a particular numbered Space across relaunches. After quitting or restarting your Mac, launch Sticky Note on the intended desktop. This version does not enable automatic launch at login.

Saved positions are relative to the primary display's usable area. They are clamped back on screen when the display arrangement changes. Secondary displays are not note destinations in this version.

## Local data

`~/Library/Application Support/StickyNote/notes.json` stores note text, RTF formatting, and placement. The menu has an **Open Notes Data Folder** action. Notes are written atomically; unreadable or newer-format files are not silently replaced. The app remains open and reports failed saves. Version 0.2 reads existing version 0.1 notes and saves format 2; version 0.1 cannot read the new format.

To transfer notes manually, quit the app on both Macs and copy that file into the same folder on the other Mac. Installing the app alone does not transfer your notes.

Checkboxes are stored as ordinary Unicode text (`☐` and `☑`); pasted `- [ ]` and `- [x]` lines also work. Copy text into Obsidian whenever a note becomes worth keeping.

For development with isolated data, launch the executable with `--data-directory /path/to/test-data`. `--restore-only` restores saved cards without opening a new editor on startup.

## Project layout

- `Sources/NoteCore`: notes, checkboxes, geometry, and JSON persistence.
- `Sources/StickyNote`: AppKit app lifecycle, capture editor, and desktop paper windows.
- `Sources/DeleteStickyNote`: a lightweight Spotlight launcher for the delete picker.
- `Tests/NoteCoreTests`: executable checks that work with Command Line Tools alone.
- `scripts`: app packaging, original programmatic icon, tests, and per-user installation.
- `PLAN.md`: agreed scope, implementation choices, and validation checklist.

## Validation

The executable checks cover Unicode and formatting round trips, version 0.1 migration, explicit deletion, corrupt-file preservation, unknown data formats, display changes, edge resizing and size limits, bold/italic selection and typing, checklist styling, invalid RTF fallback, and editor layout. AppKit checks use an isolated build and do not access saved user notes.

Before publishing a new version, also check: Spotlight launch and reopen; typing and checkbox continuation; editor dismissal and focus return; desktop checkbox clicks; Show Desktop; dragging and resizing; Space isolation; relaunch persistence; and multi-monitor reconnect behavior.
