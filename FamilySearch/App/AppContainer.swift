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
            let recordsClient: any RecordsClient
            #if DEBUG
                // Makes force-quit/offline acceptance testing deterministic without changing Mac networking.
                recordsClient =
                    ProcessInfo.processInfo.environment["FAMILY_SEARCH_FORCE_OFFLINE"] == "1"
                    ? OfflineRecordsClient()
                    : URLSessionRecordsClient()
            #else
                recordsClient = URLSessionRecordsClient()
            #endif
            return AppContainer(
                peopleRepository: LivePeopleRepository(
                    recordsClient: recordsClient,
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
    func makePersonProfileViewModel(id: PersonID) -> PersonProfileViewModel {
        PersonProfileViewModel(
            personID: id,
            repository: peopleRepository
        )
    }

    @MainActor
    func makePortraitViewModel(portrait: PortraitReference?) -> PortraitViewModel {
        PortraitViewModel(portrait: portrait, repository: portraitRepository)
    }
}

#if DEBUG
    private struct OfflineRecordsClient: RecordsClient {
        func fetchPeople() async throws -> [PersonSummary] {
            throw RecordsClientError.transport("No network connection is available.")
        }

        func fetchProfile(id: PersonID) async throws -> PersonProfile {
            throw RecordsClientError.transport("No network connection is available.")
        }
    }
#endif
