import Foundation
import SwiftUI

/// A Race Control message from the RaceControlMessages topic.
struct RaceControlMessage: Identifiable {
    let id = UUID()
    var utc: Date
    var category: Category
    var message: String
    var flag: Flag?
    var scope: Scope?
    var sector: Int?
    var lap: Int?
    var racingNumber: String?

    enum Category: String {
        case flag = "Flag"
        case drs = "Drs"
        case safetycar = "SafetyCar"
        case other = "Other"

        init(from string: String?) {
            guard let s = string else { self = .other; return }
            self = Category(rawValue: s) ?? .other
        }
    }

    enum Flag: String {
        case green = "GREEN"
        case yellow = "YELLOW"
        case doubleYellow = "DOUBLE YELLOW"
        case red = "RED"
        case blue = "BLUE"
        case black = "BLACK"
        case blackAndWhite = "BLACK AND WHITE"
        case chequered = "CHEQUERED"
        case clear = "CLEAR"

        init?(from string: String?) {
            guard let s = string else { return nil }
            self = Flag(rawValue: s) ?? .green
        }

        var color: Color {
            switch self {
            case .green, .clear: .green
            case .yellow, .doubleYellow: .yellow
            case .red: .red
            case .blue: .blue
            case .black, .blackAndWhite: .primary
            case .chequered: .gray
            }
        }

        var systemImage: String {
            switch self {
            case .green, .clear: "flag.fill"
            case .yellow, .doubleYellow: "exclamationmark.triangle.fill"
            case .red: "flag.fill"
            case .blue: "flag.fill"
            case .black, .blackAndWhite: "flag.fill"
            case .chequered: "flag.checkered"
            }
        }
    }

    enum Scope: String {
        case track = "Track"
        case sector = "Sector"
        case driver = "Driver"

        init?(from string: String?) {
            guard let s = string else { return nil }
            self = Scope(rawValue: s) ?? .track
        }
    }

    /// Parse from raw JSON dictionary.
    static func from(dict: [String: Any]) -> RaceControlMessage? {
        guard let utcString = dict["Utc"] as? String,
              let utc = DateFormatting.parseUTC(utcString),
              let message = dict["Message"] as? String else {
            return nil
        }
        return RaceControlMessage(
            utc: utc,
            category: Category(from: dict["Category"] as? String),
            message: message,
            flag: Flag(from: dict["Flag"] as? String),
            scope: Scope(from: dict["Scope"] as? String),
            sector: dict["Sector"] as? Int,
            lap: (dict["Lap"] as? Int) ?? (dict["Lap"] as? String).flatMap(Int.init),
            racingNumber: dict["RacingNumber"] as? String
        )
    }

    /// Whether this is a blue flag message (for filtering).
    var isBlueFlag: Bool {
        flag == .blue
    }
}
