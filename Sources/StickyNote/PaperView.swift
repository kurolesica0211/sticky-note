import AppKit

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
    var onResize: ((NSEvent) -> Void)?
    var showsFold = true
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

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
        if showsFold && point.x > bounds.width - 24 && point.y > bounds.height - 24 {
            onResize?(event)
        } else if point.y < 42 {
            onDrag?(event)
        }
    }

    override func resetCursorRects() {
        addCursorRect(NSRect(x: 0, y: 0, width: max(0, bounds.width - 80), height: 40), cursor: .openHand)
    }
}
