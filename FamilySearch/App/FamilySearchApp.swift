import Foundation
import SwiftUI

@main
struct FamilySearchApp: App {
    private let peopleRepository: any PeopleRepository
    private let portraitRepository: any PortraitRepository

    init() {
        do {
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

            peopleRepository = try LivePeopleRepository.makePersistent(recordsClient: recordsClient)
            portraitRepository = LivePortraitRepository(
                client: URLSessionPortraitClient(),
                store: try FilePortraitStore.applicationSupport()
            )
        } catch {
            preconditionFailure("The app's persistent storage could not be created: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                peopleRepository: peopleRepository,
                portraitRepository: portraitRepository
            )
        }
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
