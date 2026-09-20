import Foundation

struct ExerciseDBExercise: Decodable, Hashable {
    let exerciseID: String
    let name: String
    let imageURL: URL?
    let imageURLs: [String: URL]?
    let equipments: [String]
    let bodyParts: [String]
    let exerciseType: String?
    let targetMuscles: [String]
    let secondaryMuscles: [String]
    let videoURL: URL?
    let overview: String?
    let instructions: [String]
    let exerciseTips: [String]
    let variations: [String]

    enum CodingKeys: String, CodingKey {
        case exerciseID = "exerciseId"
        case name, imageURL = "imageUrl", imageURLs, equipments, bodyParts, exerciseType
        case targetMuscles, secondaryMuscles, videoURL = "videoUrl", overview, instructions, exerciseTips, variations
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        exerciseID = try values.decode(String.self, forKey: .exerciseID)
        name = try values.decode(String.self, forKey: .name)
        imageURL = try values.decodeIfPresent(URL.self, forKey: .imageURL)
        imageURLs = try values.decodeIfPresent([String: URL].self, forKey: .imageURLs)
        equipments = try values.decodeIfPresent([String].self, forKey: .equipments) ?? []
        bodyParts = try values.decodeIfPresent([String].self, forKey: .bodyParts) ?? []
        exerciseType = try values.decodeIfPresent(String.self, forKey: .exerciseType)
        targetMuscles = try values.decodeIfPresent([String].self, forKey: .targetMuscles) ?? []
        secondaryMuscles = try values.decodeIfPresent([String].self, forKey: .secondaryMuscles) ?? []
        videoURL = try values.decodeIfPresent(URL.self, forKey: .videoURL)
        overview = try values.decodeIfPresent(String.self, forKey: .overview)
        instructions = try values.decodeIfPresent([String].self, forKey: .instructions) ?? []
        exerciseTips = try values.decodeIfPresent([String].self, forKey: .exerciseTips) ?? []
        variations = try values.decodeIfPresent([String].self, forKey: .variations) ?? []
    }

    var preferredImageURL: URL? {
        imageURLs?["480p"] ?? imageURL ?? imageURLs?["360p"] ?? imageURLs?["720p"]
    }
}

private struct ExerciseDBResponse<Value: Decodable>: Decodable {
    let success: Bool
    let data: Value
}

enum ExerciseDBError: LocalizedError {
    case notConfigured
    case invalidResponse
    case requestFailed(Int)
    case noMatch

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Add a fresh ExerciseDB key in Settings to load tutorials."
        case .invalidResponse: "ExerciseDB returned an unreadable response."
        case .requestFailed(let status): "ExerciseDB request failed (HTTP \(status))."
        case .noMatch: "No matching ExerciseDB tutorial was found."
        }
    }
}

actor ExerciseDBService {
    static let shared = ExerciseDBService()

    private let host = "edb-with-videos-and-images-by-ascendapi.p.rapidapi.com"

    func tutorial(for query: String, apiKey: String) async throws -> ExerciseDBExercise {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ExerciseDBError.notConfigured }
        let results: [ExerciseDBExercise] = try await request(
            path: "/api/v1/exercises/search",
            queryItems: [URLQueryItem(name: "search", value: query)],
            apiKey: key
        )
        guard let result = results.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(query) == .orderedSame
        }) ?? results.first else {
            throw ExerciseDBError.noMatch
        }
        return try await request(path: "/api/v1/exercises/\(result.exerciseID)", queryItems: [], apiKey: key)
    }

    private func request<Value: Decodable>(path: String, queryItems: [URLQueryItem], apiKey: String) async throws -> Value {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = queryItems
        guard let url = components.url else { throw ExerciseDBError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ExerciseDBError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ExerciseDBError.requestFailed(http.statusCode) }
        let decoded = try JSONDecoder().decode(ExerciseDBResponse<Value>.self, from: data)
        guard decoded.success else { throw ExerciseDBError.invalidResponse }
        return decoded.data
    }
}
