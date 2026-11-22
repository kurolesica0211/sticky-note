import AppKit
import NoteCore

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var notes: [Note] = []
    private var store: NoteStore!
    private var cards: [UUID: DesktopController] = [:]
    private var anchor: NSWindow?
    private var editor: EditorController?
    private var draft: Note?
    private var statusItem: NSStatusItem!
    private var previousApp: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
    private var saveError: Error?
    private var loaded = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let arguments = ProcessInfo.processInfo.arguments
        let directory: URL
        if let index = arguments.firstIndex(of: "--data-directory"), index + 1 < arguments.count {
            directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("StickyNote", isDirectory: true)
        }
        store = NoteStore(directory: directory)
        do { notes = try store.load(); loaded = true }
        catch {
            showError("Your notes couldn’t be opened", error: error,
                      detail: "The existing file has not been changed. Your notes are at \(store.fileURL.path).")
            NSApp.terminate(nil)
            return
        }
        previousApp = NSWorkspace.shared.frontmostApplication
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.bundleIdentifier != "com.apple.Spotlight" else { return }
            self?.previousApp = app
        }
        buildMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Sticky Note")
        statusItem.button?.toolTip = "Sticky Note"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        makeDesktop()
        if !arguments.contains("--restore-only") { newNote() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard loaded else { return false }
        newNote()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard loaded else { return .terminateNow }
        if persist() { return .terminateNow }
        showSaveError()
        return .terminateCancel
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        guard let screen = DesktopGeometry.screen else { return }
        anchor?.setFrameOrigin(screen.visibleFrame.origin)
        for index in notes.indices {
            notes[index].placement = notes[index].placement.clamped(toWidth: screen.visibleFrame.width, height: screen.visibleFrame.height)
            cards[notes[index].id]?.place(notes[index].placement, on: screen)
        }
        _ = persist()
    }

    private func makeDesktop() {
        guard let screen = DesktopGeometry.screen else { return }
        let window = DesktopWindow(contentRect: NSRect(origin: screen.visibleFrame.origin, size: NSSize(width: 1, height: 1)),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.alphaValue = 0
        window.setAccessibilityElement(false)
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = DesktopGeometry.level
        window.collectionBehavior = [.stationary, .ignoresCycle]
        window.canHide = false
        window.orderFrontRegardless()
        anchor = window
        for note in notes { addCard(note) }
    }

    private func addCard(_ note: Note) {
        guard cards[note.id] == nil, let screen = DesktopGeometry.screen else { return }
        let controller = DesktopController(note: note, screen: screen)
        controller.onEdit = { [weak self] in self?.edit(note.id) }
        controller.onDelete = { [weak self] in self?.delete(note.id) }
        controller.onChange = { [weak self] body in self?.update(note.id, body: body) }
        controller.onPlacement = { [weak self] placement in
            guard let self, let index = self.notes.firstIndex(where: { $0.id == note.id }) else { return }
            self.notes[index].placement = placement
            _ = self.persist()
        }
        cards[note.id] = controller
        if let window = controller.window {
            // Keeping every card attached to one anchor avoids joining all Spaces.
            anchor?.addChildWindow(window, ordered: .above)
            window.orderFrontRegardless()
        }
    }

    @objc func newNote() {
        guard finishEditor(restoreFocus: false), let screen = DesktopGeometry.screen else { return }
        let area = screen.visibleFrame
        let columns = max(1, Int((area.width - 40) / 300))
        let rows = max(1, Int((area.height - 40) / 270))
        let index = notes.count % (columns * rows)
        let placement = Placement(x: 32 + Double(index % columns) * 300,
                                  y: 32 + Double(index / columns) * 270)
            .clamped(toWidth: area.width, height: area.height)
        let note = Note(placement: placement)
        draft = note
        presentEditor(note, isNew: true)
    }

    private func edit(_ id: UUID) {
        if editor?.noteID == id {
            NSApp.activate(ignoringOtherApps: true)
            editor?.window?.makeKeyAndOrderFront(nil)
            return
        }
        guard finishEditor(restoreFocus: false), let note = notes.first(where: { $0.id == id }) else { return }
        presentEditor(note, isNew: false)
    }

    private func presentEditor(_ note: Note, isNew: Bool) {
        guard let screen = DesktopGeometry.screen else { return }
        let controller = EditorController(note: note, isNew: isNew)
        controller.onChange = { [weak self] body in self?.update(note.id, body: body) }
        controller.onFinish = { [weak self] in _ = self?.finishEditor() }
        controller.onDelete = { [weak self] in self?.delete(note.id) }
        editor = controller
        controller.show(on: screen)
    }

    private func update(_ id: UUID, body: String) {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].body = body
            cards[id]?.update(notes[index])
        } else if var note = draft, note.id == id {
            note.body = body
            draft = note
            if !note.isEmpty { notes.append(note) }
        }
        _ = persist()
    }

    @discardableResult private func finishEditor(restoreFocus: Bool = true) -> Bool {
        guard let controller = editor else { return true }
        guard persist() else { showSaveError(); return false }
        if let note = notes.first(where: { $0.id == controller.noteID }) { addCard(note) }
        controller.window?.orderOut(nil)
        editor = nil
        draft = nil
        if restoreFocus { previousApp?.activate(options: []) }
        return true
    }

    private func delete(_ id: UUID) {
        let remaining = notes.filter { $0.id != id }
        do { try store.save(remaining) }
        catch { saveError = error; showSaveError(); return }
        notes = remaining
        saveError = nil
        if let card = cards.removeValue(forKey: id), let window = card.window {
            anchor?.removeChildWindow(window)
            window.orderOut(nil)
        }
        if editor?.noteID == id {
            editor?.window?.orderOut(nil)
            editor = nil
            draft = nil
            previousApp?.activate(options: [])
        }
    }

    @discardableResult private func persist() -> Bool {
        guard loaded else { return false }
        do {
            try store.save(notes)
            saveError = nil
            editor?.setSaveError(false)
            return true
        } catch {
            saveError = error
            editor?.setSaveError(true)
            return false
        }
    }

    @objc private func moveNotesHere() {
        guard finishEditor(restoreFocus: false) else { return }
        for controller in cards.values { controller.window?.orderOut(nil) }
        cards.removeAll()
        anchor?.orderOut(nil)
        anchor = nil
        makeDesktop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let new = menu.addItem(withTitle: "New Sticky Note", action: #selector(newNote), keyEquivalent: "n")
        new.target = self
        menu.addItem(.separator())
        for note in notes {
            let item = menu.addItem(withTitle: note.title, action: #selector(openFromMenu(_:)), keyEquivalent: "")
            item.representedObject = note.id
            item.target = self
        }
        if notes.isEmpty {
            let item = menu.addItem(withTitle: "Your desktop is clear", action: nil, keyEquivalent: "")
            item.isEnabled = false
        }
        menu.addItem(.separator())
        let move = menu.addItem(withTitle: "Move Notes to This Desktop", action: #selector(moveNotesHere), keyEquivalent: "")
        move.target = self
        let folder = menu.addItem(withTitle: "Open Notes Data Folder", action: #selector(openDataFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Sticky Note", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func openFromMenu(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID { edit(id) }
    }
    @objc private func openDataFolder() { NSWorkspace.shared.open(store.fileURL.deletingLastPathComponent()) }

    private func buildMainMenu() {
        let main = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "Quit Sticky Note", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = app; main.addItem(appItem)
        let file = NSMenu(title: "File")
        let new = file.addItem(withTitle: "New Sticky Note", action: #selector(newNote), keyEquivalent: "n"); new.target = self
        let fileItem = NSMenuItem(); fileItem.submenu = file; main.addItem(fileItem)
        let edit = NSMenu(title: "Edit")
        for (title, action, key) in [
            ("Undo", Selector(("undo:")), "z"), ("Redo", Selector(("redo:")), "Z"),
            ("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")
        ] { edit.addItem(withTitle: title, action: action, keyEquivalent: key) }
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func showSaveError() {
        if let saveError { showError("Your note couldn’t be saved", error: saveError,
                                    detail: "Keep this editor open and copy the text somewhere safe before quitting.") }
    }
    private func showError(_ message: String, error: Error, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail + "\n\n" + error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
