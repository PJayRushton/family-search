import Foundation

extension PersonEntity {
    var summary: PersonSummary? {
        let portrait: PortraitReference?
        if let portraitKey, let portraitRemoteURL, let url = URL(string: portraitRemoteURL) {
            portrait = PortraitReference(key: portraitKey, remoteURL: url)
        } else {
            portrait = nil
        }
        let death: LifeEvent?
        if let deathDate, let deathYear, let deathPlace {
            death = LifeEvent(date: deathDate, year: deathYear, place: deathPlace)
        } else {
            death = nil
        }
        return PersonSummary(
            id: PersonID(rawValue: personID), name: PersonName(given: givenName, surname: surname),
            isLiving: isLiving, birth: LifeEvent(date: birthDate, year: birthYear, place: birthPlace),
            death: death, portrait: portrait
        )
    }

    var profile: PersonProfile? {
        guard hasFetchedProfile, let summary, let biography else { return nil }
        let mappedRelatives = relatives.compactMap(\.relative).sorted { $0.name.fullName < $1.name.fullName }
        guard mappedRelatives.count == relatives.count else { return nil }
        return PersonProfile(summary: summary, occupation: occupation, biography: biography,
                             relatives: mappedRelatives)
    }
}

private extension RelativeEntity {
    var relative: RelativeSummary? {
        guard let relationship = Relationship(rawValue: relationship) else { return nil }
        return RelativeSummary(id: PersonID(rawValue: personID), relationship: relationship,
                               name: PersonName(given: givenName, surname: surname),
                               birthYear: birthYear, deathYear: deathYear)
    }
}
