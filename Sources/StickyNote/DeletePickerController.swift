import AppKit
import NoteCore

final class DeletePickerPanel: NSPanel {
    var onDelete: (() -> Void)?
    var onDismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 51 && event.modifierFlags.contains(.command) { onDelete?(); return true }
        return super.performKeyEquivalent(with: event)
    }
    override func cancelOperation(_ sender: Any?) { onDismiss?() }
}

private final class PickerContentView: NSView { override var isFlipped: Bool { true } }

final class DeletePickerController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var onDelete: ((UUID) -> Bool)?
    var onClose: (() -> Void)?
    private var notes: [Note]
    private var filtered: [Note] = []
    private let search = NSSearchField()
    private let table = NSTableView()
    private let status = NSTextField(labelWithString: "")
    private let deleteButton = NSButton(title: "Delete note", target: nil, action: nil)

    init(notes: [Note]) {
        self.notes = notes
        let panel = DeletePickerPanel(contentRect: NSRect(x: 0, y: 0, width: 540, height: 410),
                                      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = "Delete Sticky Note"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 440, height: 280)
        super.init(window: panel)
        panel.delegate = self
        panel.onDelete = { [weak self] in self?.deleteSelected() }
        panel.onDismiss = { [weak self] in self?.dismiss() }
        let content = PickerContentView(frame: panel.contentView!.bounds)
        panel.contentView = content

        search.frame = NSRect(x: 20, y: 18, width: 500, height: 30)
        search.autoresizingMask = [.width]
        search.placeholderString = "Search your notes"
        search.setAccessibilityLabel("Search notes to delete")
        search.delegate = self
        content.addSubview(search)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 62, width: 500, height: 278))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .lineBorder
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
        column.width = 496
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 58
        table.intercellSpacing = NSSize(width: 0, height: 4)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel("Current notes")
        scroll.documentView = table
        content.addSubview(scroll)

        status.frame = NSRect(x: 20, y: 355, width: 350, height: 38)
        status.autoresizingMask = [.width, .minYMargin]
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.maximumNumberOfLines = 2
        content.addSubview(status)
        deleteButton.frame = NSRect(x: 404, y: 359, width: 116, height: 30)
        deleteButton.autoresizingMask = [.minXMargin, .minYMargin]
        deleteButton.bezelStyle = .rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelected)
        deleteButton.toolTip = "Delete selected note (⌘Delete)"
        content.addSubview(deleteButton)
        filter()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        if let screen = DesktopGeometry.screen, let window {
            let area = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2, y: area.midY - window.frame.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(search)
    }

    private func filter(preferredRow: Int = 0) {
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        filtered = notes.filter { query.isEmpty || $0.body.localizedCaseInsensitiveContains(query) }
        table.reloadData()
        if !filtered.isEmpty { table.selectRowIndexes(IndexSet(integer: min(preferredRow, filtered.count - 1)), byExtendingSelection: false) }
        status.stringValue = filtered.isEmpty ? (notes.isEmpty ? "No notes to delete." : "No matching notes.") : "\(filtered.count) notes · ↑↓ select\n⌘Delete removes the selected note · Esc closes"
        deleteButton.isEnabled = !filtered.isEmpty
    }

    func controlTextDidChange(_ notification: Notification) { filter() }
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }
    func tableViewSelectionDidChange(_ notification: Notification) { deleteButton.isEnabled = table.selectedRow >= 0 }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 58))
        let title = NSTextField(labelWithString: filtered[row].title)
        title.font = .systemFont(ofSize: 14, weight: .medium)
        title.frame = NSRect(x: 12, y: 31, width: max(50, tableView.bounds.width - 28), height: 20)
        title.lineBreakMode = .byTruncatingTail
        title.autoresizingMask = [.width]
        cell.textField = title
        cell.addSubview(title)
        let preview = filtered[row].body.split(whereSeparator: \.isNewline).dropFirst().joined(separator: " · ")
        let subtitle = NSTextField(labelWithString: preview.isEmpty ? "No additional text" : preview)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.frame = NSRect(x: 12, y: 9, width: max(50, tableView.bounds.width - 28), height: 18)
        subtitle.autoresizingMask = [.width]
        cell.addSubview(subtitle)
        return cell
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.moveUp(_:)) {
            guard !filtered.isEmpty else { return true }
            let delta = commandSelector == #selector(NSResponder.moveDown(_:)) ? 1 : -1
            let row = max(0, min(filtered.count - 1, table.selectedRow + delta))
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            table.scrollRowToVisible(row)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { dismiss(); return true }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { window?.makeFirstResponder(table); return true }
        return false
    }

    @objc private func deleteSelected() {
        let row = table.selectedRow
        guard filtered.indices.contains(row) else { NSSound.beep(); return }
        let id = filtered[row].id
        guard onDelete?(id) == true else { return }
        notes.removeAll { $0.id == id }
        filter(preferredRow: row)
        window?.makeFirstResponder(search)
    }
    private func dismiss() { window?.orderOut(nil); onClose?() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { dismiss(); return false }
}
