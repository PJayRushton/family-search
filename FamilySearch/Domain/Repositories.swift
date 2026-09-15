import Foundation

enum RepositoryIssue: Hashable, Sendable {
    case refreshFailed(message: String)
}

struct RepositoryResult<Value: Sendable>: Sendable {
    let value: Value
    let refreshIssue: RepositoryIssue?

    init(_ value: Value, refreshIssue: RepositoryIssue? = nil) {
        self.value = value
        self.refreshIssue = refreshIssue
    }
}

protocol PeopleRepository: Sendable {
    func loadPeople() async throws -> RepositoryResult<[PersonSummary]>
    func loadProfile(id: PersonID) async throws -> RepositoryResult<PersonProfile>
}

protocol PortraitRepository: Sendable {
    func data(for portrait: PortraitReference) async throws -> Data?
}

enum PeopleRepositoryError: LocalizedError, Equatable, Sendable {
    case notFound(PersonID)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            "No saved or remote record was found for \(id.rawValue)."
        case .unavailable:
            "People could not be loaded. Check your connection and try again."
        }
    }
}
