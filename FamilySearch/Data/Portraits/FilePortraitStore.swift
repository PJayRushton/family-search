import Foundation

actor FilePortraitStore: PortraitRepository {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    static func applicationSupport(fileManager: FileManager = .default) throws -> FilePortraitStore {
        let root = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        return FilePortraitStore(directory: root.appending(path: "Portraits", directoryHint: .isDirectory))
    }

    func data(for portrait: PortraitReference) throws -> Data? {
        let url = fileURL(for: portrait.key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func save(_ data: Data, for portrait: PortraitReference) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: portrait.key), options: .atomic)
    }

    private func fileURL(for key: String) -> URL {
        // Base64url is stable and never trusts API-provided path components.
        let safeKey = Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory.appending(path: safeKey).appendingPathExtension("portrait")
    }
}
