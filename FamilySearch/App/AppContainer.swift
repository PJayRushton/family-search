import Foundation

/// The only place in the app target that assembles concrete dependencies.
struct AppContainer {
    let peopleRepository: any PeopleRepository
    let portraitRepository: any PortraitRepository

    static func live() -> AppContainer {
        AppContainer(
            peopleRepository: BootstrapPeopleRepository(),
            portraitRepository: BootstrapPortraitRepository()
        )
    }

    @MainActor
    func makePeopleListViewModel() -> PeopleListViewModel {
        PeopleListViewModel(repository: peopleRepository)
    }
}

private struct BootstrapPeopleRepository: PeopleRepository {
    func people() -> AsyncThrowingStream<RepositorySnapshot<[PersonSummary]>, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.fresh([]))
            continuation.finish()
        }
    }

    func profile(id: PersonID) -> AsyncThrowingStream<RepositorySnapshot<PersonProfile>, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: PeopleRepositoryError.notFound(id))
        }
    }
}

private struct BootstrapPortraitRepository: PortraitRepository {
    func data(for portrait: PortraitReference) async throws -> Data? {
        nil
    }
}
