import Foundation
import XCTest

@testable import FamilySearch

@MainActor
final class PersonProfileViewModelTests: XCTestCase {
    func testProfileMapsRepositoryResult() async {
        let repository = ProfileRepositoryFake(plans: [
            .result(delay: .zero, result: RepositoryResult(Self.profile(name: "Fresh Ezra")))
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()
        guard case .content(let profile, let isStale, let notice) = viewModel.state else {
            return XCTFail("Expected fresh content")
        }
        XCTAssertEqual(profile.name, "Fresh Ezra")
        XCTAssertFalse(isStale)
        XCTAssertNil(notice)
    }

    func testStaleResultKeepsCachedProfileAndExplainsRefreshFailure() async {
        let repository = ProfileRepositoryFake(plans: [
            .result(
                delay: .zero,
                result: RepositoryResult(
                    Self.profile(), refreshIssue: .refreshFailed(message: "Offline")
                ))
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        guard case .content(_, let isStale, let notice) = viewModel.state else {
            return XCTFail("Expected usable stale content")
        }
        XCTAssertTrue(isStale)
        XCTAssertEqual(notice, "Offline")
    }

    func testNoCacheFailureThenRetrySucceeds() async {
        let repository = ProfileRepositoryFake(plans: [
            .failure(.unavailable),
            .result(delay: .zero, result: RepositoryResult(Self.profile())),
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
            .result(delay: .zero, result: RepositoryResult(living))
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        guard case .content(let profile, _, _) = viewModel.state else {
            return XCTFail("Expected living profile")
        }
        XCTAssertNil(profile.death)
        XCTAssertNil(profile.occupation)
        XCTAssertEqual(profile.portrait?.key, "portrait")
    }

    func testRelativeRowsPreserveStableIdentityOnly() async {
        let repository = ProfileRepositoryFake(plans: [
            .result(delay: .zero, result: RepositoryResult(Self.profile()))
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        guard case .content(let profile, _, _) = viewModel.state else {
            return XCTFail("Expected profile")
        }
        XCTAssertEqual(
            profile.relatives,
            [
                RelativeRowPresentationModel(
                    id: PersonID(rawValue: "RELATIVE-1"), relationship: "Spouse",
                    name: "Ada Whitcomb", lifespan: "1871–Living"
                )
            ])
        XCTAssertEqual(AppRoute.profile(profile.relatives[0].id), .profile(PersonID(rawValue: "RELATIVE-1")))
    }

    func testCancellationDoesNotBecomeFailure() async {
        let repository = ProfileRepositoryFake(plans: [
            .result(delay: .milliseconds(100), result: RepositoryResult(Self.profile()))
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
            .result(delay: .milliseconds(80), result: RepositoryResult(Self.profile(name: "Old"))),
            .result(delay: .zero, result: RepositoryResult(Self.profile(name: "New"))),
        ])
        let viewModel = makeViewModel(repository: repository)
        let firstLoad = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(10))

        await viewModel.load()
        await firstLoad.value

        guard case .content(let profile, _, _) = viewModel.state else {
            return XCTFail("Expected the newer retry result")
        }
        XCTAssertEqual(profile.name, "New")
    }

    private func makeViewModel(repository: ProfileRepositoryFake) -> PersonProfileViewModel {
        PersonProfileViewModel(
            personID: Self.id,
            repository: repository
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
            relatives: [
                RelativeSummary(
                    id: PersonID(rawValue: "RELATIVE-1"), relationship: .spouse,
                    name: PersonName(given: "Ada", surname: "Whitcomb"),
                    birthYear: 1871, deathYear: nil
                )
            ]
        )
    }
}

private final class ProfileRepositoryFake: PeopleRepository, @unchecked Sendable {
    enum Plan: Sendable {
        case result(delay: Duration, result: RepositoryResult<PersonProfile>)
        case failure(PeopleRepositoryError)
    }

    private let lock = NSLock()
    private let plans: [Plan]
    private var callCount = 0

    init(plans: [Plan]) { self.plans = plans }

    func loadPeople() async throws -> RepositoryResult<[PersonSummary]> {
        throw PeopleRepositoryError.unavailable
    }

    func loadProfile(id: PersonID) async throws -> RepositoryResult<PersonProfile> {
        let plan = lock.withLock {
            defer { callCount += 1 }
            return plans[min(callCount, plans.count - 1)]
        }
        switch plan {
        case .result(let delay, let result):
            try await Task.sleep(for: delay)
            return result
        case .failure(let error):
            throw error
        }
    }
}
