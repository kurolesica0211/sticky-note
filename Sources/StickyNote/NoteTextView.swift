import AppKit
import NoteCore

final class NoteTextView: NSTextView {
    var onChange: ((String, Data?) -> Void)?
    var onFinish: (() -> Void)?
    var onEdit: (() -> Void)?
    var desktopMode = false
    var isApplyingStyle = false
    var placeholder = "A thought, a reminder, a little list…"

    convenience init() {
        self.init(frame: .zero)
        isRichText = true
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

    func setBody(_ body: String, richText: Data? = nil) {
        if let richText,
           let formatted = try? NSAttributedString(data: richText, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil),
           formatted.string == body {
            textStorage?.setAttributedString(formatted)
        } else {
            textStorage?.setAttributedString(NSAttributedString(string: body, attributes: [.font: Paper.font]))
        }
        restyle()
        needsDisplay = true
    }

    var richTextData: Data? {
        guard !string.isEmpty else { return nil }
        return try? textStorage?.data(from: NSRange(location: 0, length: (string as NSString).length),
                                      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    override func didChangeText() {
        super.didChangeText()
        guard !isApplyingStyle else { return }
        restyle()
        onChange?(string, richTextData)
        needsDisplay = true
    }

    func restyle() {
        guard let storage = textStorage else { return }
        isApplyingStyle = true
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let attributes: [NSAttributedString.Key: Any] = [.font: Paper.font, .foregroundColor: Paper.ink, .paragraphStyle: paragraph]
        storage.beginEditing()
        let fullRange = NSRange(location: 0, length: storage.length)
        var fonts: [(NSRange, NSFont)] = []
        storage.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let traits = NSFontManager.shared.traits(of: value as? NSFont ?? Paper.font)
            var font = Paper.font
            if traits.contains(.boldFontMask) { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
            if traits.contains(.italicFontMask) { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            fonts.append((range, font))
        }
        storage.removeAttribute(.strikethroughStyle, range: fullRange)
        storage.removeAttribute(.link, range: fullRange)
        storage.removeAttribute(.underlineStyle, range: fullRange)
        storage.addAttributes([.foregroundColor: Paper.ink, .paragraphStyle: paragraph], range: fullRange)
        for (range, font) in fonts { storage.addAttribute(.font, value: font, range: range) }
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
        var typing = attributes
        typing[.font] = typingAttributes[.font] as? NSFont ?? Paper.font
        typingAttributes = typing
        isApplyingStyle = false
    }

    @objc func toggleBold() { toggle(.boldFontMask, name: "Bold") }
    @objc func toggleItalic() { toggle(.italicFontMask, name: "Italic") }

    private func toggle(_ trait: NSFontTraitMask, name: String) {
        let manager = NSFontManager.shared
        let range = selectedRange()
        guard range.length > 0, let storage = textStorage else {
            let font = typingAttributes[.font] as? NSFont ?? Paper.font
            typingAttributes[.font] = manager.traits(of: font).contains(trait)
                ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)
            window?.makeFirstResponder(self)
            return
        }
        let previous = NSAttributedString(attributedString: storage)
        var allHaveTrait = true
        storage.enumerateAttribute(.font, in: range) { value, _, _ in
            if !manager.traits(of: value as? NSFont ?? Paper.font).contains(trait) { allHaveTrait = false }
        }
        var changes: [(NSRange, NSFont)] = []
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = value as? NSFont ?? Paper.font
            changes.append((subrange, allHaveTrait ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)))
        }
        undoManager?.registerUndo(withTarget: self) { $0.restore(previous, selection: range) }
        undoManager?.setActionName(name)
        storage.beginEditing()
        for (subrange, font) in changes { storage.addAttribute(.font, value: font, range: subrange) }
        storage.endEditing()
        restyle()
        setSelectedRange(range)
        onChange?(string, richTextData)
        window?.makeFirstResponder(self)
    }

    private func restore(_ text: NSAttributedString, selection: NSRange) {
        guard let storage = textStorage else { return }
        let previous = NSAttributedString(attributedString: storage)
        let previousSelection = selectedRange()
        undoManager?.registerUndo(withTarget: self) { $0.restore(previous, selection: previousSelection) }
        storage.setAttributedString(text)
        restyle()
        setSelectedRange(selection)
        onChange?(string, richTextData)
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
        let replacement = item.checked ? "☐ " : "☑ "
        if desktopMode {
            textStorage?.replaceCharacters(in: prefixRange, with: replacement)
            restyle()
            onChange?(string, richTextData)
        } else {
            replace(prefixRange, with: replacement)
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
        if event.charactersIgnoringModifiers?.lowercased() == "l" && event.modifierFlags.contains([.command, .shift]) {
            addCheckbox(); return
        }
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "b" { toggleBold(); return }
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "i" { toggleItalic(); return }
        super.keyDown(with: event)
    }

    private func replace(_ range: NSRange, with text: String) {
        insertText(text, replacementRange: range)
    }
}
