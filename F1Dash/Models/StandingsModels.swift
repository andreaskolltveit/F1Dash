import Foundation

// MARK: - Ergast/Jolpica API Models

/// Driver standings from Ergast/Jolpica API.
struct DriverStanding: Identifiable, Codable {
    var id: String { driverId }

    let position: String
    let positionText: String
    let points: String
    let wins: String
    let driverId: String
    let permanentNumber: String?
    let code: String?
    let givenName: String
    let familyName: String
    let nationality: String
    let constructorName: String
    let constructorId: String

    var pointsDouble: Double { Double(points) ?? 0 }
    var positionInt: Int { Int(position) ?? 0 }
}

/// Constructor standings from Ergast/Jolpica API.
struct ConstructorStanding: Identifiable, Codable {
    var id: String { constructorId }

    let position: String
    let positionText: String
    let points: String
    let wins: String
    let constructorId: String
    let constructorName: String
    let nationality: String

    var pointsDouble: Double { Double(points) ?? 0 }
    var positionInt: Int { Int(position) ?? 0 }
}

// MARK: - Schedule Models

/// A race weekend from the schedule.
struct RaceEvent: Identifiable, Codable {
    var id: String { "\(season)-\(round)" }

    let season: String
    let round: String
    let raceName: String
    let circuitName: String
    let circuitId: String
    let country: String
    let locality: String
    let date: String      // "2025-03-16"
    let time: String?     // "15:00:00Z"

    // Session dates (optional, from detailed schedule)
    let fp1Date: String?
    let fp1Time: String?
    let qualifyingDate: String?
    let qualifyingTime: String?
    let sprintDate: String?
    let sprintTime: String?

    var roundInt: Int { Int(round) ?? 0 }

    /// Parse the race date+time into a Date.
    var raceDate: Date? {
        let str = time != nil ? "\(date)T\(time!)" : "\(date)T15:00:00Z"
        return ISO8601DateFormatter().date(from: str)
    }

    /// Whether this event is in the future.
    var isFuture: Bool {
        guard let d = raceDate else { return false }
        return d > Date()
    }
}
