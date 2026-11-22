import AppKit
import NoteCore

final class NoteTextView: NSTextView {
    var onChange: ((String) -> Void)?
    var onFinish: (() -> Void)?
    var onEdit: (() -> Void)?
    var desktopMode = false
    var isApplyingStyle = false
    var placeholder = "A thought, a reminder, a little list…"

    convenience init() {
        self.init(frame: .zero)
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        drawsBackground = false
        textColor = Paper.ink
        insertionPointColor = Paper.ink
        font = Paper.font
        textContainerInset = NSSize(width: 0, height: 8)
        textContainer?.lineFragmentPadding = 0
        isHorizontallyResizable = false
        isVerticallyResizable = true
        autoresizingMask = [.width]
        textContainer?.widthTracksTextView = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticLinkDetectionEnabled = false
        setAccessibilityLabel("Note text")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty && !desktopMode {
            placeholder.draw(in: NSRect(x: 1, y: 8, width: bounds.width - 8, height: 60),
                             withAttributes: [.font: Paper.font, .foregroundColor: Paper.mutedInk])
        }
    }

    func setBody(_ body: String) {
        if string != body { string = body }
        restyle()
        needsDisplay = true
    }

    override func didChangeText() {
        super.didChangeText()
        guard !isApplyingStyle else { return }
        restyle()
        onChange?(string)
        needsDisplay = true
    }

    func restyle() {
        guard let storage = textStorage else { return }
        isApplyingStyle = true
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let attributes: [NSAttributedString.Key: Any] = [.font: Paper.font, .foregroundColor: Paper.ink, .paragraphStyle: paragraph]
        storage.beginEditing()
        storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
        let source = string as NSString
        var offset = 0
        while offset < source.length {
            let range = source.lineRange(for: NSRange(location: offset, length: 0))
            if let item = Checklist.item(in: source.substring(with: range)), item.checked {
                storage.addAttribute(.foregroundColor, value: Paper.mutedInk, range: range)
                let contentRange = NSRange(location: range.location + item.prefixLength, length: max(0, range.length - item.prefixLength))
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
            }
            offset = NSMaxRange(range)
        }
        storage.endEditing()
        typingAttributes = attributes
        isApplyingStyle = false
    }

    override func mouseDown(with event: NSEvent) {
        if toggleCheckbox(at: event) { return }
        if desktopMode {
            onEdit?()
            return
        }
        super.mouseDown(with: event)
    }

    private func toggleCheckbox(at event: NSEvent) -> Bool {
        guard let layoutManager, let textContainer, !string.isEmpty else { return false }
        var point = convert(event.locationInWindow, from: nil)
        point.x -= textContainerOrigin.x
        point.y -= textContainerOrigin.y
        let character = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        let source = string as NSString
        guard character < source.length else { return false }
        let line = source.lineRange(for: NSRange(location: character, length: 0))
        guard let item = Checklist.item(in: source.substring(with: line)) else { return false }
        let prefixRange = NSRange(location: line.location, length: item.prefixLength)
        let glyphs = layoutManager.glyphRange(forCharacterRange: prefixRange, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer).insetBy(dx: -3, dy: -2)
        guard rect.contains(point) else { return false }
        let replacement = Checklist.toggled(source.substring(with: line))
        if desktopMode {
            string = source.replacingCharacters(in: line, with: replacement)
            restyle()
            onChange?(string)
        } else {
            replace(line, with: replacement)
        }
        return true
    }

    @objc func addCheckbox() {
        let source = string as NSString
        let location = min(selectedRange().location, source.length)
        let range = source.lineRange(for: NSRange(location: location, length: 0))
        let line = source.substring(with: range)
        if let item = Checklist.item(in: line) {
            replace(NSRange(location: range.location, length: item.prefixLength), with: "")
        } else {
            replace(NSRange(location: range.location, length: 0), with: "☐ ")
        }
        window?.makeFirstResponder(self)
    }

    override func insertNewline(_ sender: Any?) {
        let source = string as NSString
        let location = min(selectedRange().location, source.length)
        let range = source.lineRange(for: NSRange(location: location, length: 0))
        if let item = Checklist.item(in: source.substring(with: range)) {
            if item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                replace(NSRange(location: range.location, length: item.prefixLength), with: "")
                return
            }
            insertText("\n☐ ", replacementRange: selectedRange())
        } else {
            super.insertNewline(sender)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || (event.keyCode == 36 && event.modifierFlags.contains(.command)) {
            onFinish?(); return
        }
        if event.charactersIgnoringModifiers == "l" && event.modifierFlags.contains([.command, .shift]) {
            addCheckbox(); return
        }
        super.keyDown(with: event)
    }

    private func replace(_ range: NSRange, with text: String) {
        guard shouldChangeText(in: range, replacementString: text) else { return }
        textStorage?.replaceCharacters(in: range, with: text)
        setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
        didChangeText()
    }
}
