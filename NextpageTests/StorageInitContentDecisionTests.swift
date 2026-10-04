import XCTest

@testable import Nextpage

/// Covers the decision that seeds a welcome note only for a new, empty journal.
///
/// The decision logic was extracted into `Storage.decideInitContent` so the
/// matrix can be tested without spinning up a real Storage instance.
@MainActor
final class StorageInitContentDecisionTests: XCTestCase {

    func testEmptyNoteListUnsetFlagCreatesWelcomeContent() {
        XCTAssertEqual(
            Storage.decideInitContent(noteListIsEmpty: true, hasCreatedInitContent: false),
            .createInitFolders)
    }

    func testEmptyNoteListFlagAlreadySetSkips() {
        XCTAssertEqual(
            Storage.decideInitContent(noteListIsEmpty: true, hasCreatedInitContent: true),
            .skip)
    }

    func testExistingUserWithNotesAndUnsetFlagGetsMarkedInitialized() {
        // The exact regression in cb46c987 / 13964acd: a returning user has
        // notes on disk but the flag was never set. Old code seeded the demo
        // folders on every launch; new code marks them initialized so the
        // next "delete + relaunch" no longer triggers re-seeding.
        XCTAssertEqual(
            Storage.decideInitContent(noteListIsEmpty: false, hasCreatedInitContent: false),
            .markInitialized)
    }

    func testExistingUserWithNotesAndSetFlagGetsMarkedInitialized() {
        // Setting the flag is idempotent; the return value still says "do
        // nothing about init folders" via .markInitialized.
        XCTAssertEqual(
            Storage.decideInitContent(noteListIsEmpty: false, hasCreatedInitContent: true),
            .markInitialized)
    }

    func testGlobalPromptIsPersistedOutsideTheJournalNotes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NextpagePromptTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = PromptStore(storageRoot: root)
        try store.save("Always be concise.", scope: .global)

        XCTAssertEqual(try store.prompt(for: .global), "Always be concise.")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("config/prompt.md").path))
    }

    func testEffectivePromptAppendsGlobalAndJournalPrompts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NextpagePromptTests-\(UUID().uuidString)", isDirectory: true)
        let journalURL = root.appendingPathComponent("Work", isDirectory: true)
        try FileManager.default.createDirectory(at: journalURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = PromptStore(storageRoot: root)
        let journal = Project(url: journalURL)
        try store.save("Global context", scope: .global)
        try store.save("Journal context", scope: .journal(journal))

        XCTAssertEqual(try store.effectivePrompt(for: journal), "Global context\n\nJournal context")
    }

    func testEmptyPromptSaveRemovesThePortablePromptFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NextpagePromptTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = PromptStore(storageRoot: root)
        try store.save("Temporary prompt", scope: .global)
        try store.save("", scope: .global)

        XCTAssertEqual(try store.prompt(for: .global), "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: .global).path))
    }
}
