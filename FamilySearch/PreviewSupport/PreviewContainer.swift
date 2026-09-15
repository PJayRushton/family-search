import Foundation

@MainActor
enum PreviewContainer {
    /// Previews exercise production SwiftData mapping while remaining memory-only and offline.
    static func populated() -> AppContainer {
        do {
            let store = try SwiftDataPeopleStore.makeInMemory()
            return AppContainer(peopleRepository: StoredPeopleRepository(
                store: store,
                seedProfiles: [sampleProfile, livingProfile]
            ),
                                portraitRepository: PreviewPortraitRepository())
        } catch { preconditionFailure("Preview persistence failed: \(error)") }
    }

    static let profileID = PersonID(rawValue: "L4RX-9FT")
    static let livingProfileID = PersonID(rawValue: "M7AB-2CD")

    private static let sampleProfile = PersonProfile(
        summary: PersonSummary(
            id: profileID, name: PersonName(given: "Ezra", surname: "Whitcomb"),
            isLiving: false, birth: LifeEvent(date: "12 March 1868", year: 1868, place: "Nauvoo, Illinois"),
            death: LifeEvent(date: "3 November 1941", year: 1941, place: "Ogden, Utah"), portrait: nil
        ), occupation: "Carpenter", biography: "Ezra built homes and raised a family in northern Utah.",
        relatives: [RelativeSummary(id: PersonID(rawValue: "KWJH-123"), relationship: .spouse,
                                    name: PersonName(given: "Ada", surname: "Whitcomb"),
                                    birthYear: 1871, deathYear: 1950)]
    )

    private static let livingProfile = PersonProfile(
        summary: PersonSummary(
            id: livingProfileID, name: PersonName(given: "Maya", surname: "Chen"), isLiving: true,
            birth: LifeEvent(date: "8 July 1992", year: 1992, place: "Seattle, Washington"),
            death: nil, portrait: nil
        ),
        occupation: nil,
        biography: "Maya enjoys preserving family stories.",
        relatives: []
    )
}

private struct PreviewPortraitRepository: PortraitRepository {
    func data(for portrait: PortraitReference) async throws -> Data? { nil }
}
