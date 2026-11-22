import AppKit
import NoteCore

final class EditorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { (windowController as? EditorController)?.finish() }
}

final class EditorController: NSWindowController, NSWindowDelegate {
    let noteID: UUID
    let textView = NoteTextView()
    var onChange: ((String) -> Void)?
    var onFinish: (() -> Void)?
    var onDelete: (() -> Void)?
    private let footer = NSTextField(labelWithString: "Saved on this Mac")

    init(note: Note, isNew: Bool) {
        noteID = note.id
        let panel = EditorPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 360),
                                styleMask: [.borderless], backing: .buffered, defer: false)
        panel.title = isNew ? "New Sticky Note" : "Edit Sticky Note"
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        // Capture follows the user; saved desktop cards keep their own Space.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .aqua)
        super.init(window: panel)
        panel.delegate = self

        let paper = PaperView(frame: panel.contentView!.bounds)
        paper.showsFold = false
        paper.onDrag = { [weak panel] event in panel?.performDrag(with: event) }
        panel.contentView = paper

        let title = NSTextField(labelWithString: isNew ? "NEW NOTE" : "YOUR NOTE")
        title.font = .systemFont(ofSize: 10, weight: .semibold)
        title.textColor = Paper.mutedInk
        title.frame = NSRect(x: 22, y: 16, width: 180, height: 16)
        paper.addSubview(title)

        let finishButton = NSButton(title: "Place on desktop", target: self, action: #selector(finish))
        finishButton.bezelStyle = .inline
        finishButton.isBordered = false
        finishButton.font = .systemFont(ofSize: 12, weight: .medium)
        finishButton.contentTintColor = Paper.ink
        finishButton.frame = NSRect(x: 250, y: 10, width: 132, height: 26)
        finishButton.toolTip = "Place on desktop (⌘Return or Esc)"
        paper.addSubview(finishButton)

        let scroll = NSScrollView(frame: NSRect(x: 22, y: 47, width: 356, height: 245))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder
        textView.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: scroll.contentSize.height)
        textView.minSize = NSSize(width: 0, height: scroll.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = textView
        paper.addSubview(scroll)
        textView.setBody(note.body)
        textView.onChange = { [weak self] in self?.onChange?($0) }
        textView.onFinish = { [weak self] in self?.finish() }

        let checkbox = NSButton(title: "☐  Checkbox", target: textView, action: #selector(NoteTextView.addCheckbox))
        checkbox.isBordered = false
        checkbox.bezelStyle = .inline
        checkbox.contentTintColor = Paper.ink
        checkbox.font = .systemFont(ofSize: 12)
        checkbox.frame = NSRect(x: 17, y: 306, width: 105, height: 28)
        checkbox.toolTip = "Toggle checkbox on this line (⇧⌘L)"
        checkbox.setAccessibilityLabel("Add checkbox")
        paper.addSubview(checkbox)

        footer.font = .systemFont(ofSize: 10)
        footer.textColor = Paper.mutedInk
        footer.frame = NSRect(x: 138, y: 315, width: 190, height: 16)
        paper.addSubview(footer)

        let delete = Paper.button("trash", label: "Delete note", target: self, action: #selector(deleteNote))
        delete.frame = NSRect(x: 348, y: 307, width: 28, height: 28)
        paper.addSubview(delete)
        panel.initialFirstResponder = textView
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(on screen: NSScreen) {
        guard let window else { return }
        let area = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2,
                                      y: area.midY - window.frame.height / 2 + 40))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
    }

    func setSaveError(_ failed: Bool) {
        footer.stringValue = failed ? "Couldn’t save — try again" : "Saved on this Mac"
        footer.textColor = failed ? .systemRed : Paper.mutedInk
    }

    @objc func finish() { onFinish?() }
    @objc private func deleteNote() { onDelete?() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { finish(); return false }
}
