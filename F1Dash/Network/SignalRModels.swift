import Foundation

// MARK: - Negotiate Response

struct NegotiateResponse: Decodable {
    let ConnectionToken: String
    let ConnectionId: String?
    let KeepAliveTimeout: Double?
    let DisconnectTimeout: Double?
    let TransportConnectTimeout: Double?
    let TryWebSockets: Bool?
}

// MARK: - SignalR Wire Messages

/// Incoming message from SignalR 1.5 WebSocket
struct SignalRMessage {
    /// Messages array — each contains hub invocation data
    let messages: [SignalRHubMessage]
    /// Server-side groups token
    let groupsToken: String?
    /// Message ID for long polling (not used with WS)
    let messageId: String?
}

struct SignalRHubMessage {
    /// Hub name (always "Streaming")
    let hub: String?
    /// Method name (always "feed")
    let method: String?
    /// Arguments: [topicName, data, timestamp?]
    let arguments: [Any]
}

// MARK: - Subscribe Request

struct SignalRInvocation: Encodable {
    let H: String  // Hub name
    let M: String  // Method name
    let A: [[String]]  // Arguments (topic list)
    let I: String  // Invocation ID
}

// MARK: - Topic Names

enum F1Topic: String, CaseIterable {
    case heartbeat = "Heartbeat"
    case carData = "CarData.z"
    case position = "Position.z"
    case extrapolatedClock = "ExtrapolatedClock"
    case timingStats = "TimingStats"
    case timingAppData = "TimingAppData"
    case weatherData = "WeatherData"
    case trackStatus = "TrackStatus"
    case sessionStatus = "SessionStatus"
    case driverList = "DriverList"
    case raceControlMessages = "RaceControlMessages"
    case sessionInfo = "SessionInfo"
    case sessionData = "SessionData"
    case lapCount = "LapCount"
    case timingData = "TimingData"
    case teamRadio = "TeamRadio"
    case championshipPrediction = "ChampionshipPrediction"

    /// All topics to subscribe to
    static var allTopicNames: [String] {
        allCases.map(\.rawValue)
    }

    /// Whether this topic uses .z compression
    var isCompressed: Bool {
        rawValue.hasSuffix(".z")
    }

    /// Base name without .z suffix
    var baseName: String {
        rawValue.replacingOccurrences(of: ".z", with: "")
    }
}
