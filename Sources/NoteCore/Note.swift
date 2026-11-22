import Foundation

public struct Placement: Codable, Equatable {
    // Points from the top-left of the primary display's usable area.
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double = 32, y: Double = 32, width: Double = 280, height: Double = 250) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    public func clamped(toWidth screenWidth: Double, height screenHeight: Double) -> Placement {
        let availableWidth = max(1, screenWidth)
        let availableHeight = max(1, screenHeight)
        let w = min(max(width.isFinite ? width : 280, 220), availableWidth)
        let h = min(max(height.isFinite ? height : 250, 160), availableHeight)
        return Placement(
            x: min(max(x.isFinite ? x : 32, 0), availableWidth - w),
            y: min(max(y.isFinite ? y : 32, 0), availableHeight - h),
            width: w, height: h
        )
    }
}

public struct Note: Codable, Identifiable, Equatable {
    public var id: UUID
    public var body: String
    public var placement: Placement
    public var richText: Data?
    public init(id: UUID = UUID(), body: String = "", placement: Placement = Placement(), richText: Data? = nil) {
        self.id = id; self.body = body; self.placement = placement; self.richText = richText
    }
    public var isEmpty: Bool { body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var title: String {
        let first = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Untitled note"
        return String(first.prefix(48))
    }
}

public enum Checklist {
    public struct Item: Equatable {
        public var checked: Bool
        public var prefixLength: Int
        public var content: String
    }
    public static func item(in line: String) -> Item? {
        for (prefix, checked) in [("☐ ", false), ("☑ ", true), ("- [ ] ", false), ("- [x] ", true), ("- [X] ", true)] {
            if line.hasPrefix(prefix) {
                return Item(checked: checked, prefixLength: (prefix as NSString).length,
                            content: String(line.dropFirst(prefix.count)))
            }
        }
        return nil
    }
    public static func toggled(_ line: String) -> String {
        guard let item = item(in: line) else { return line }
        return (item.checked ? "☐ " : "☑ ") + item.content
    }
}

public struct NoteStore {
    private struct Document: Codable { var version: Int; var notes: [Note] }
    public enum StoreError: LocalizedError {
        case unsupportedVersion(Int)
        public var errorDescription: String? {
            switch self { case .unsupportedVersion(let version): return "This notes file uses a newer format (\(version)). Update Sticky Note before opening it." }
        }
    }
    public let fileURL: URL
    public init(directory: URL) { fileURL = directory.appendingPathComponent("notes.json") }
    public func load() throws -> [Note] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: fileURL))
        guard (1...2).contains(document.version) else { throw StoreError.unsupportedVersion(document.version) }
        return document.notes
    }
    public func save(_ notes: [Note]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Document(version: 2, notes: notes)).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
