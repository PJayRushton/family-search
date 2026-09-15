import Foundation

protocol RecordsClient: Sendable {
    func fetchPeople() async throws -> [PersonSummary]
    func fetchProfile(id: PersonID) async throws -> PersonProfile
}

enum RecordsClientError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case decoding
    case invalidData(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The records service returned an invalid response."
        case let .httpStatus(statusCode):
            "The records service returned HTTP status \(statusCode)."
        case .decoding:
            "The records service returned data in an unexpected format."
        case let .invalidData(reason):
            "The records service returned an invalid record: \(reason)"
        case let .transport(message):
            "The records service could not be reached: \(message)"
        }
    }
}

final class URLSessionRecordsClient: RecordsClient, @unchecked Sendable {
    static let serviceBaseURL = URL(string: "https://fs-records-sample.vercel.app/")!

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = serviceBaseURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    func fetchPeople() async throws -> [PersonSummary] {
        let response: PeopleResponseDTO = try await request(path: "persons.json")
        return try response.persons.map { try $0.domainModel(baseURL: baseURL) }
    }

    func fetchProfile(id: PersonID) async throws -> PersonProfile {
        let escapedID = id.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        guard let escapedID else {
            throw RecordsClientError.invalidData("Person ID cannot form a URL.")
        }

        let response: PersonProfileDTO = try await request(path: "persons/\(escapedID).json")
        return try response.domainModel(baseURL: baseURL)
    }

    private func request<Response: Decodable>(path: String) async throws -> Response {
        let url = baseURL.appending(path: path)

        do {
            try Task.checkCancellation()
            let (data, response) = try await session.data(from: url)
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RecordsClientError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw RecordsClientError.httpStatus(httpResponse.statusCode)
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw RecordsClientError.decoding
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            // URLSession reports cancellation as URLError; keep it cancellation to callers.
            throw CancellationError()
        } catch let error as RecordsClientError {
            throw error
        } catch {
            throw RecordsClientError.transport(error.localizedDescription)
        }
    }
}

// These types deliberately mirror the wire format and never leave the remote adapter.
private struct PeopleResponseDTO: Decodable {
    let persons: [PersonSummaryDTO]
}

private struct PersonSummaryDTO: Decodable {
    let id: String
    let name: PersonNameDTO
    let living: Bool
    let birth: LifeEventDTO
    let death: LifeEventDTO?
    let portraitUrl: String?

    func domainModel(baseURL: URL) throws -> PersonSummary {
        let portrait = try portraitUrl.map { path -> PortraitReference in
            guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
                  url.scheme == baseURL.scheme,
                  url.host == baseURL.host else {
                throw RecordsClientError.invalidData("Portrait URL is not relative to the service.")
            }
            return PortraitReference(key: path, remoteURL: url)
        }

        return PersonSummary(
            id: PersonID(rawValue: id),
            name: name.domainModel,
            isLiving: living,
            birth: birth.domainModel,
            death: death?.domainModel,
            portrait: portrait
        )
    }
}

private struct PersonProfileDTO: Decodable {
    let id: String
    let name: PersonNameDTO
    let living: Bool
    let birth: LifeEventDTO
    let death: LifeEventDTO?
    let portraitUrl: String?
    let occupation: String?
    let biography: String
    let relatives: [RelativeDTO]

    func domainModel(baseURL: URL) throws -> PersonProfile {
        let summary = try PersonSummaryDTO(
            id: id,
            name: name,
            living: living,
            birth: birth,
            death: death,
            portraitUrl: portraitUrl
        ).domainModel(baseURL: baseURL)

        return PersonProfile(
            summary: summary,
            occupation: occupation,
            biography: biography,
            relatives: try relatives.map { try $0.domainModel }
        )
    }
}

private struct PersonNameDTO: Decodable {
    let given: String
    let surname: String

    var domainModel: PersonName {
        PersonName(given: given, surname: surname)
    }
}

private struct LifeEventDTO: Decodable {
    let date: String
    let year: Int
    let place: String

    var domainModel: LifeEvent {
        LifeEvent(date: date, year: year, place: place)
    }
}

private struct RelativeDTO: Decodable {
    let id: String
    let relationship: String
    let name: PersonNameDTO
    let birthYear: Int
    let deathYear: Int?

    var domainModel: RelativeSummary {
        get throws {
            guard let relationship = Relationship(rawValue: relationship) else {
                throw RecordsClientError.invalidData("Unknown relationship '\(relationship)'.")
            }
            return RelativeSummary(
                id: PersonID(rawValue: id),
                relationship: relationship,
                name: name.domainModel,
                birthYear: birthYear,
                deathYear: deathYear
            )
        }
    }
}
