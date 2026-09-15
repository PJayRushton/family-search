import Foundation
import SwiftData

/// Fetches people from the API, saves them to SwiftData, and returns the saved values.
@ModelActor
actor LivePeopleRepository: PeopleRepository {
    private var recordsClient: (any RecordsClient)? = nil
    private var seedProfiles: [PersonProfile] = []

    init(
        modelContainer: ModelContainer,
        recordsClient: (any RecordsClient)? = nil,
        seedProfiles: [PersonProfile] = []
    ) {
        let context = ModelContext(modelContainer)
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = modelContainer
        self.recordsClient = recordsClient
        self.seedProfiles = seedProfiles
    }

    /// Production repository backed by the app's persistent SwiftData store.
    nonisolated static func makePersistent(
        recordsClient: any RecordsClient
    ) throws -> LivePeopleRepository {
        try LivePeopleRepository(
            modelContainer: ModelContainer(for: PersonEntity.self, RelativeEntity.self),
            recordsClient: recordsClient
        )
    }

    /// Disk-backed repository at a controlled URL, used to test closing and reopening the store.
    nonisolated static func makePersistent(at url: URL) throws -> LivePeopleRepository {
        let configuration = ModelConfiguration(url: url)
        return try LivePeopleRepository(
            modelContainer: ModelContainer(
                for: PersonEntity.self, RelativeEntity.self, configurations: configuration
            )
        )
    }

    /// Disposable repository for unit tests and previews.
    nonisolated static func makeInMemory(
        recordsClient: (any RecordsClient)? = nil,
        seedProfiles: [PersonProfile] = []
    ) throws -> LivePeopleRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try LivePeopleRepository(
            modelContainer: ModelContainer(
                for: PersonEntity.self, RelativeEntity.self, configurations: configuration
            ),
            recordsClient: recordsClient,
            seedProfiles: seedProfiles
        )
    }

    func loadPeople() async throws -> RepositoryResult<[PersonSummary]> {
        try seedIfNeeded()
        guard let recordsClient else { return RepositoryResult(try summaries()) }

        do {
            let remotePeople = try await recordsClient.fetchPeople()
            try Task.checkCancellation()
            try upsert(summaries: remotePeople)
            try Task.checkCancellation()
            return RepositoryResult(try summaries())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let savedPeople = try summaries()
            guard !savedPeople.isEmpty else { throw error }
            return RepositoryResult(savedPeople, refreshIssue: Self.refreshIssue(from: error))
        }
    }

    func loadProfile(id: PersonID) async throws -> RepositoryResult<PersonProfile> {
        try seedIfNeeded()
        guard let recordsClient else {
            guard let savedProfile = try profile(id: id) else {
                throw PeopleRepositoryError.notFound(id)
            }
            return RepositoryResult(savedProfile)
        }

        do {
            let remoteProfile = try await recordsClient.fetchProfile(id: id)
            try Task.checkCancellation()
            try upsert(profile: remoteProfile)
            try Task.checkCancellation()
            guard let persistedProfile = try profile(id: id) else {
                throw PeopleRepositoryError.notFound(id)
            }
            return RepositoryResult(persistedProfile)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let savedProfile = try profile(id: id) else { throw error }
            return RepositoryResult(savedProfile, refreshIssue: Self.refreshIssue(from: error))
        }
    }

    func summaries() throws -> [PersonSummary] {
        let descriptor = FetchDescriptor<PersonEntity>(
            predicate: #Predicate { $0.isInPeopleList == true },
            sortBy: [SortDescriptor(\PersonEntity.surname), SortDescriptor(\PersonEntity.givenName)]
        )
        return try modelContext.fetch(descriptor).compactMap(\.summary)
    }

    /// This predicate is executed by SwiftData, so a single lookup does not load the whole table.
    func summary(id: PersonID) throws -> PersonSummary? { try entity(id: id)?.summary }

    func profile(id: PersonID) throws -> PersonProfile? { try entity(id: id)?.profile }

    func upsert(summaries: [PersonSummary]) throws {
        let listed = try modelContext.fetch(
            FetchDescriptor<PersonEntity>(predicate: #Predicate { $0.isInPeopleList == true })
        )
        for entity in listed { entity.isInPeopleList = false }
        for summary in summaries {
            if let existing = try entity(id: summary.id) {
                apply(summary, to: existing)
                existing.isInPeopleList = true
            } else {
                let record = makeEntity(from: summary)
                record.isInPeopleList = true
                modelContext.insert(record)
            }
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

    private func seedIfNeeded() throws {
        for profile in seedProfiles { try upsert(profile: profile) }
        if !seedProfiles.isEmpty { try upsert(summaries: seedProfiles.map(\.summary)) }
    }

    private func entity(id: PersonID) throws -> PersonEntity? {
        let rawID = id.rawValue
        var descriptor = FetchDescriptor<PersonEntity>(predicate: #Predicate { $0.personID == rawID })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func makeEntity(from summary: PersonSummary) -> PersonEntity {
        let entity = PersonEntity(
            personID: summary.id.rawValue, givenName: summary.name.given,
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
        RelativeEntity(
            personID: relative.id.rawValue, relationship: relative.relationship.rawValue,
            givenName: relative.name.given, surname: relative.name.surname,
            birthYear: relative.birthYear, deathYear: relative.deathYear)
    }

    private static func refreshIssue(from error: Error) -> RepositoryIssue {
        let message =
            (error as? LocalizedError)?.errorDescription
            ?? "Saved data is shown because the latest records could not be loaded."
        return .refreshFailed(message: message)
    }
}
