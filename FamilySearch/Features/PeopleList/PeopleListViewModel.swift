import Foundation
import Observation

@MainActor
@Observable
final class PeopleListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case empty
        case content(people: [PersonSummary], isStale: Bool, notice: String?)
        case failure(message: String)
    }

    private(set) var state: State = .idle

    private let repository: any PeopleRepository
    // A retry supersedes earlier work even if an underlying dependency ignores cancellation.
    private var loadGeneration = 0

    init(repository: any PeopleRepository) {
        self.repository = repository
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading

        do {
            for try await snapshot in repository.people() {
                try Task.checkCancellation()
                guard generation == loadGeneration else { return }
                apply(snapshot)
            }
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            state = .failure(message: Self.message(for: error))
        }
    }

    func cancel() {
        loadGeneration += 1
    }

    private func apply(_ snapshot: RepositorySnapshot<[PersonSummary]>) {
        switch snapshot {
        case let .fresh(people):
            state = people.isEmpty ? .empty : .content(people: people, isStale: false, notice: nil)
        case let .cached(people):
            state = people.isEmpty ? .loading : .content(people: people, isStale: true, notice: "Refreshing…")
        case let .stale(people, issue):
            let notice = switch issue {
            case let .refreshFailed(message): message
            }
            state = people.isEmpty
                ? .failure(message: notice)
                : .content(people: people, isStale: true, notice: notice)
        }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "Something went wrong. Please try again."
    }
}
