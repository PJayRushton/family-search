import Foundation
import XCTest
@testable import FamilySearch

@MainActor
final class SwiftDataPeopleStoreTests: XCTestCase {
    func testSummaryUpsertAndDirectLookupRoundTripNullableFields() throws {
        let store = try SwiftDataPeopleStore.makeInMemory()
        let summary = Self.summary(death: nil, portrait: Self.portrait)

        try store.upsert(summaries: [summary])

        XCTAssertEqual(try store.summary(id: summary.id), summary)
        XCTAssertEqual(try store.summaries(), [summary])
        XCTAssertNil(try store.profile(id: summary.id))
    }

    func testProfilePersistsRelativesAndNullableOccupation() throws {
        let store = try SwiftDataPeopleStore.makeInMemory()
        let profile = PersonProfile(
            summary: Self.summary(death: Self.death, portrait: Self.portrait),
            occupation: nil,
            biography: "A deliberately short fixture.",
            relatives: [Self.relative]
        )

        try store.upsert(profile: profile)

        XCTAssertEqual(try store.profile(id: profile.id), profile)
    }

    func testSummaryRefreshDoesNotEraseFetchedProfileFields() throws {
        let store = try SwiftDataPeopleStore.makeInMemory()
        let profile = PersonProfile(
            summary: Self.summary(), occupation: "Carpenter", biography: "Biography",
            relatives: [Self.relative]
        )
        try store.upsert(profile: profile)

        let renamedSummary = PersonSummary(
            id: profile.id, name: PersonName(given: "Ezra", surname: "Whitcomb-Smith"),
            isLiving: false, birth: profile.summary.birth, death: profile.summary.death,
            portrait: profile.summary.portrait
        )
        try store.upsert(summaries: [renamedSummary])

        let refreshed = try XCTUnwrap(store.profile(id: profile.id))
        XCTAssertEqual(refreshed.summary, renamedSummary)
        XCTAssertEqual(refreshed.occupation, profile.occupation)
        XCTAssertEqual(refreshed.biography, profile.biography)
        XCTAssertEqual(refreshed.relatives, profile.relatives)
    }

    func testSeededPreviewUsesStoredDomainValues() async throws {
        let container = PreviewContainer.populated()
        var snapshots: [RepositorySnapshot<[PersonSummary]>] = []

        for try await snapshot in container.peopleRepository.people() { snapshots.append(snapshot) }

        guard case let .cached(people) = snapshots.first else {
            return XCTFail("Expected preview repository to emit persisted people")
        }
        XCTAssertEqual(people.first?.name.fullName, "Ezra Whitcomb")
    }

    func testProfileSurvivesReopeningDiskStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appending(path: "people.store")
        let profile = PersonProfile(
            summary: Self.summary(), occupation: "Carpenter", biography: "Biography",
            relatives: [Self.relative]
        )

        try SwiftDataPeopleStore.makePersistent(at: databaseURL).upsert(profile: profile)
        let reopenedStore = try SwiftDataPeopleStore.makePersistent(at: databaseURL)

        XCTAssertEqual(try reopenedStore.profile(id: profile.id), profile)
    }

    private static let portrait = PortraitReference(
        key: "portraits/L4RX-9FT.jpg",
        remoteURL: URL(string: "https://example.com/portraits/L4RX-9FT.jpg")!
    )
    private static let death = LifeEvent(date: "3 November 1941", year: 1941, place: "Ogden")
    private static let relative = RelativeSummary(
        id: PersonID(rawValue: "KWJH-123"), relationship: .spouse,
        name: PersonName(given: "Ada", surname: "Whitcomb"), birthYear: 1871, deathYear: nil
    )

    private static func summary(
        death: LifeEvent? = death,
        portrait: PortraitReference? = portrait
    ) -> PersonSummary {
        PersonSummary(
            id: PersonID(rawValue: "L4RX-9FT"), name: PersonName(given: "Ezra", surname: "Whitcomb"),
            isLiving: false, birth: LifeEvent(date: "12 March 1868", year: 1868, place: "Nauvoo"),
            death: death, portrait: portrait
        )
    }
}
