import Foundation
import SwiftData

@Model
final class PersonEntity {
    @Attribute(.unique) var personID: String
    var givenName: String
    var surname: String
    var isLiving: Bool
    var birthDate: String
    var birthYear: Int
    var birthPlace: String
    var deathDate: String?
    var deathYear: Int?
    var deathPlace: String?
    var portraitKey: String?
    var portraitRemoteURL: String?
    var occupation: String?
    var biography: String?
    var hasFetchedProfile: Bool
    /// Separates collection records from relatives fetched only through a profile.
    var isInPeopleList: Bool?
    @Relationship(deleteRule: .cascade, inverse: \RelativeEntity.person)
    var relatives: [RelativeEntity]

    init(
        personID: String, givenName: String, surname: String, isLiving: Bool, birthDate: String,
        birthYear: Int, birthPlace: String, deathDate: String? = nil, deathYear: Int? = nil,
        deathPlace: String? = nil, portraitKey: String? = nil, portraitRemoteURL: String? = nil,
        occupation: String? = nil, biography: String? = nil, hasFetchedProfile: Bool = false,
        isInPeopleList: Bool? = false,
        relatives: [RelativeEntity] = []
    ) {
        self.personID = personID
        self.givenName = givenName
        self.surname = surname
        self.isLiving = isLiving
        self.birthDate = birthDate
        self.birthYear = birthYear
        self.birthPlace = birthPlace
        self.deathDate = deathDate
        self.deathYear = deathYear
        self.deathPlace = deathPlace
        self.portraitKey = portraitKey
        self.portraitRemoteURL = portraitRemoteURL
        self.occupation = occupation
        self.biography = biography
        self.hasFetchedProfile = hasFetchedProfile
        self.isInPeopleList = isInPeopleList
        self.relatives = relatives
    }
}

@Model
final class RelativeEntity {
    var personID: String
    var relationship: String
    var givenName: String
    var surname: String
    var birthYear: Int
    var deathYear: Int?
    var person: PersonEntity?

    init(
        personID: String, relationship: String, givenName: String, surname: String,
        birthYear: Int, deathYear: Int?
    ) {
        self.personID = personID
        self.relationship = relationship
        self.givenName = givenName
        self.surname = surname
        self.birthYear = birthYear
        self.deathYear = deathYear
    }
}
