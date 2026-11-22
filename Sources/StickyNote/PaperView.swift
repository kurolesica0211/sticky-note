import AppKit
import NoteCore

enum Paper {
    static let ink = NSColor(srgbRed: 0.25, green: 0.20, blue: 0.10, alpha: 1)
    static let mutedInk = ink.withAlphaComponent(0.60)
    static let background = NSColor(srgbRed: 1, green: 0.94, blue: 0.66, alpha: 1)
    static let top = NSColor(srgbRed: 0.96, green: 0.85, blue: 0.45, alpha: 1)
    static let font = NSFont.systemFont(ofSize: 16)

    static func button(_ symbol: String, label: String, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label)!, target: target, action: action)
        button.bezelStyle = .inline
        button.isBordered = false
        button.contentTintColor = ink
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.focusRingType = .none
        return button
    }
}

final class PaperView: NSView {
    var onDrag: ((NSEvent) -> Void)?
    var onResize: ((NSEvent, ResizeEdges) -> Void)?
    var showsFold = true
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    private func edges(at point: NSPoint) -> ResizeEdges {
        var edges: ResizeEdges = []
        let margin: CGFloat = 7
        if point.x < margin { edges.insert(.left) }
        if point.x > bounds.width - margin { edges.insert(.right) }
        if point.y < margin { edges.insert(.top) }
        if point.y > bounds.height - margin { edges.insert(.bottom) }
        if showsFold && point.x > bounds.width - 22 && point.y > bounds.height - 22 {
            edges.formUnion([.right, .bottom])
        }
        return edges
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if bounds.contains(local), onResize != nil, !edges(at: local).isEmpty { return self }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Paper.background.setFill()
        bounds.fill()
        NSGradient(starting: Paper.top.withAlphaComponent(0.72), ending: Paper.top.withAlphaComponent(0.08))?
            .draw(in: NSRect(x: 0, y: 0, width: bounds.width, height: 42), angle: 90)
        // A restrained, deterministic paper texture. No bitmap or external asset.
        NSColor.black.withAlphaComponent(0.018).setFill()
        for row in stride(from: 4, to: Int(bounds.height), by: 8) {
            for col in stride(from: 3, to: Int(bounds.width), by: 11) {
                let offset = (row * 7 + col * 3) % 5
                NSRect(x: CGFloat(col + offset), y: CGFloat(row), width: 0.7, height: 0.7).fill()
            }
        }
        if showsFold {
            let fold = NSBezierPath()
            fold.move(to: NSPoint(x: bounds.maxX - 17, y: bounds.maxY))
            fold.line(to: NSPoint(x: bounds.maxX - 17, y: bounds.maxY - 17))
            fold.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 17))
            fold.close()
            Paper.top.withAlphaComponent(0.85).setFill()
            fold.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let edges = edges(at: point)
        if !edges.isEmpty, onResize != nil {
            onResize?(event, edges)
        } else if point.y < 42 {
            onDrag?(event)
        }
    }

    override func resetCursorRects() {
        addCursorRect(NSRect(x: 0, y: 0, width: max(0, bounds.width - 80), height: 40), cursor: .openHand)
        guard onResize != nil else { return }
        addCursorRect(NSRect(x: 0, y: 0, width: 7, height: bounds.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: bounds.width - 7, y: 0, width: 7, height: bounds.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: 0, y: 0, width: bounds.width, height: 7), cursor: .resizeUpDown)
        addCursorRect(NSRect(x: 0, y: bounds.height - 7, width: bounds.width, height: 7), cursor: .resizeUpDown)
    }
}

func resizePaperWindow(_ window: NSWindow, event: NSEvent, edges: ResizeEdges, minimum: NSSize) {
    guard let screen = DesktopGeometry.screen else { return }
    let original = window.frame
    // Use the original mouse-down position even if a fast drag is already queued.
    let start = window.convertPoint(toScreen: event.locationInWindow)
    while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
        let mouse = window.convertPoint(toScreen: next.locationInWindow)
        let frame = ResizeGeometry.resize(original, edges: edges, dx: mouse.x - start.x, dy: mouse.y - start.y,
                                          minimum: minimum, within: screen.visibleFrame)
        window.setFrame(frame, display: true)
        if next.type == .leftMouseUp { break }
    }
    window.invalidateCursorRects(for: window.contentView!)
}
