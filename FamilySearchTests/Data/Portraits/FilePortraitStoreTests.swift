import Foundation
import XCTest
@testable import FamilySearch

final class FilePortraitStoreTests: XCTestCase {
    func testWritesAndReadsBytesUsingStableSafePath() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FilePortraitStore(directory: directory)
        let portrait = PortraitReference(
            key: "../portraits/person/id.jpg",
            remoteURL: URL(string: "https://example.com/person.jpg")!
        )
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xD9])

        try await store.save(bytes, for: portrait)

        let reopenedStore = FilePortraitStore(directory: directory)
        let savedBytes = try await reopenedStore.data(for: portrait)
        XCTAssertEqual(savedBytes, bytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil).count, 1)
    }

    func testMissingPortraitReturnsNil() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = FilePortraitStore(directory: directory)
        let portrait = PortraitReference(key: "missing", remoteURL: URL(string: "https://example.com")!)

        let savedBytes = try await store.data(for: portrait)
        XCTAssertNil(savedBytes)
    }
}
