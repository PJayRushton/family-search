enum AppRoute: Hashable {
    case profile(PersonID)

    /// Family relationships form cycles, so revisit an existing destination instead of stacking it twice.
    static func path(afterSelecting personID: PersonID, from path: [AppRoute]) -> [AppRoute] {
        let destination = AppRoute.profile(personID)
        guard let existingIndex = path.firstIndex(of: destination) else {
            return path + [destination]
        }
        return Array(path.prefix(through: existingIndex))
    }
}
