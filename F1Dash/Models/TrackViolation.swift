import Foundation

/// Aggregated track violations per driver, derived from RaceControlMessages.
struct TrackViolation: Identifiable {
    let id: String  // racing number
    let driverNumber: String
    var count: Int
    var lastLap: Int?
    var messages: [RaceControlMessage]
}
