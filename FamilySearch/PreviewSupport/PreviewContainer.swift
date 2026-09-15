import Foundation

@MainActor
enum PreviewContainer {
    /// Previews exercise production SwiftData mapping while remaining memory-only and offline.
    static func populated() -> AppContainer {
        do {
            let store = try SwiftDataPeopleStore.makeInMemory()
            return AppContainer(peopleRepository: StoredPeopleRepository(store: store, seedProfiles: sampleProfiles),
                                portraitRepository: PreviewPortraitRepository())
        } catch { preconditionFailure("Preview persistence failed: \(error)") }
    }

    private static let sampleProfiles = [
        PersonProfile(
            summary: PersonSummary(
                id: PersonID(rawValue: "L4RX-9FT"),
                name: PersonName(given: "Ezra", surname: "Whitcomb"),
                isLiving: false,
                birth: LifeEvent(date: "12 March 1868", year: 1868, place: "Nauvoo, Illinois"),
                death: LifeEvent(date: "3 November 1941", year: 1941, place: "Ogden, Utah"),
                portrait: nil
            ),
            occupation: "Carpenter",
            biography: "Ezra built homes and raised a family in northern Utah.",
            relatives: [
                RelativeSummary(
                    id: PersonID(rawValue: "KWJH-123"),
                    relationship: .spouse,
                    name: PersonName(given: "Ada", surname: "Whitcomb"),
                    birthYear: 1871,
                    deathYear: 1950
                )
            ]
        ),
        PersonProfile(
            summary: PersonSummary(
                id: PersonID(rawValue: "LIVE-123"),
                name: PersonName(given: "June", surname: "Hart"),
                isLiving: true,
                birth: LifeEvent(date: "about 1980", year: 1980, place: "Denver, Colorado"),
                death: nil,
                portrait: nil
            ),
            occupation: nil,
            biography: "A living-person preview with intentionally absent optional fields.",
            relatives: []
        )
    ]
}

private struct PreviewPortraitRepository: PortraitRepository {
    func data(for portrait: PortraitReference) async throws -> Data? { nil }
}
