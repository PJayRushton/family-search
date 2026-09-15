import Foundation

enum RepositoryIssue: Hashable, Sendable {
    case refreshFailed(message: String)
}

/// Lets a repository publish saved data first, then replace or annotate it after refresh.
enum RepositorySnapshot<Value: Sendable>: Sendable {
    case cached(Value)
    case fresh(Value)
    case stale(Value, RepositoryIssue)
}

protocol PeopleRepository: Sendable {
    /// Cache/network policy stays here so view models never coordinate data sources.
    func people() -> AsyncThrowingStream<RepositorySnapshot<[PersonSummary]>, Error>
    func profile(id: PersonID) -> AsyncThrowingStream<RepositorySnapshot<PersonProfile>, Error>
}

protocol PortraitRepository: Sendable {
    func data(for portrait: PortraitReference) async throws -> Data?
}

enum PeopleRepositoryError: LocalizedError, Equatable, Sendable {
    case notFound(PersonID)
    case unavailable

    var errorDescription: String? {
        switch self {
        case let .notFound(id):
            "No saved or remote record was found for \(id.rawValue)."
        case .unavailable:
            "People could not be loaded. Check your connection and try again."
        }
    }
}
