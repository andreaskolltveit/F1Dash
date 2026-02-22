import Foundation
import SwiftUI

/// Tire compound types used in F1.
enum TireCompound: String, Codable, CaseIterable {
    case soft = "SOFT"
    case medium = "MEDIUM"
    case hard = "HARD"
    case intermediate = "INTERMEDIATE"
    case wet = "WET"
    case unknown = "UNKNOWN"

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = TireCompound(rawValue: value) ?? .unknown
    }

    var abbreviation: String {
        switch self {
        case .soft: "S"
        case .medium: "M"
        case .hard: "H"
        case .intermediate: "I"
        case .wet: "W"
        case .unknown: "?"
        }
    }

    var color: Color {
        switch self {
        case .soft: F1Theme.Tire.soft
        case .medium: F1Theme.Tire.medium
        case .hard: F1Theme.Tire.hard
        case .intermediate: F1Theme.Tire.intermediate
        case .wet: F1Theme.Tire.wet
        case .unknown: .gray
        }
    }
}

/// Stint data from OpenF1 API.
struct StintData: Codable, Identifiable {
    var id: String { "\(driverNumber)-\(stintNumber)" }

    let driverNumber: Int
    let stintNumber: Int
    let compound: TireCompound
    let tyreAgeAtStart: Int?
    let lapStart: Int?
    let lapEnd: Int?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case stintNumber = "stint_number"
        case compound
        case tyreAgeAtStart = "tyre_age_at_start"
        case lapStart = "lap_start"
        case lapEnd = "lap_end"
    }

    /// Current tire age = age at start + laps driven in this stint.
    func currentAge(currentLap: Int) -> Int {
        let startAge = tyreAgeAtStart ?? 0
        let lapsDriven = max(0, currentLap - (lapStart ?? currentLap))
        return startAge + lapsDriven
    }
}

/// Pit stop data from OpenF1 API.
struct PitStopData: Codable, Identifiable {
    var id: String { "\(driverNumber)-\(lapNumber)" }

    let driverNumber: Int
    let lapNumber: Int
    let pitDuration: Double?
    let date: String?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case lapNumber = "lap_number"
        case pitDuration = "pit_duration"
        case date
    }
}
