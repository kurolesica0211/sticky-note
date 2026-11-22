import Foundation
import NoteCore

struct CheckFailure: Error, CustomStringConvertible { let description: String }
func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) throws {
    guard actual == expected else { throw CheckFailure(description: "\(file):\(line): \(actual) != \(expected)") }
}
func XCTAssertTrue(_ value: Bool) throws { try XCTAssertEqual(value, true) }
func XCTAssertFalse(_ value: Bool) throws { try XCTAssertEqual(value, false) }
func XCTAssertNil<T>(_ value: T?) throws { try XCTAssertTrue(value == nil) }
func XCTAssertLessThanOrEqual<T: Comparable>(_ actual: T, _ maximum: T) throws { try XCTAssertTrue(actual <= maximum) }
func XCTAssertThrowsError<T>(_ body: @autoclosure () throws -> T) throws {
    do { _ = try body() } catch { return }
    throw CheckFailure(description: "Expected an error")
}

final class NoteCoreTests {
    private func temporaryStore() throws -> (NoteStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (NoteStore(directory: directory), directory)
    }

    func testRoundTripPreservesUnicodeCheckboxesAndPositions() throws {
        let (store, directory) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let notes = [Note(body: "Ideas 📝\n☐ Buy coffee\n☑ Call José\n日本語", placement: Placement(x: 200, y: 70, width: 310, height: 240))]
        try store.save(notes)
        try XCTAssertEqual(try store.load(), notes)
    }

    func testExplicitDeletionSurvivesReload() throws {
        let (store, directory) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = Note(body: "Keep")
        let second = Note(body: "Delete")
        try store.save([first, second])
        try store.save([first])
        try XCTAssertEqual(try store.load(), [first])
        try XCTAssertFalse(String(decoding: try Data(contentsOf: store.fileURL), as: UTF8.self).contains(second.id.uuidString))
    }

    func testCorruptFileFailsWithoutOverwritingIt() throws {
        let (store, directory) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let damaged = Data("{\"version\":1,\"notes\":[".utf8)
        try damaged.write(to: store.fileURL)
        try XCTAssertThrowsError(try store.load())
        try XCTAssertEqual(try Data(contentsOf: store.fileURL), damaged)
    }

