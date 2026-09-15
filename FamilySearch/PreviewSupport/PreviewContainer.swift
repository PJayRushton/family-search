import Foundation

@MainActor
enum PreviewContainer {
    /// Previews exercise production SwiftData mapping while remaining memory-only and offline.
    static func populated() -> AppContainer {
        do {
            let store = try SwiftDataPeopleStore.makeInMemory()
            try store.upsert(profile: sampleProfile)
            return AppContainer(peopleRepository: StoredPeopleRepository(store: store),
                                portraitRepository: PreviewPortraitRepository())
        } catch { preconditionFailure("Preview persistence failed: \(error)") }
    }

    private static let sampleProfile = PersonProfile(
        summary: PersonSummary(
            id: PersonID(rawValue: "L4RX-9FT"), name: PersonName(given: "Ezra", surname: "Whitcomb"),
            isLiving: false, birth: LifeEvent(date: "12 March 1868", year: 1868, place: "Nauvoo, Illinois"),
            death: LifeEvent(date: "3 November 1941", year: 1941, place: "Ogden, Utah"), portrait: nil
        ), occupation: "Carpenter", biography: "Ezra built homes and raised a family in northern Utah.",
        relatives: [RelativeSummary(id: PersonID(rawValue: "KWJH-123"), relationship: .spouse,
                                    name: PersonName(given: "Ada", surname: "Whitcomb"),
                                    birthYear: 1871, deathYear: 1950)]
    )
}

private struct PreviewPortraitRepository: PortraitRepository {
    func data(for portrait: PortraitReference) async throws -> Data? { nil }
}
