import Foundation
import UIKit

actor LivePortraitRepository: PortraitRepository {
    private let client: any PortraitClient
    private let store: FilePortraitStore

    init(client: any PortraitClient, store: FilePortraitStore) {
        self.client = client
        self.store = store
    }

    func data(for portrait: PortraitReference) async throws -> Data? {
        if let savedData = try await store.data(for: portrait) { return savedData }

        let remoteData = try await client.fetchData(from: portrait.remoteURL)
        try Task.checkCancellation()
        guard UIImage(data: remoteData) != nil else { throw RecordsClientError.invalidResponse }
        try await store.save(remoteData, for: portrait)
        // Reading after writing keeps the same source-of-truth rule as record refreshes.
        return try await store.data(for: portrait)
    }
}