    func testFutureFormatIsRejected() throws {
        let (store, directory) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"version\":3,\"notes\":[]}".utf8).write(to: store.fileURL)
        try XCTAssertThrowsError(try store.load())
    }

    func testASecondDisplayDisconnectCannotLeaveNotesOffscreen() throws {
        let placement = Placement(x: 2400, y: 900, width: 600, height: 700)
            .clamped(toWidth: 1280, height: 720)
        try XCTAssertEqual(placement.x, 680)
        try XCTAssertEqual(placement.y, 20)
        try XCTAssertLessThanOrEqual(placement.x + placement.width, 1280)
        try XCTAssertLessThanOrEqual(placement.y + placement.height, 720)
    }

    func testSmallScreenAndInvalidGeometryRemainUsable() throws {
        let placement = Placement(x: -.infinity, y: -80, width: .nan, height: 900)
            .clamped(toWidth: 200, height: 130)
        try XCTAssertEqual(placement, Placement(x: 0, y: 0, width: 200, height: 130))
    }

    func testCheckboxToggleDoesNotDamageTextOrNewlines() throws {
        try XCTAssertEqual(Checklist.toggled("☐ Send résumé 📨\n"), "☑ Send résumé 📨\n")
        try XCTAssertEqual(Checklist.toggled("- [X] Already done"), "☐ Already done")
        try XCTAssertEqual(Checklist.toggled("Ordinary text"), "Ordinary text")
        try XCTAssertNil(Checklist.item(in: "An inline ☐ symbol"))
    }

    func testEmptyAndWhitespaceDraftsAreRecognized() throws {
        try XCTAssertTrue(Note(body: " \n\t ").isEmpty)
        try XCTAssertFalse(Note(body: "☐ Task").isEmpty)
    }

    func testVersionOneNotesLoadWithoutFormatting() throws {
        let (store, directory) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID()
        let old = "{\"version\":1,\"notes\":[{\"id\":\"\(id)\",\"body\":\"Existing note\",\"placement\":{\"x\":32,\"y\":32,\"width\":280,\"height\":250}}]}"
        try Data(old.utf8).write(to: store.fileURL)
        let loaded = try store.load()
        try XCTAssertEqual(loaded.first?.body, "Existing note")
        try XCTAssertNil(loaded.first?.richText)
        try store.save(loaded)
        try XCTAssertEqual(try store.load(), loaded)
    }

    func testFormattingPayloadRoundTrip() throws {
        let (store, directory) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = Note(body: "Bold", richText: Data("{\\rtf1\\ansi \\b Bold}".utf8))
        try store.save([note])
        try XCTAssertEqual(try store.load(), [note])
    }

    func testResizingKeepsOppositeEdgesFixed() throws {
        let frame = CGRect(x: 100, y: 100, width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let minimum = CGSize(width: 220, height: 160)
        let left = ResizeGeometry.resize(frame, edges: .left, dx: -50, dy: 0, minimum: minimum, within: bounds)
        try XCTAssertEqual(left, CGRect(x: 50, y: 100, width: 450, height: 300))
        let top = ResizeGeometry.resize(frame, edges: .top, dx: 0, dy: 70, minimum: minimum, within: bounds)
        try XCTAssertEqual(top, CGRect(x: 100, y: 100, width: 400, height: 370))
        let corner = ResizeGeometry.resize(frame, edges: [.right, .bottom], dx: 80, dy: -30, minimum: minimum, within: bounds)
        try XCTAssertEqual(corner, CGRect(x: 100, y: 70, width: 480, height: 330))
    }

    func testResizeRespectsMinimumAndScreenEdges() throws {
        let frame = CGRect(x: 100, y: 100, width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let minimum = CGSize(width: 220, height: 160)
        let small = ResizeGeometry.resize(frame, edges: [.left, .bottom], dx: 1000, dy: 1000, minimum: minimum, within: bounds)
        try XCTAssertEqual(small, CGRect(x: 280, y: 240, width: 220, height: 160))
        let large = ResizeGeometry.resize(frame, edges: [.right, .top], dx: 5000, dy: 5000, minimum: minimum, within: bounds)
        try XCTAssertEqual(large.maxX, bounds.maxX)
        try XCTAssertEqual(large.maxY, bounds.maxY)
    }
}

let suite = NoteCoreTests()
let checks: [(String, () throws -> Void)] = [
    ("Unicode and placement round trip", suite.testRoundTripPreservesUnicodeCheckboxesAndPositions),
    ("Explicit deletion survives reload", suite.testExplicitDeletionSurvivesReload),
    ("Corrupt data is preserved", suite.testCorruptFileFailsWithoutOverwritingIt),
    ("Newer data formats are rejected", suite.testFutureFormatIsRejected),
    ("Monitor disconnect keeps notes on screen", suite.testASecondDisplayDisconnectCannotLeaveNotesOffscreen),
    ("Invalid geometry stays usable", suite.testSmallScreenAndInvalidGeometryRemainUsable),
    ("Checkbox toggles preserve text", suite.testCheckboxToggleDoesNotDamageTextOrNewlines),
    ("Empty drafts", suite.testEmptyAndWhitespaceDraftsAreRecognized),
    ("Version 0.1 notes migrate without losing text", suite.testVersionOneNotesLoadWithoutFormatting),
    ("Formatting payload survives storage", suite.testFormattingPayloadRoundTrip),
    ("Edge resizing preserves the opposite edge", suite.testResizingKeepsOppositeEdgesFixed),
    ("Resize limits stay on screen", suite.testResizeRespectsMinimumAndScreenEdges)
]
var failures = 0
for (name, check) in checks {
    do { try check(); print("PASS: \(name)") }
    catch { failures += 1; print("FAIL: \(name): \(error)") }
}
print("\(checks.count - failures)/\(checks.count) checks passed")
exit(failures == 0 ? 0 : 1)
