import XCTest

@testable import FamilySearch

@MainActor
final class FoundationTests: XCTestCase {
    func testDomainDerivesDisplayNameAndLifespan() {
        let person = PersonSummary.fixture()

        XCTAssertEqual(person.name.fullName, "Ezra Whitcomb")
        XCTAssertEqual(person.lifespan, "1868–1941")
    }

    func testViewModelMapsFreshPeopleToContent() async {
        let person = PersonSummary.fixture()
        let viewModel = PeopleListViewModel(repository: PeopleRepositoryFake(result: RepositoryResult([person])))

        await viewModel.load()

        XCTAssertEqual(
            viewModel.state,
            .content(
                rows: [
                    PeopleListRowModel(
                        id: person.id,
                        name: "Ezra Whitcomb",
                        lifespan: "1868–1941",
                        birthplace: "Nauvoo",
                        portrait: nil
                    )
                ],
                isStale: false,
                notice: nil
            )
        )
    }

    func testViewModelDistinguishesEmptyAndStaleStates() async {
        let person = PersonSummary.fixture()
        let emptyViewModel = PeopleListViewModel(
            repository: PeopleRepositoryFake(result: RepositoryResult([]))
        )
        let staleViewModel = PeopleListViewModel(
            repository: PeopleRepositoryFake(
                result: RepositoryResult(
                    [person], refreshIssue: .refreshFailed(message: "Offline")
                ))
        )

        await emptyViewModel.load()
        await staleViewModel.load()

        guard case .content(_, let staleIsStale, let staleNotice) = staleViewModel.state else {
            return XCTFail("Expected stale content state")
        }
        XCTAssertEqual(emptyViewModel.state, .empty)
        XCTAssertTrue(staleIsStale)
        XCTAssertEqual(staleNotice, "Offline")
    }

    func testLoadedListDoesNotReloadUntilExplicitRefresh() async {
        let person = PersonSummary.fixture()
        let repository = PeopleRepositorySpy(
            results: [
                RepositoryResult([person]),
                RepositoryResult(
                    [person],
                    refreshIssue: .refreshFailed(message: "Couldn't refresh. Showing saved people.")
                ),
            ])
        let viewModel = PeopleListViewModel(repository: repository)

        await viewModel.load()
        await viewModel.load()

        let loadCountAfterReappearing = await repository.loadCount()
        XCTAssertEqual(loadCountAfterReappearing, 1)

        await viewModel.refresh()

        let loadCountAfterRefreshing = await repository.loadCount()
        XCTAssertEqual(loadCountAfterRefreshing, 2)
        guard case .content(let rows, let isStale, let notice) = viewModel.state else {
            return XCTFail("Expected content to remain visible after refresh")
        }
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(isStale)
        XCTAssertEqual(notice, "Couldn't refresh. Showing saved people.")
    }

    func testNavigationPushesNewPeopleButCollapsesFamilyCycles() {
        let parentID = PersonID(rawValue: "PARENT")
        let childID = PersonID(rawValue: "CHILD")
        var path = AppRoute.path(afterSelecting: parentID, from: [])

        path = AppRoute.path(afterSelecting: childID, from: path)
        XCTAssertEqual(path, [.profile(parentID), .profile(childID)])

        path = AppRoute.path(afterSelecting: parentID, from: path)
        XCTAssertEqual(path, [.profile(parentID)])

        path = AppRoute.path(afterSelecting: parentID, from: path)
        XCTAssertEqual(path, [.profile(parentID)])
    }

}

private actor PeopleRepositorySpy: PeopleRepository {
    private var results: [RepositoryResult<[PersonSummary]>]
    private(set) var peopleLoadCount = 0

    init(results: [RepositoryResult<[PersonSummary]>]) {
        self.results = results
    }

    func loadPeople() async throws -> RepositoryResult<[PersonSummary]> {
        peopleLoadCount += 1
        return results.removeFirst()
    }

    func loadProfile(id: PersonID) async throws -> RepositoryResult<PersonProfile> {
        throw PeopleRepositoryError.notFound(id)
    }

    func loadCount() -> Int {
        peopleLoadCount
    }
}

private struct PeopleRepositoryFake: PeopleRepository {
    let result: RepositoryResult<[PersonSummary]>

    func loadPeople() async throws -> RepositoryResult<[PersonSummary]> {
        result
    }

    func loadProfile(id: PersonID) async throws -> RepositoryResult<PersonProfile> {
        throw PeopleRepositoryError.notFound(id)
    }
}

extension PersonSummary {
    fileprivate static func fixture() -> PersonSummary {
        PersonSummary(
            id: PersonID(rawValue: "L4RX-9FT"),
            name: PersonName(given: "Ezra", surname: "Whitcomb"),
            isLiving: false,
            birth: LifeEvent(date: "12 March 1868", year: 1868, place: "Nauvoo"),
            death: LifeEvent(date: "3 November 1941", year: 1941, place: "Ogden"),
            portrait: nil
        )
    }
}
