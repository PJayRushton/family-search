import Foundation

protocol PortraitClient: Sendable {
    func fetchData(from url: URL) async throws -> Data
}

actor URLSessionPortraitClient: PortraitClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchData(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else {
                throw RecordsClientError.invalidResponse
            }
            guard (200..<300).contains(response.statusCode) else {
                throw RecordsClientError.httpStatus(response.statusCode)
            }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as RecordsClientError {
            throw error
        } catch {
            throw RecordsClientError.transport(error.localizedDescription)
        }
    }
}
