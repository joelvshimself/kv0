import Foundation

class APIClient: ObservableObject {
    static let shared = APIClient()
    
    @Published var baseURL: String = "http://localhost:3000/api"
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    func setBaseURL(_ url: String) {
        self.baseURL = url
    }
    
    private func request<T: Decodable>(
        method: String,
        path: String,
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    func registerUser(_ request: UserRequest) async throws -> UserResponse {
        try await self.request(method: "POST", path: "/users", body: request)
    }
    
    func getUser(userId: String) async throws -> User {
        try await self.request(method: "GET", path: "/users/\(userId)")
    }
    
    func submitSleep(_ session: SleepSessionRequest) async throws -> SleepSubmitResponse {
        try await self.request(method: "POST", path: "/sleep", body: session)
    }
    
    func getSleepHistory(userId: String, days: Int = 7) async throws -> SleepHistoryResponse {
        try await self.request(method: "GET", path: "/sleep/\(userId)?days=\(days)")
    }
    
    func getEnergyPrediction(userId: String) async throws -> EnergyPredictionResponse {
        try await self.request(method: "GET", path: "/energy/\(userId)")
    }
    
    func submitJourney(_ journey: JourneyRequest) async throws -> JourneyResponse {
        try await self.request(method: "POST", path: "/journey", body: journey)
    }
    
    func getJourneyHistory(userId: String, days: Int = 7) async throws -> JourneyHistoryResponse {
        try await self.request(method: "GET", path: "/journey/\(userId)?days=\(days)")
    }
    
    func getDashboard(userId: String) async throws -> DashboardResponse {
        try await self.request(method: "GET", path: "/dashboard/\(userId)")
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

struct ErrorResponse: Codable {
    let error: String
}

struct UserRequest: Codable {
    let id: String
    let device_token: String?
    let timezone: String?
    let wake_time: String?
    let sleep_time: String?
    let pre_dip_notification_minutes: Int?
    let notifications_enabled: Bool?
}

struct UserResponse: Codable {
    let success: Bool
    let user: User
}

struct User: Codable {
    let id: String
    let device_token: String?
    let timezone: String
    let wake_time: String?
    let sleep_time: String?
    let pre_dip_notification_minutes: Int
    let notifications_enabled: Bool
    let created_at: String
    let updated_at: String
}

struct SleepSessionRequest: Codable {
    let user_id: String
    let start_time: String
    let end_time: String
    let duration_minutes: Int
    let quality_score: Int?
    let deep_sleep_minutes: Int?
    let rem_sleep_minutes: Int?
    let light_sleep_minutes: Int?
    let awake_minutes: Int?
    let source: String
}

struct SleepSubmitResponse: Codable {
    let success: Bool
    let session_id: Int
    let analysis: SleepAnalysisResponse
    let prediction: PredictionResponse
}

struct SleepAnalysisResponse: Codable {
    let score: ScoreBreakdown
    let sleep_debt_minutes: Int
    let recommendation: String
    let optimal_wake_time: String
    let optimal_sleep_time: String
}

struct ScoreBreakdown: Codable {
    let overall: Int
    let duration: Int
    let quality: Int
    let timing: Int
}

struct PredictionResponse: Codable {
    let wake_time: String
    let dip_time: String
    let peak_time: String
    let evening_decline_time: String
    let alertness_curve: [AlertnessPointAPI]
    let sleep_debt_impact: Double
}

struct AlertnessPointAPI: Codable {
    let hour: Double
    let level: Double
}

struct SleepHistoryResponse: Codable {
    let sessions: [SleepSessionResponse]
}

struct SleepSessionResponse: Codable {
    let id: Int
    let user_id: String
    let start_time: String
    let end_time: String
    let duration_minutes: Int
    let quality_score: Int?
    let deep_sleep_minutes: Int?
    let rem_sleep_minutes: Int?
    let light_sleep_minutes: Int?
    let awake_minutes: Int?
    let source: String
    let created_at: String
}

struct EnergyPredictionResponse: Codable {
    let id: Int
    let user_id: String
    let date: String
    let wake_time: String
    let dip_time: String
    let sleep_debt_minutes: Int
    let circadian_phase: Double
    let alertness_curve: [AlertnessPointAPI]
    let hours_until_dip: Double
    let created_at: String
}

struct JourneyRequest: Codable {
    let user_id: String
    let date: String
    let duration_minutes: Int
    let start_time: String
    let end_time: String
}

struct JourneyResponse: Codable {
    let success: Bool
    let journey_id: Int
}

struct JourneyHistoryResponse: Codable {
    let journeys: [JourneyLog]
}

struct JourneyLog: Codable {
    let id: Int
    let user_id: String
    let date: String
    let duration_minutes: Int
    let start_time: String
    let end_time: String
    let created_at: String
}

struct DashboardResponse: Codable {
    let last_sleep: SleepSessionResponse?
    let recent_sleep: [SleepSessionResponse]
    let energy_prediction: EnergyPredictionResponse?
    let today_journey: JourneyLog?
}
