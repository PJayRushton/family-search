import Foundation
import SwiftData

/// Owns all SwiftData access. Callers exchange domain values, never persistence entities.
@ModelActor
actor SwiftDataPeopleStore {
    nonisolated static func makePersistent() throws -> SwiftDataPeopleStore {
        try SwiftDataPeopleStore(modelContainer: ModelContainer(for: PersonEntity.self, RelativeEntity.self))
    }

    nonisolated static func makePersistent(at url: URL) throws -> SwiftDataPeopleStore {
        let configuration = ModelConfiguration(url: url)
        return try SwiftDataPeopleStore(modelContainer: ModelContainer(
            for: PersonEntity.self, RelativeEntity.self, configurations: configuration
        ))
    }

    nonisolated static func makeInMemory() throws -> SwiftDataPeopleStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try SwiftDataPeopleStore(modelContainer: ModelContainer(
            for: PersonEntity.self, RelativeEntity.self, configurations: configuration
        ))
    }

    func summaries() throws -> [PersonSummary] {
        let descriptor = FetchDescriptor<PersonEntity>(
            sortBy: [SortDescriptor(\PersonEntity.surname), SortDescriptor(\PersonEntity.givenName)]
        )
        return try modelContext.fetch(descriptor).compactMap(\.summary)
    }

    /// The predicate becomes a store query; this does not load and scan the people table.
    func summary(id: PersonID) throws -> PersonSummary? { try entity(id: id)?.summary }
    func profile(id: PersonID) throws -> PersonProfile? { try entity(id: id)?.profile }

    func upsert(summaries: [PersonSummary]) throws {
        for summary in summaries {
            if let existing = try entity(id: summary.id) { apply(summary, to: existing) }
            else { modelContext.insert(makeEntity(from: summary)) }
        }
        try modelContext.save()
    }

    func upsert(profile: PersonProfile) throws {
        let record: PersonEntity
        if let existing = try entity(id: profile.id) {
            record = existing
            apply(profile.summary, to: record)
            record.relatives.forEach(modelContext.delete)
            record.relatives.removeAll()
        } else {
            record = makeEntity(from: profile.summary)
            modelContext.insert(record)
        }
        record.occupation = profile.occupation
        record.biography = profile.biography
        record.hasFetchedProfile = true
        record.relatives = profile.relatives.map(makeEntity(from:))
        try modelContext.save()
    }

    private func entity(id: PersonID) throws -> PersonEntity? {
        let rawID = id.rawValue
        var descriptor = FetchDescriptor<PersonEntity>(predicate: #Predicate { $0.personID == rawID })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func makeEntity(from summary: PersonSummary) -> PersonEntity {
        let entity = PersonEntity(personID: summary.id.rawValue, givenName: summary.name.given,
                                  surname: summary.name.surname, isLiving: summary.isLiving,
                                  birthDate: summary.birth.date, birthYear: summary.birth.year,
                                  birthPlace: summary.birth.place)
        apply(summary, to: entity)
        return entity
    }

    /// Summary refreshes deliberately leave profile-only fields and relatives intact.
    private func apply(_ summary: PersonSummary, to entity: PersonEntity) {
        entity.givenName = summary.name.given
        entity.surname = summary.name.surname
        entity.isLiving = summary.isLiving
        entity.birthDate = summary.birth.date
        entity.birthYear = summary.birth.year
        entity.birthPlace = summary.birth.place
        entity.deathDate = summary.death?.date
        entity.deathYear = summary.death?.year
        entity.deathPlace = summary.death?.place
        entity.portraitKey = summary.portrait?.key
        entity.portraitRemoteURL = summary.portrait?.remoteURL.absoluteString
    }

    private func makeEntity(from relative: RelativeSummary) -> RelativeEntity {
        RelativeEntity(personID: relative.id.rawValue, relationship: relative.relationship.rawValue,
                       givenName: relative.name.given, surname: relative.name.surname,
                       birthYear: relative.birthYear, deathYear: relative.deathYear)
    }
}

/// Local-only repository for previews and the stored-data half of the live repository.
struct StoredPeopleRepository: PeopleRepository {
    private let store: SwiftDataPeopleStore
    private let seedProfiles: [PersonProfile]

    init(store: SwiftDataPeopleStore, seedProfiles: [PersonProfile] = []) {
        self.store = store
        self.seedProfiles = seedProfiles
    }

    func people() -> AsyncThrowingStream<RepositorySnapshot<[PersonSummary]>, Error> {
        AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    try await seedIfNeeded()
                    guard !Task.isCancelled else { return }
                    continuation.yield(.cached(try await store.summaries()))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }

    func profile(id: PersonID) -> AsyncThrowingStream<RepositorySnapshot<PersonProfile>, Error> {
        AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    try await seedIfNeeded()
                    guard !Task.isCancelled else { return }
                    guard let profile = try await store.profile(id: id) else {
                        continuation.finish(throwing: PeopleRepositoryError.notFound(id)); return
                    }
                    continuation.yield(.cached(profile)); continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }

    private func seedIfNeeded() async throws {
        for profile in seedProfiles { try await store.upsert(profile: profile) }
    }
}
