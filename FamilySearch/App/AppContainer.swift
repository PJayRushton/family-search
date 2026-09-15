import Foundation

/// The only place in the app target that assembles concrete dependencies.
struct AppContainer {
    let peopleRepository: any PeopleRepository
    let portraitRepository: any PortraitRepository

    @MainActor
    static func live() -> AppContainer {
        do {
            let store = try SwiftDataPeopleStore.makePersistent()
            return AppContainer(
                peopleRepository: StoredPeopleRepository(store: store),
                portraitRepository: try FilePortraitStore.applicationSupport()
            )
        } catch {
            preconditionFailure("The persistent app container could not be created: \(error)")
        }
    }

    @MainActor
    func makePeopleListViewModel() -> PeopleListViewModel {
        PeopleListViewModel(repository: peopleRepository)
    }
}
