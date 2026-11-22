import AppKit
import NoteCore

final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum DesktopGeometry {
    static var screen: NSScreen? { NSScreen.screens.first }
    static var level: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }
    static func frame(for placement: Placement, on screen: NSScreen) -> NSRect {
        let area = screen.visibleFrame
        let p = placement.clamped(toWidth: area.width, height: area.height)
        return NSRect(x: area.minX + p.x, y: area.maxY - p.y - p.height, width: p.width, height: p.height)
    }
    static func placement(for frame: NSRect, on screen: NSScreen) -> Placement {
        let area = screen.visibleFrame
        return Placement(x: frame.minX - area.minX, y: area.maxY - frame.maxY,
                         width: frame.width, height: frame.height)
            .clamped(toWidth: area.width, height: area.height)
    }
}

final class DesktopController: NSWindowController, NSWindowDelegate {
    let noteID: UUID
    let textView = NoteTextView()
    var onChange: ((String) -> Void)?
    var onPlacement: ((Placement) -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    private var positioning = false
    private let paper: PaperView
    private let scroll: NSScrollView
    private let edit: NSButton
    private let delete: NSButton
    private let label = NSTextField(labelWithString: "NOTE")

    init(note: Note, screen: NSScreen) {
        noteID = note.id
        let frame = DesktopGeometry.frame(for: note.placement, on: screen)
        let window = DesktopWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "Sticky Note — \(note.title)"
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = DesktopGeometry.level
        window.collectionBehavior = [.stationary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.canHide = false
        window.appearance = NSAppearance(named: .aqua)

        paper = PaperView(frame: NSRect(origin: .zero, size: frame.size))
        scroll = NSScrollView()
        edit = NSButton()
        delete = NSButton()
        super.init(window: window)
        window.delegate = self
        window.contentView = paper
        paper.onDrag = { [weak self] event in self?.drag(event) }
        paper.onResize = { [weak self] event in self?.resize(event) }

        label.font = .systemFont(ofSize: 9, weight: .semibold)
        label.textColor = Paper.mutedInk
        paper.addSubview(label)
        for (button, symbol, title, action) in [
            (edit, "pencil", "Edit note", #selector(editNote)),
            (delete, "trash", "Delete note", #selector(deleteNote))
        ] {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            button.isBordered = false
            button.bezelStyle = .inline
            button.contentTintColor = Paper.mutedInk
            button.target = self
            button.action = action
            button.toolTip = title
            button.setAccessibilityLabel(title)
            paper.addSubview(button)
        }

        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        textView.desktopMode = true
        textView.isEditable = false
        textView.isSelectable = false
        textView.onEdit = { [weak self] in self?.onEdit?() }
        textView.onChange = { [weak self] in self?.onChange?($0) }
        scroll.documentView = textView
        paper.addSubview(scroll)
        layout()
        update(note)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(_ note: Note) {
        textView.setBody(note.body)
        window?.title = "Sticky Note — \(note.title)"
    }

    func place(_ placement: Placement, on screen: NSScreen) {
        positioning = true
        window?.setFrame(DesktopGeometry.frame(for: placement, on: screen), display: true)
        layout()
        positioning = false
    }

    private func layout() {
        let size = paper.bounds.size
        label.frame = NSRect(x: 17, y: 13, width: max(0, size.width - 100), height: 14)
        edit.frame = NSRect(x: size.width - 72, y: 7, width: 26, height: 26)
        delete.frame = NSRect(x: size.width - 39, y: 7, width: 26, height: 26)
        scroll.frame = NSRect(x: 17, y: 39, width: max(1, size.width - 34), height: max(1, size.height - 60))
        textView.setFrameSize(NSSize(width: scroll.contentSize.width, height: max(textView.frame.height, scroll.contentSize.height)))
        textView.minSize = NSSize(width: 0, height: scroll.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        paper.needsDisplay = true
    }

    private func drag(_ event: NSEvent) {
        window?.performDrag(with: event)
        keepOnMainScreen()
    }

    private func resize(_ event: NSEvent) {
        guard let window else { return }
        let original = window.frame
        let start = NSEvent.mouseLocation
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { break }
            let current = NSEvent.mouseLocation
            let width = max(220, original.width + current.x - start.x)
            let height = max(160, original.height - current.y + start.y)
            window.setFrame(NSRect(x: original.minX, y: original.maxY - height, width: width, height: height), display: true)
        }
        keepOnMainScreen()
    }

    private func keepOnMainScreen() {
        guard let window, let screen = DesktopGeometry.screen else { return }
        let placement = DesktopGeometry.placement(for: window.frame, on: screen)
        place(placement, on: screen)
        onPlacement?(placement)
    }

    func windowDidMove(_ notification: Notification) {
        guard !positioning, let window, let screen = DesktopGeometry.screen else { return }
        onPlacement?(DesktopGeometry.placement(for: window.frame, on: screen))
    }
    func windowDidResize(_ notification: Notification) { layout() }
    @objc private func editNote() { onEdit?() }
    @objc private func deleteNote() { onDelete?() }
}
