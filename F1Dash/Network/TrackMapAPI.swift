import Foundation
import os

/// Fetches track map geometry from the MultiViewer API.
enum TrackMapAPI {
    private static let logger = Logger(subsystem: "com.f1dash", category: "TrackMapAPI")
    private static let baseURL = "https://api.multiviewer.app/api/v1/circuits"

    /// Fetch track map for a circuit and year.
    static func fetchTrackMap(circuitKey: Int, year: Int) async throws -> TrackMap {
        let url = URL(string: "\(baseURL)/\(circuitKey)/\(year)")!
        var request = URLRequest(url: url)
        request.setValue("F1Dash/1.0", forHTTPHeaderField: "User-Agent")

        logger.info("Fetching track map: circuit=\(circuitKey), year=\(year)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TrackMapError.fetchFailed
        }

        let decoder = JSONDecoder()
        let trackMap = try decoder.decode(TrackMap.self, from: data)
        logger.info("Track map loaded: \(trackMap.x.count) points")
        return trackMap
    }

    enum TrackMapError: Error, LocalizedError {
        case fetchFailed

        var errorDescription: String? {
            "Failed to fetch track map from MultiViewer API"
        }
    }
}
