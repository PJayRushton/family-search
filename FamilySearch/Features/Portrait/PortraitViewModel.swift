import Foundation
import Observation

@MainActor
@Observable
final class PortraitViewModel {
    enum State: Equatable {
        case placeholder
        case loading
        case image(Data)
        case failure
    }

    private(set) var state: State = .placeholder

    private let portrait: PortraitReference?
    private let repository: any PortraitRepository
    private var loadGeneration = 0

    init(portrait: PortraitReference?, repository: any PortraitRepository) {
        self.portrait = portrait
        self.repository = repository
    }

    func load() async {
        guard let portrait else {
            state = .placeholder
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading

        do {
            let data = try await repository.data(for: portrait)
            guard generation == loadGeneration, !Task.isCancelled else { return }
            state = data.map(State.image) ?? .placeholder
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            state = .failure
        }
    }

    func cancel() {
        loadGeneration += 1
    }
}
