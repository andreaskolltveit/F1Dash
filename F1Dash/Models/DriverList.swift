import Foundation
import SwiftUI

/// A driver entry from the DriverList topic.
struct Driver: Identifiable {
    let id: String  // Racing number as string key
    var racingNumber: String
    var tla: String  // Three-letter abbreviation (e.g., "VER")
    var firstName: String
    var lastName: String
    var fullName: String
    var teamName: String
    var teamColour: String  // Hex without #
    var line: Int  // Position on timing screen
    var countryCode: String
    var broadcastName: String = ""
    var headshotUrl: String? = nil
    var reference: String? = nil

    var color: Color {
        Color(hex: teamColour)
    }

    /// Parse from raw JSON dictionary.
    static func from(key: String, dict: [String: Any]) -> Driver {
        Driver(
            id: key,
            racingNumber: dict["RacingNumber"] as? String ?? key,
            tla: dict["Tla"] as? String ?? "???",
            firstName: dict["FirstName"] as? String ?? "",
            lastName: dict["LastName"] as? String ?? "",
            fullName: dict["FullName"] as? String ?? "",
            teamName: dict["TeamName"] as? String ?? "",
            teamColour: dict["TeamColour"] as? String ?? "FFFFFF",
            line: dict["Line"] as? Int ?? 0,
            countryCode: dict["CountryCode"] as? String ?? "",
            broadcastName: dict["BroadcastName"] as? String ?? "",
            headshotUrl: dict["HeadshotUrl"] as? String,
            reference: dict["Reference"] as? String
        )
    }
}

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
