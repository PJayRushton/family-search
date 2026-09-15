import Foundation
import XCTest

@testable import FamilySearch

@MainActor
final class LiveRepositoryTests: XCTestCase {
    func testPeoplePersistsAndRereadsRemoteRecords() async throws {
        let store = try SwiftDataPeopleStore.makeInMemory()
        let cached = Self.person(id: "CACHED", given: "Beth", surname: "Cache")
        try await store.upsert(summaries: [cached])
        let zulu = Self.person(id: "Z", given: "Zoe", surname: "Zulu")
        let alpha = Self.person(id: "A", given: "Amy", surname: "Alpha")
        let repository = LivePeopleRepository(
            recordsClient: RecordsClientFake(peopleResult: .success([zulu, alpha])),
            store: store
        )

        let result = try await repository.loadPeople()

        XCTAssertNil(result.refreshIssue)
        // SwiftData applies its surname sort, proving network values did not bypass the store.
        XCTAssertEqual(result.value.map(\.id), [alpha.id, zulu.id])
        let storedAlpha = try await store.summary(id: alpha.id)
        XCTAssertEqual(storedAlpha, alpha)
    }

    func testPeopleReturnsSavedDataWhenRefreshFails() async throws {
        let store = try SwiftDataPeopleStore.makeInMemory()
        let cached = Self.person(id: "CACHED", given: "Beth", surname: "Cache")
        try await store.upsert(summaries: [cached])
        let repository = LivePeopleRepository(
            recordsClient: RecordsClientFake(peopleResult: .failure(TestError.offline)),
            store: store
        )

        let result = try await repository.loadPeople()

        XCTAssertEqual(result.value, [cached])
        XCTAssertNotNil(result.refreshIssue)
    }

    func testPeopleThrowsOnFirstLaunchWhenRefreshFails() async {
        let store = try! SwiftDataPeopleStore.makeInMemory()
        let repository = LivePeopleRepository(
            recordsClient: RecordsClientFake(peopleResult: .failure(TestError.offline)),
            store: store
        )

        do {
            _ = try await repository.loadPeople()
            XCTFail("Expected first-launch failure")
        } catch {
            XCTAssertEqual(error as? TestError, .offline)
        }
    }

    func testPortraitRepositoryPersistsDownloadedBytesForOfflineRead() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FilePortraitStore(directory: directory)
        let bytes = try XCTUnwrap(
            Data(
                base64Encoded:
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
            ))
        let client = PortraitClientSpy(result: .success(bytes))
        let repository = LivePortraitRepository(client: client, store: store)
        let portrait = PortraitReference(
            key: "portraits/A.jpg",
            remoteURL: URL(string: "https://example.test/portraits/A.jpg")!
        )

        let downloadedData = try await repository.data(for: portrait)
        XCTAssertEqual(downloadedData, bytes)
        let offlineRepository = LivePortraitRepository(
            client: PortraitClientSpy(result: .failure(TestError.offline)),
            store: FilePortraitStore(directory: directory)
        )
        let savedData = try await offlineRepository.data(for: portrait)
        let requestCount = await client.requestCount
        XCTAssertEqual(savedData, bytes)
        XCTAssertEqual(requestCount, 1)
    }

    func testSupersededViewModelLoadCannotOverwriteNewerContent() async {
        let repository = ControlledPeopleRepository()
        let viewModel = PeopleListViewModel(repository: repository)
        let olderLoad = Task { await viewModel.load() }
        await repository.waitForRequestCount(1)
        let newerLoad = Task { await viewModel.load() }
        await repository.waitForRequestCount(2)
        let newer = Self.person(id: "NEW", given: "New", surname: "Result")
        let older = Self.person(id: "OLD", given: "Old", surname: "Result")

        repository.finishRequest(at: 1, with: RepositoryResult([newer]))
        await newerLoad.value
        repository.finishRequest(at: 0, with: RepositoryResult([older]))
        await olderLoad.value

        guard case .content(let rows, _, _) = viewModel.state else {
            return XCTFail("Expected content")
        }
        XCTAssertEqual(rows.map(\.id), [newer.id])
    }

    func testCancelledPortraitLoadDoesNotPublishLateData() async {
        let repository = ControlledPortraitRepository()
        let portrait = PortraitReference(
            key: "portrait", remoteURL: URL(string: "https://example.test/portrait")!
        )
        let viewModel = PortraitViewModel(portrait: portrait, repository: repository)
        let load = Task { await viewModel.load() }
        await repository.waitUntilRequested()

        viewModel.cancel()
        await repository.finish(with: Data([1, 2, 3]))
        await load.value

        XCTAssertEqual(viewModel.state, .loading)
    }

    private static func person(id: String, given: String, surname: String) -> PersonSummary {
        PersonSummary(
            id: PersonID(rawValue: id), name: PersonName(given: given, surname: surname),
            isLiving: true, birth: LifeEvent(date: "2000", year: 2000, place: "Place"),
            death: nil, portrait: nil
        )
    }
}

private enum TestError: Error, Equatable { case offline }

private struct RecordsClientFake: RecordsClient {
    let peopleResult: Result<[PersonSummary], Error>

    func fetchPeople() async throws -> [PersonSummary] { try peopleResult.get() }
    func fetchProfile(id: PersonID) async throws -> PersonProfile { throw TestError.offline }
}

private actor PortraitClientSpy: PortraitClient {
    private(set) var requestCount = 0
    let result: Result<Data, Error>

    init(result: Result<Data, Error>) { self.result = result }

    func fetchData(from url: URL) async throws -> Data {
        requestCount += 1
        return try result.get()
    }
}

private final class ControlledPeopleRepository: PeopleRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<RepositoryResult<[PersonSummary]>, Error>] = []

    func loadPeople() async throws -> RepositoryResult<[PersonSummary]> {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { continuations.append(continuation) }
        }
    }

    func loadProfile(id: PersonID) async throws -> RepositoryResult<PersonProfile> {
        throw TestError.offline
    }

    func waitForRequestCount(_ count: Int) async {
        while lock.withLock({ continuations.count }) < count { await Task.yield() }
    }

    func finishRequest(at index: Int, with result: RepositoryResult<[PersonSummary]>) {
        let continuation = lock.withLock { continuations[index] }
        continuation.resume(returning: result)
    }
}

private actor ControlledPortraitRepository: PortraitRepository {
    private var continuation: CheckedContinuation<Data?, Never>?

    func data(for portrait: PortraitReference) async throws -> Data? {
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilRequested() async {
        while continuation == nil { await Task.yield() }
    }

    func finish(with data: Data?) {
        continuation?.resume(returning: data)
        continuation = nil
    }
}
