import Foundation
import os

/// Client for the Jolpica (Ergast replacement) F1 API.
/// Provides schedule, driver standings, and constructor standings.
actor ErgastClient {
    private let logger = Logger(subsystem: "com.f1dash", category: "Ergast")
    private let baseURL = URL(string: "https://api.jolpi.ca/ergast/f1")!

    // MARK: - Schedule

    /// Fetch race schedule for a season.
    func fetchSchedule(season: Int) async throws -> [RaceEvent] {
        let url = baseURL.appendingPathComponent("\(season).json")
        let data = try await fetchData(url: url)

        guard let mrData = data["MRData"] as? [String: Any],
              let raceTable = mrData["RaceTable"] as? [String: Any],
              let races = raceTable["Races"] as? [[String: Any]] else {
            return []
        }

        return races.compactMap { parseRaceEvent($0) }
    }

    // MARK: - Driver Standings

    /// Fetch current driver standings.
    func fetchDriverStandings(season: Int) async throws -> [DriverStanding] {
        let url = baseURL.appendingPathComponent("\(season)/driverStandings.json")
        let data = try await fetchData(url: url)

        guard let mrData = data["MRData"] as? [String: Any],
              let table = mrData["StandingsTable"] as? [String: Any],
              let lists = table["StandingsLists"] as? [[String: Any]],
              let first = lists.first,
              let standings = first["DriverStandings"] as? [[String: Any]] else {
            return []
        }

        return standings.compactMap { parseDriverStanding($0) }
    }

    // MARK: - Constructor Standings

    /// Fetch current constructor standings.
    func fetchConstructorStandings(season: Int) async throws -> [ConstructorStanding] {
        let url = baseURL.appendingPathComponent("\(season)/constructorStandings.json")
        let data = try await fetchData(url: url)

        guard let mrData = data["MRData"] as? [String: Any],
              let table = mrData["StandingsTable"] as? [String: Any],
              let lists = table["StandingsLists"] as? [[String: Any]],
              let first = lists.first,
              let standings = first["ConstructorStandings"] as? [[String: Any]] else {
            return []
        }

        return standings.compactMap { parseConstructorStanding($0) }
    }

    // MARK: - Private

    private func fetchData(url: URL) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ErgastError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ErgastError.invalidResponse
        }
        return json
    }

    private func parseRaceEvent(_ dict: [String: Any]) -> RaceEvent? {
        let circuit = dict["Circuit"] as? [String: Any] ?? [:]
        let location = circuit["Location"] as? [String: Any] ?? [:]
        let fp1 = dict["FirstPractice"] as? [String: Any]
        let quali = dict["Qualifying"] as? [String: Any]
        let sprint = dict["Sprint"] as? [String: Any]

        return RaceEvent(
            season: dict["season"] as? String ?? "",
            round: dict["round"] as? String ?? "",
            raceName: dict["raceName"] as? String ?? "",
            circuitName: circuit["circuitName"] as? String ?? "",
            circuitId: circuit["circuitId"] as? String ?? "",
            country: location["country"] as? String ?? "",
            locality: location["locality"] as? String ?? "",
            date: dict["date"] as? String ?? "",
            time: dict["time"] as? String,
            fp1Date: fp1?["date"] as? String,
            fp1Time: fp1?["time"] as? String,
            qualifyingDate: quali?["date"] as? String,
            qualifyingTime: quali?["time"] as? String,
            sprintDate: sprint?["date"] as? String,
            sprintTime: sprint?["time"] as? String
        )
    }

    private func parseDriverStanding(_ dict: [String: Any]) -> DriverStanding? {
        let driver = dict["Driver"] as? [String: Any] ?? [:]
        let constructors = dict["Constructors"] as? [[String: Any]] ?? []
        let constructor = constructors.first ?? [:]

        return DriverStanding(
            position: dict["position"] as? String ?? "",
            positionText: dict["positionText"] as? String ?? "",
            points: dict["points"] as? String ?? "0",
            wins: dict["wins"] as? String ?? "0",
            driverId: driver["driverId"] as? String ?? "",
            permanentNumber: driver["permanentNumber"] as? String,
            code: driver["code"] as? String,
            givenName: driver["givenName"] as? String ?? "",
            familyName: driver["familyName"] as? String ?? "",
            nationality: driver["nationality"] as? String ?? "",
            constructorName: constructor["name"] as? String ?? "",
            constructorId: constructor["constructorId"] as? String ?? ""
        )
    }

    private func parseConstructorStanding(_ dict: [String: Any]) -> ConstructorStanding? {
        let constructor = dict["Constructor"] as? [String: Any] ?? [:]

        return ConstructorStanding(
            position: dict["position"] as? String ?? "",
            positionText: dict["positionText"] as? String ?? "",
            points: dict["points"] as? String ?? "0",
            wins: dict["wins"] as? String ?? "0",
            constructorId: constructor["constructorId"] as? String ?? "",
            constructorName: constructor["name"] as? String ?? "",
            nationality: constructor["nationality"] as? String ?? ""
        )
    }
}

enum ErgastError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from Ergast API"
        case .httpError(let code): "Ergast API returned HTTP \(code)"
        }
    }
}
