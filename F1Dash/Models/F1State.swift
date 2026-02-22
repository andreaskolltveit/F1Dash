import Foundation

/// Connection state for the SignalR client.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting..."
        case .connected: "Connected"
        case .reconnecting: "Reconnecting..."
        case .error(let msg): "Error: \(msg)"
        }
    }

    var isConnected: Bool {
        self == .connected
    }
}

/// Extrapolated clock from the ExtrapolatedClock topic.
struct ExtrapolatedClock {
    var utc: Date
    var remaining: String  // e.g., "01:23:45"
    var extrapolating: Bool

    static func from(dict: [String: Any]) -> ExtrapolatedClock? {
        guard let utcString = dict["Utc"] as? String,
              let utc = DateFormatting.parseUTC(utcString) else { return nil }
        return ExtrapolatedClock(
            utc: utc,
            remaining: dict["Remaining"] as? String ?? "",
            extrapolating: dict["Extrapolating"] as? Bool ?? false
        )
    }
}

/// Lap count from the LapCount topic.
struct LapCount {
    var currentLap: Int
    var totalLaps: Int

    static func from(dict: [String: Any]) -> LapCount {
        LapCount(
            currentLap: dict["CurrentLap"] as? Int ?? 0,
            totalLaps: dict["TotalLaps"] as? Int ?? 0
        )
    }
}
