#if EDITOR_CHECKS
import AppKit
import NoteCore

func runEditorChecks() -> Int32 {
    _ = NSApplication.shared
    var failures = 0
    var count = 0
    func check(_ name: String, _ condition: @autoclosure () -> Bool) {
        count += 1
        if condition() { print("PASS: \(name)") }
        else { failures += 1; print("FAIL: \(name)") }
    }
    func traits(_ text: NoteTextView, at index: Int) -> NSFontTraitMask {
        let font = text.textStorage?.attribute(.font, at: index, effectiveRange: nil) as? NSFont ?? Paper.font
        return NSFontManager.shared.traits(of: font)
    }
    let text = NoteTextView()
    text.setBody("Hello café 📝")
    text.setSelectedRange(NSRange(location: 0, length: 5))
    text.toggleBold()
    check("Selected text becomes bold", traits(text, at: 0).contains(.boldFontMask))
    check("Unselected text stays regular", !traits(text, at: 6).contains(.boldFontMask))
    text.toggleItalic()
    check("Bold and italic can overlap", traits(text, at: 0).contains([.boldFontMask, .italicFontMask]))
    let copy = NoteTextView()
    copy.setBody(text.string, richText: text.richTextData)
    check("Formatting survives RTF reload", traits(copy, at: 0).contains([.boldFontMask, .italicFontMask]))
    check("Unicode text survives RTF reload", copy.string == "Hello café 📝")
    copy.setSelectedRange(NSRange(location: 0, length: 5))
    copy.toggleBold()
    check("Turning off bold preserves italics", !traits(copy, at: 0).contains(.boldFontMask) && traits(copy, at: 0).contains(.italicFontMask))
    copy.setSelectedRange(NSRange(location: 0, length: 0))
    copy.addCheckbox()
    check("Checkbox insertion preserves content styling", traits(copy, at: 2).contains(.italicFontMask))
    copy.setSelectedRange(NSRange(location: (copy.string as NSString).length, length: 0))
    copy.insertNewline(nil)
    check("Return continues a checklist", copy.string.hasSuffix("\n☐ "))
    copy.insertNewline(nil)
    check("Empty checkbox ends the checklist", copy.string.hasSuffix("\n"))

    let typed = NoteTextView()
    typed.toggleBold()
    typed.insertText("Typed", replacementRange: NSRange(location: 0, length: 0))
    check("Bold can be enabled before typing", traits(typed, at: 0).contains(.boldFontMask))
    let fallback = NoteTextView()
    fallback.setBody("Keep the plain text", richText: Data("bad RTF".utf8))
    check("Invalid RTF falls back to the saved text", fallback.string == "Keep the plain text")

    let editor = EditorController(note: Note(body: "Resize"), isNew: false)
    editor.window?.setContentSize(NSSize(width: 660, height: 480))
    check("Editor content grows with its window", (editor.textView.enclosingScrollView?.frame.width ?? 0) > 600)
    print("\(count - failures)/\(count) editor checks passed")
    return failures == 0 ? 0 : 1
}
#endif
