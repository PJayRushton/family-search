import Foundation
import XCTest
@testable import FamilySearch

final class RecordsClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.setHandler(nil)
        super.tearDown()
    }

    func testFetchPeopleMapsFixtureToDomainAndResolvesPortraitURL() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.path, "/persons.json")
            return (.success(statusCode: 200), try fixture(named: "people"))
        }

        let people = try await client.fetchPeople()

        XCTAssertEqual(people.count, 2)
        XCTAssertEqual(people[0].name.fullName, "Ezra Whitcomb")
        XCTAssertEqual(people[0].birth.date, "12 March 1868")
        XCTAssertEqual(people[0].portrait?.remoteURL.absoluteString, "https://example.test/portraits/L4RX-9FT.jpg")
        XCTAssertNil(people[1].death)
        XCTAssertNil(people[1].portrait)
    }

    func testFetchProfileMapsNullableOccupationAndRelatives() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.path, "/persons/L4RX-9FT.json")
            return (.success(statusCode: 200), try fixture(named: "profile"))
        }

        let profile = try await client.fetchProfile(id: PersonID(rawValue: "L4RX-9FT"))

        XCTAssertNil(profile.occupation)
        XCTAssertEqual(profile.biography, "A concise fixture biography.")
        XCTAssertEqual(profile.relatives.first?.relationship, .father)
        XCTAssertEqual(profile.relatives.first?.name.fullName, "Amos Whitcomb")
    }

    func testFetchProfileRejectsIDContainingPathSeparatorBeforeRequest() async {
        let client = makeClient { _ in
            XCTFail("Invalid IDs must not reach the URL loading layer")
            return (.success(statusCode: 200), Data())
        }

        await XCTAssertThrowsErrorAsync(
            try await client.fetchProfile(id: PersonID(rawValue: "family/person"))
        ) { error in
            XCTAssertEqual(
                error as? RecordsClientError,
                .invalidData("Person ID cannot contain path separators.")
            )
        }
    }

    func testFetchPeopleReportsHTTPFailureWithoutDecodingBody() async {
        let client = makeClient { _ in
            (.success(statusCode: 503), Data("not json".utf8))
        }

        await XCTAssertThrowsErrorAsync(try await client.fetchPeople()) { error in
            XCTAssertEqual(error as? RecordsClientError, .httpStatus(503))
        }
    }

    func testFetchPeopleReportsMalformedPayloadAsDecodingFailure() async {
        let client = makeClient { _ in
            (.success(statusCode: 200), Data(#"{"persons":"wrong type"}"#.utf8))
        }

        await XCTAssertThrowsErrorAsync(try await client.fetchPeople()) { error in
            XCTAssertEqual(error as? RecordsClientError, .decoding)
        }
    }

    func testFetchProfileRejectsUnknownRelationshipDuringDomainMapping() async throws {
        let validFixture = String(decoding: try fixture(named: "profile"), as: UTF8.self)
        let invalidFixture = validFixture.replacingOccurrences(of: "\"father\"", with: "\"guardian\"")
        let client = makeClient { _ in
            (.success(statusCode: 200), Data(invalidFixture.utf8))
        }

        await XCTAssertThrowsErrorAsync(
            try await client.fetchProfile(id: PersonID(rawValue: "L4RX-9FT"))
        ) { error in
            XCTAssertEqual(
                error as? RecordsClientError,
                .invalidData("Unknown relationship 'guardian'.")
            )
        }
    }

    func testFetchPeopleWrapsTransportFailure() async {
        let client = makeClient { _ in throw URLError(.notConnectedToInternet) }

        await XCTAssertThrowsErrorAsync(try await client.fetchPeople()) { error in
            guard case .transport = error as? RecordsClientError else {
                return XCTFail("Expected typed transport error, got \(error)")
            }
        }
    }

    func testFetchPeoplePreservesCancellation() async {
        let client = makeClient { _ in
            try await Task.sleep(for: .seconds(10))
            return (.success(statusCode: 200), Data())
        }
        let task = Task { try await client.fetchPeople() }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: cancellation remains distinguishable from a transport failure.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    private func makeClient(
        handler: @escaping @Sendable (URLRequest) async throws -> (HTTPURLResponse, Data)
    ) -> URLSessionRecordsClient {
        URLProtocolStub.setHandler(handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSessionRecordsClient(
            baseURL: URL(string: "https://example.test/")!,
            session: URLSession(configuration: configuration)
        )
    }
}

private func fixture(named name: String) throws -> Data {
    let url = Bundle(for: RecordsClientTests.self).url(forResource: name, withExtension: "json")
    return try Data(contentsOf: XCTUnwrap(url))
}

private extension HTTPURLResponse {
    static func success(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) async throws -> (HTTPURLResponse, Data))?
    private static let handlerLock = NSLock()

    private var loadingTask: Task<Void, Never>?

    static func setHandler(
        _ newHandler: (@Sendable (URLRequest) async throws -> (HTTPURLResponse, Data))?
    ) {
        handlerLock.withLock { handler = newHandler }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handlerLock.withLock({ Self.handler }) else {
            client?.urlProtocol(self, didFailWithError: RecordsClientError.invalidResponse)
            return
        }
        loadingTask = Task {
            do {
                let (response, data) = try await handler(request)
                guard !Task.isCancelled else { return }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
