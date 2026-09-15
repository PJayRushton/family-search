import Foundation

struct PersonID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct PersonName: Hashable, Sendable {
    let given: String
    let surname: String

    var fullName: String {
        [given, surname].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct LifeEvent: Hashable, Sendable {
    let date: String
    let year: Int
    let place: String
}

struct PortraitReference: Hashable, Sendable {
    let key: String
    let remoteURL: URL
}

struct PersonSummary: Identifiable, Hashable, Sendable {
    let id: PersonID
    let name: PersonName
    let isLiving: Bool
    let birth: LifeEvent
    let death: LifeEvent?
    let portrait: PortraitReference?

    var lifespan: String {
        let ending = death.map { String($0.year) } ?? "Living"
        return "\(birth.year)–\(ending)"
    }
}

struct RelativeSummary: Identifiable, Hashable, Sendable {
    let id: PersonID
    let relationship: Relationship
    let name: PersonName
    let birthYear: Int
    let deathYear: Int?
}

enum Relationship: String, Hashable, Sendable {
    case father, mother, spouse, son, daughter
}

struct PersonProfile: Identifiable, Hashable, Sendable {
    let summary: PersonSummary
    let occupation: String?
    let biography: String
    let relatives: [RelativeSummary]

    var id: PersonID { summary.id }
}
