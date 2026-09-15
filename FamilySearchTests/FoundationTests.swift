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
        let viewModel = PeopleListViewModel(repository: PeopleRepositoryFake(snapshots: [.fresh([person])]))

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
}

private struct PeopleRepositoryFake: PeopleRepository {
    let snapshots: [RepositorySnapshot<[PersonSummary]>]

    func people() -> AsyncThrowingStream<RepositorySnapshot<[PersonSummary]>, Error> {
        AsyncThrowingStream { continuation in
            snapshots.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func profile(id: PersonID) -> AsyncThrowingStream<RepositorySnapshot<PersonProfile>, Error> {
        AsyncThrowingStream { $0.finish(throwing: PeopleRepositoryError.notFound(id)) }
    }
}

private extension PersonSummary {
    static func fixture() -> PersonSummary {
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
