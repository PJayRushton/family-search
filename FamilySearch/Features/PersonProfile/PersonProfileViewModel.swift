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
    let portraitData: Data?
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
    private let portraitRepository: any PortraitRepository
    // Each destination owns a generation so late work cannot update a newer retry.
    private var loadGeneration = 0

    init(
        personID: PersonID,
        repository: any PeopleRepository,
        portraitRepository: any PortraitRepository
    ) {
        self.personID = personID
        self.repository = repository
        self.portraitRepository = portraitRepository
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading

        do {
            for try await snapshot in repository.profile(id: personID) {
                try Task.checkCancellation()
                let mapped = await map(snapshot)
                try Task.checkCancellation()
                guard generation == loadGeneration else { return }
                state = mapped
            }
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

    private func map(_ snapshot: RepositorySnapshot<PersonProfile>) async -> State {
        switch snapshot {
        case let .cached(profile):
            return .content(profile: await makePresentation(from: profile),
                            isStale: true, notice: "Refreshing…")
        case let .fresh(profile):
            return .content(profile: await makePresentation(from: profile),
                            isStale: false, notice: nil)
        case let .stale(profile, issue):
            let notice = switch issue {
            case let .refreshFailed(message): message
            }
            return .content(profile: await makePresentation(from: profile),
                            isStale: true, notice: notice)
        }
    }

    private func makePresentation(from profile: PersonProfile) async -> PersonProfilePresentationModel {
        let portraitData: Data?
        if let portrait = profile.summary.portrait {
            portraitData = try? await portraitRepository.data(for: portrait)
        } else {
            portraitData = nil
        }

        return PersonProfilePresentationModel(
            id: profile.id,
            name: profile.summary.name.fullName,
            portraitData: portraitData,
            birth: LifeEventPresentationModel(date: profile.summary.birth.date,
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
