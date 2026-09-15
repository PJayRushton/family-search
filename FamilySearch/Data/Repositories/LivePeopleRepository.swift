import Foundation

/// Refreshes remote records, then returns only values read from SwiftData.
struct LivePeopleRepository: PeopleRepository {
    private let recordsClient: any RecordsClient
    private let store: SwiftDataPeopleStore

    init(recordsClient: any RecordsClient, store: SwiftDataPeopleStore) {
        self.recordsClient = recordsClient
        self.store = store
    }

    func loadPeople() async throws -> RepositoryResult<[PersonSummary]> {
        do {
            let remotePeople = try await recordsClient.fetchPeople()
            try Task.checkCancellation()
            try await store.upsert(summaries: remotePeople)
            try Task.checkCancellation()
            return RepositoryResult(try await store.summaries())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let savedPeople = try await store.summaries()
            guard !savedPeople.isEmpty else { throw error }
            return RepositoryResult(savedPeople, refreshIssue: Self.refreshIssue(from: error))
        }
    }

    func loadProfile(id: PersonID) async throws -> RepositoryResult<PersonProfile> {
        do {
            let remoteProfile = try await recordsClient.fetchProfile(id: id)
            try Task.checkCancellation()
            try await store.upsert(profile: remoteProfile)
            try Task.checkCancellation()
            guard let persistedProfile = try await store.profile(id: id) else {
                throw PeopleRepositoryError.notFound(id)
            }
            return RepositoryResult(persistedProfile)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let savedProfile = try await store.profile(id: id) else { throw error }
            return RepositoryResult(savedProfile, refreshIssue: Self.refreshIssue(from: error))
        }
    }

    private static func refreshIssue(from error: Error) -> RepositoryIssue {
        let message = (error as? LocalizedError)?.errorDescription
            ?? "Saved data is shown because the latest records could not be loaded."
        return .refreshFailed(message: message)
    }
}
