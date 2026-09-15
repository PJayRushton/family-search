import Foundation
import XCTest
@testable import FamilySearch

@MainActor
final class PersonProfileViewModelTests: XCTestCase {
    func testCachedProfileIsShownBeforeFreshProfile() async {
        let cached = Self.profile(name: "Cached Ezra")
        let fresh = Self.profile(name: "Fresh Ezra")
        let repository = ProfileRepositoryFake(plans: [
            .snapshots([
                .init(delay: .zero, snapshot: .cached(cached)),
                .init(delay: .milliseconds(80), snapshot: .fresh(fresh))
            ])
        ])
        let viewModel = makeViewModel(repository: repository)

        let load = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(10))

        guard case let .content(profile, isStale, notice) = viewModel.state else {
            load.cancel()
            return XCTFail("Expected cached content while refresh was pending")
        }
        XCTAssertEqual(profile.name, "Cached Ezra")
        XCTAssertTrue(isStale)
        XCTAssertEqual(notice, "Refreshing…")

        await load.value
        guard case let .content(profile, isStale, notice) = viewModel.state else {
            return XCTFail("Expected fresh content")
        }
        XCTAssertEqual(profile.name, "Fresh Ezra")
        XCTAssertFalse(isStale)
        XCTAssertNil(notice)
    }

    func testStaleSnapshotKeepsCachedProfileAndExplainsRefreshFailure() async {
        let repository = ProfileRepositoryFake(plans: [
            .snapshots([.init(delay: .zero, snapshot: .stale(
                Self.profile(), .refreshFailed(message: "Offline")
            ))])
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        guard case let .content(_, isStale, notice) = viewModel.state else {
            return XCTFail("Expected usable stale content")
        }
        XCTAssertTrue(isStale)
        XCTAssertEqual(notice, "Offline")
    }

    func testNoCacheFailureThenRetrySucceeds() async {
        let repository = ProfileRepositoryFake(plans: [
            .failure(.unavailable),
            .snapshots([.init(delay: .zero, snapshot: .fresh(Self.profile()))])
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()
        XCTAssertEqual(viewModel.state, .failure(message: PeopleRepositoryError.unavailable.localizedDescription))

        await viewModel.load()
        guard case .content = viewModel.state else { return XCTFail("Expected retry content") }
    }

    func testLivingProfileOmitsDeathAndMissingOccupation() async {
        let living = Self.profile(isLiving: true, death: nil, occupation: nil)
        let repository = ProfileRepositoryFake(plans: [
            .snapshots([.init(delay: .zero, snapshot: .fresh(living))])
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        guard case let .content(profile, _, _) = viewModel.state else {
            return XCTFail("Expected living profile")
        }
        XCTAssertNil(profile.death)
        XCTAssertNil(profile.occupation)
    }

    func testRelativeRowsPreserveStableIdentityOnly() async {
        let repository = ProfileRepositoryFake(plans: [
            .snapshots([.init(delay: .zero, snapshot: .fresh(Self.profile()))])
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        guard case let .content(profile, _, _) = viewModel.state else {
            return XCTFail("Expected profile")
        }
        XCTAssertEqual(profile.relatives, [
            RelativeRowPresentationModel(
                id: PersonID(rawValue: "RELATIVE-1"), relationship: "Spouse",
                name: "Ada Whitcomb", lifespan: "1871–Living"
            )
        ])
        XCTAssertEqual(AppRoute.profile(profile.relatives[0].id), .profile(PersonID(rawValue: "RELATIVE-1")))
    }

    func testCancellationDoesNotBecomeFailure() async {
        let repository = ProfileRepositoryFake(plans: [
            .snapshots([.init(delay: .milliseconds(100), snapshot: .fresh(Self.profile()))])
        ])
        let viewModel = makeViewModel(repository: repository)
        let load = Task { await viewModel.load() }

        await Task.yield()
        load.cancel()
        await load.value

        XCTAssertEqual(viewModel.state, .loading)
    }

    func testSupersededResponseCannotReplaceNewerRetry() async {
        let repository = ProfileRepositoryFake(plans: [
            .snapshots([.init(delay: .milliseconds(80), snapshot: .fresh(Self.profile(name: "Old")))]),
            .snapshots([.init(delay: .zero, snapshot: .fresh(Self.profile(name: "New")))])
        ])
        let viewModel = makeViewModel(repository: repository)
        let firstLoad = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(10))

        await viewModel.load()
        await firstLoad.value

        guard case let .content(profile, _, _) = viewModel.state else {
            return XCTFail("Expected the newer retry result")
        }
        XCTAssertEqual(profile.name, "New")
    }

    private func makeViewModel(repository: ProfileRepositoryFake) -> PersonProfileViewModel {
        PersonProfileViewModel(
            personID: Self.id,
            repository: repository,
            portraitRepository: PortraitRepositoryFake(data: Data([1, 2, 3]))
        )
    }

    private static let id = PersonID(rawValue: "PERSON-1")

    private static func profile(
        name: String = "Ezra Whitcomb",
        isLiving: Bool = false,
        death: LifeEvent? = LifeEvent(date: "3 November 1941", year: 1941, place: "Ogden"),
        occupation: String? = "Carpenter"
    ) -> PersonProfile {
        let names = name.split(separator: " ", maxSplits: 1).map(String.init)
        return PersonProfile(
            summary: PersonSummary(
                id: id,
                name: PersonName(given: names.first ?? "", surname: names.count > 1 ? names[1] : ""),
                isLiving: isLiving,
                birth: LifeEvent(date: "12 March 1868", year: 1868, place: "Nauvoo"),
                death: death,
                portrait: PortraitReference(key: "portrait", remoteURL: URL(string: "https://example.com/p.jpg")!)
            ),
            occupation: occupation,
            biography: "Biography",
            relatives: [RelativeSummary(
                id: PersonID(rawValue: "RELATIVE-1"), relationship: .spouse,
                name: PersonName(given: "Ada", surname: "Whitcomb"),
                birthYear: 1871, deathYear: nil
            )]
        )
    }
}

private struct PortraitRepositoryFake: PortraitRepository {
    let data: Data?
    func data(for portrait: PortraitReference) async throws -> Data? { data }
}

private final class ProfileRepositoryFake: PeopleRepository, @unchecked Sendable {
    struct TimedSnapshot: Sendable {
        let delay: Duration
        let snapshot: RepositorySnapshot<PersonProfile>
    }

    enum Plan: Sendable {
        case snapshots([TimedSnapshot])
        case failure(PeopleRepositoryError)
    }

    private let lock = NSLock()
    private let plans: [Plan]
    private var callCount = 0

    init(plans: [Plan]) { self.plans = plans }

    func people() -> AsyncThrowingStream<RepositorySnapshot<[PersonSummary]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func profile(id: PersonID) -> AsyncThrowingStream<RepositorySnapshot<PersonProfile>, Error> {
        let plan = lock.withLock {
            defer { callCount += 1 }
            return plans[min(callCount, plans.count - 1)]
        }
        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    switch plan {
                    case let .snapshots(events):
                        for event in events {
                            try await Task.sleep(for: event.delay)
                            continuation.yield(event.snapshot)
                        }
                        continuation.finish()
                    case let .failure(error):
                        continuation.finish(throwing: error)
                    }
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }
}
