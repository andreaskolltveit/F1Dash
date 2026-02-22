import Foundation
import os

/// Network client for the OpenF1 API.
/// Rate-limited to max 2 requests per second with automatic retry on 429.
actor OpenF1Client {
    private let logger = Logger(subsystem: "com.f1dash", category: "OpenF1")
    private let baseURL = URL(string: "https://api.openf1.org/v1")!

    // Rate limiting: enforce minimum delay between requests
    private var lastRequestTime: Date = .distantPast
    private let minRequestInterval: TimeInterval = 0.6  // ~1.7 req/s, safe under 4/s limit
    private let maxRetries = 3

    /// Fetch all stints for a given session.
    func fetchStints(sessionKey: Int) async throws -> [StintData] {
        let url = baseURL.appendingPathComponent("stints")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    /// Fetch all pit stops for a given session.
    func fetchPitStops(sessionKey: Int) async throws -> [PitStopData] {
        let url = baseURL.appendingPathComponent("pit")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    // MARK: - Session Discovery

    /// Fetch all sessions for a given year.
    func fetchSessions(year: Int) async throws -> [OpenF1Session] {
        let url = baseURL.appendingPathComponent("sessions")
            .appending(queryItems: [URLQueryItem(name: "year", value: "\(year)")])
        return try await request(url: url)
    }

    /// Fetch drivers for a given session.
    func fetchDrivers(sessionKey: Int) async throws -> [OpenF1Driver] {
        let url = baseURL.appendingPathComponent("drivers")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    // MARK: - Historical Data for Replay

    /// Fetch position data for a session.
    func fetchPositions(sessionKey: Int) async throws -> [HistoricalPosition] {
        let url = baseURL.appendingPathComponent("position")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    /// Fetch lap data for a session.
    func fetchLaps(sessionKey: Int) async throws -> [HistoricalLap] {
        let url = baseURL.appendingPathComponent("laps")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    /// Fetch interval data for a session.
    func fetchIntervals(sessionKey: Int) async throws -> [HistoricalInterval] {
        let url = baseURL.appendingPathComponent("intervals")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    /// Fetch race control messages for a session.
    func fetchRaceControl(sessionKey: Int) async throws -> [HistoricalRaceControl] {
        let url = baseURL.appendingPathComponent("race_control")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    /// Fetch team radio for a session.
    func fetchTeamRadio(sessionKey: Int) async throws -> [HistoricalTeamRadio] {
        let url = baseURL.appendingPathComponent("team_radio")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    /// Fetch weather data for a session.
    func fetchWeather(sessionKey: Int) async throws -> [HistoricalWeather] {
        let url = baseURL.appendingPathComponent("weather")
            .appending(queryItems: [URLQueryItem(name: "session_key", value: "\(sessionKey)")])
        return try await request(url: url)
    }

    /// Fetch car telemetry data for a session (sampled — large dataset).
    /// Use driver_number filter to limit data.
    func fetchCarData(sessionKey: Int, driverNumber: Int? = nil) async throws -> [HistoricalCarData] {
        var items = [URLQueryItem(name: "session_key", value: "\(sessionKey)")]
        if let driverNumber {
            items.append(URLQueryItem(name: "driver_number", value: "\(driverNumber)"))
        }
        let url = baseURL.appendingPathComponent("car_data")
            .appending(queryItems: items)
        return try await request(url: url)
    }

    /// Fetch location data for a session (large dataset).
    func fetchLocations(sessionKey: Int, driverNumber: Int? = nil) async throws -> [HistoricalLocation] {
        var items = [URLQueryItem(name: "session_key", value: "\(sessionKey)")]
        if let driverNumber {
            items.append(URLQueryItem(name: "driver_number", value: "\(driverNumber)"))
        }
        let url = baseURL.appendingPathComponent("location")
            .appending(queryItems: items)
        return try await request(url: url)
    }

    // MARK: - Private

    private func request<T: Decodable>(url: URL) async throws -> T {
        for attempt in 0..<maxRetries {
            await enforceRateLimit()

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenF1Error.invalidResponse
            }

            if httpResponse.statusCode == 429 {
                // Rate limited — back off exponentially and retry
                let backoff = Double(attempt + 1) * 2.0
                logger.warning("OpenF1 429 rate limited for \(url.lastPathComponent), backing off \(backoff)s (attempt \(attempt + 1)/\(self.maxRetries))")
                try await Task.sleep(for: .seconds(backoff))
                continue
            }

            guard httpResponse.statusCode == 200 else {
                logger.error("OpenF1 HTTP \(httpResponse.statusCode) for \(url.absoluteString)")
                throw OpenF1Error.httpError(httpResponse.statusCode)
            }

            // Models use explicit CodingKeys for snake_case mapping, so plain decoder works
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(T.self, from: data)
            } catch let error as DecodingError {
                let endpoint = url.lastPathComponent
                switch error {
                case .keyNotFound(let key, let context):
                    logger.error("[\(endpoint)] Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    logger.error("[\(endpoint)] Type mismatch: expected \(String(describing: type)) at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    logger.error("[\(endpoint)] Null value for \(String(describing: type)) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                case .dataCorrupted(let context):
                    logger.error("[\(endpoint)] Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)")
                @unknown default:
                    logger.error("[\(endpoint)] Unknown decode error: \(error.localizedDescription)")
                }
                // Log first 500 chars of response for debugging
                if let preview = String(data: data.prefix(500), encoding: .utf8) {
                    logger.error("[\(endpoint)] Response preview: \(preview)")
                }
                throw error
            }
        }

        // All retries exhausted
        logger.error("OpenF1 rate limit exhausted after \(self.maxRetries) retries for \(url.absoluteString)")
        throw OpenF1Error.rateLimited
    }

    private func enforceRateLimit() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)
        if elapsed < minRequestInterval {
            let waitTime = minRequestInterval - elapsed
            try? await Task.sleep(for: .seconds(waitTime))
        }
        lastRequestTime = Date()
    }
}

enum OpenF1Error: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from OpenF1 API"
        case .httpError(let code): "OpenF1 API returned HTTP \(code)"
        case .rateLimited: "OpenF1 API rate limit exceeded. Please wait a moment and try again."
        }
    }
}
