import Foundation
import Observation

struct LifeEventPresentationModel: Equatable {
    let date: String
    let place: String
}

struct RelativeRowPresentationModel: Identifiable, Equatable {
    let id: PersonID
    let relationship: String
    let name: String
    let lifespan: String
}

struct PersonProfilePresentationModel: Identifiable, Equatable {
    let id: PersonID
    let name: String
    let portrait: PortraitReference?
    let birth: LifeEventPresentationModel
    let death: LifeEventPresentationModel?
    let occupation: String?
    let biography: String
    let relatives: [RelativeRowPresentationModel]
}

@MainActor
@Observable
final class PersonProfileViewModel {
    enum State: Equatable {
        case idle
        case loading
        case content(profile: PersonProfilePresentationModel, isStale: Bool, notice: String?)
        case failure(message: String)
    }

    private(set) var state: State = .idle
    let personID: PersonID

    private let repository: any PeopleRepository
    // Each destination owns a generation so late work cannot update a newer retry.
    private var loadGeneration = 0

    init(
        personID: PersonID,
        repository: any PeopleRepository
    ) {
        self.personID = personID
        self.repository = repository
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading

        do {
            let result = try await repository.loadProfile(id: personID)
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }
            state = map(result)
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            state = .failure(message: Self.message(for: error))
        }
    }

    func cancel() {
        loadGeneration += 1
    }

    private func map(_ result: RepositoryResult<PersonProfile>) -> State {
        let notice = result.refreshIssue.map { issue in
            switch issue {
            case .refreshFailed(let message): message
            }
        }
        return .content(
            profile: makePresentation(from: result.value),
            isStale: result.refreshIssue != nil,
            notice: notice)
    }

    private func makePresentation(from profile: PersonProfile) -> PersonProfilePresentationModel {
        PersonProfilePresentationModel(
            id: profile.id,
            name: profile.summary.name.fullName,
            portrait: profile.summary.portrait,
            birth: LifeEventPresentationModel(
                date: profile.summary.birth.date,
                place: profile.summary.birth.place),
            death: profile.summary.death.map {
                LifeEventPresentationModel(date: $0.date, place: $0.place)
            },
            occupation: profile.occupation,
            biography: profile.biography,
            relatives: profile.relatives.map(Self.makeRelative)
        )
    }

    private static func makeRelative(_ relative: RelativeSummary) -> RelativeRowPresentationModel {
        let ending = relative.deathYear.map(String.init) ?? "Living"
        return RelativeRowPresentationModel(
            id: relative.id,
            relationship: relative.relationship.rawValue.capitalized,
            name: relative.name.fullName,
            lifespan: "\(relative.birthYear)–\(ending)"
        )
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "This profile could not be loaded. Please try again."
    }
}
