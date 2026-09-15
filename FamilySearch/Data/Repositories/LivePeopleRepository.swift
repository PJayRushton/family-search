import Foundation

/// Coordinates refreshes, but only emits values read back from SwiftData.
struct LivePeopleRepository: PeopleRepository {
    private let recordsClient: any RecordsClient
    private let store: SwiftDataPeopleStore

    init(recordsClient: any RecordsClient, store: SwiftDataPeopleStore) {
        self.recordsClient = recordsClient
        self.store = store
    }

    func people() -> AsyncThrowingStream<RepositorySnapshot<[PersonSummary]>, Error> {
        AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    let savedPeople = try await store.summaries()
                    if !savedPeople.isEmpty { continuation.yield(.cached(savedPeople)) }

                    do {
                        let remotePeople = try await recordsClient.fetchPeople()
                        try Task.checkCancellation()
                        try await store.upsert(summaries: remotePeople)
                        try Task.checkCancellation()
                        continuation.yield(.fresh(try await store.summaries()))
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        if savedPeople.isEmpty { throw error }
                        continuation.yield(.stale(savedPeople, Self.refreshIssue(from: error)))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }

    func profile(id: PersonID) -> AsyncThrowingStream<RepositorySnapshot<PersonProfile>, Error> {
        AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    let savedProfile = try await store.profile(id: id)
                    if let savedProfile { continuation.yield(.cached(savedProfile)) }

                    do {
                        let remoteProfile = try await recordsClient.fetchProfile(id: id)
                        try Task.checkCancellation()
                        try await store.upsert(profile: remoteProfile)
                        try Task.checkCancellation()
                        guard let persistedProfile = try await store.profile(id: id) else {
                            throw PeopleRepositoryError.notFound(id)
                        }
                        continuation.yield(.fresh(persistedProfile))
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        guard let savedProfile else { throw error }
                        continuation.yield(.stale(savedProfile, Self.refreshIssue(from: error)))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }

    private static func refreshIssue(from error: Error) -> RepositoryIssue {
        let message = (error as? LocalizedError)?.errorDescription
            ?? "Saved data is shown because the latest records could not be loaded."
        return .refreshFailed(message: message)
    }
}
