import Foundation
import SwiftData

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
