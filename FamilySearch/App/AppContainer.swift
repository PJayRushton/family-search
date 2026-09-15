import Foundation

/// The only place in the app target that assembles concrete dependencies.
struct AppContainer {
    let peopleRepository: any PeopleRepository
    let portraitRepository: any PortraitRepository

    @MainActor
    static func live() -> AppContainer {
        do {
            let store = try SwiftDataPeopleStore.makePersistent()
            let portraitStore = try FilePortraitStore.applicationSupport()
            return AppContainer(
                peopleRepository: LivePeopleRepository(
                    recordsClient: URLSessionRecordsClient(),
                    store: store
                ),
                portraitRepository: LivePortraitRepository(
                    client: URLSessionPortraitClient(),
                    store: portraitStore
                )
            )
        } catch {
            preconditionFailure("The persistent app container could not be created: \(error)")
        }
    }

    @MainActor
    func makePeopleListViewModel() -> PeopleListViewModel {
        PeopleListViewModel(repository: peopleRepository)
    }

    @MainActor
    func makePortraitViewModel(portrait: PortraitReference?) -> PortraitViewModel {
        PortraitViewModel(portrait: portrait, repository: portraitRepository)
    }
}
