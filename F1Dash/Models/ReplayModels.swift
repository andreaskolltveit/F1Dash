import Foundation

// MARK: - OpenF1 Session Discovery

/// A session from the OpenF1 sessions endpoint.
struct OpenF1Session: Codable, Identifiable, Hashable {
    var id: Int { sessionKey }

    let sessionKey: Int
    let sessionName: String
    let sessionType: String?
    let dateStart: String?
    let dateEnd: String?
    let year: Int
    let circuitKey: Int?
    let circuitShortName: String?
    let countryName: String?
    let countryCode: String?
    let meetingKey: Int?
    let meetingName: String?
    let gmtOffset: String?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case sessionName = "session_name"
        case sessionType = "session_type"
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case year
        case circuitKey = "circuit_key"
        case circuitShortName = "circuit_short_name"
        case countryName = "country_name"
        case countryCode = "country_code"
        case meetingKey = "meeting_key"
        case meetingName = "meeting_name"
        case gmtOffset = "gmt_offset"
        case location
    }

    /// Parsed start date.
    var startDate: Date? {
        guard let dateStart else { return nil }
        return parseOpenF1Date(dateStart)
    }

    /// Display name: prefer location (e.g. "Las Vegas"), then meeting name, then country.
    /// OpenF1 API often returns meeting_name as null, so location is the best fallback.
    var displayName: String {
        meetingName ?? location ?? countryName ?? "Session \(sessionKey)"
    }
}

/// A driver entry from the OpenF1 drivers endpoint.
struct OpenF1Driver: Codable, Identifiable {
    var id: Int { driverNumber }

    let driverNumber: Int
    let broadcastName: String?
    let fullName: String?
    let nameAcronym: String?
    let teamName: String?
    let teamColour: String?
    let countryCode: String?
    let sessionKey: Int?
    let meetingKey: Int?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case broadcastName = "broadcast_name"
        case fullName = "full_name"
        case nameAcronym = "name_acronym"
        case teamName = "team_name"
        case teamColour = "team_colour"
        case countryCode = "country_code"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }

    /// Display acronym (fallback to driver number).
    var tla: String {
        nameAcronym ?? String(driverNumber)
    }

    /// Display name (fallback to broadcast name or number).
    var displayName: String {
        fullName ?? broadcastName ?? "Driver \(driverNumber)"
    }
}

// MARK: - Historical Data (for replay timeline)

/// Position data point from OpenF1.
struct HistoricalPosition: Codable {
    let driverNumber: Int
    let date: String
    let position: Int

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case date
        case position
    }
}

/// Lap data from OpenF1.
struct HistoricalLap: Codable {
    let driverNumber: Int
    let lapNumber: Int
    let lapDuration: Double?
    let durationSector1: Double?
    let durationSector2: Double?
    let durationSector3: Double?
    let isPitOutLap: Bool?
    let dateStart: String?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case lapNumber = "lap_number"
        case lapDuration = "lap_duration"
        case durationSector1 = "duration_sector_1"
        case durationSector2 = "duration_sector_2"
        case durationSector3 = "duration_sector_3"
        case isPitOutLap = "is_pit_out_lap"
        case dateStart = "date_start"
    }
}

/// Interval data from OpenF1.
/// Note: `gap_to_leader` and `interval` can be Double, String (e.g. "+1 LAP"), or null.
struct HistoricalInterval: Codable {
    let driverNumber: Int
    let date: String
    let gapToLeader: Double?
    let gapToLeaderText: String?  // For values like "+1 LAP"
    let interval: Double?
    let intervalText: String?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case date
        case gapToLeader = "gap_to_leader"
        case interval
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        driverNumber = try c.decode(Int.self, forKey: .driverNumber)
        date = try c.decode(String.self, forKey: .date)

        // gap_to_leader: try Double first, then String
        if let value = try? c.decodeIfPresent(Double.self, forKey: .gapToLeader) {
            gapToLeader = value
            gapToLeaderText = nil
        } else if let text = try? c.decodeIfPresent(String.self, forKey: .gapToLeader) {
            gapToLeader = nil
            gapToLeaderText = text
        } else {
            gapToLeader = nil
            gapToLeaderText = nil
        }

        // interval: try Double first, then String
        if let value = try? c.decodeIfPresent(Double.self, forKey: .interval) {
            interval = value
            intervalText = nil
        } else if let text = try? c.decodeIfPresent(String.self, forKey: .interval) {
            interval = nil
            intervalText = text
        } else {
            interval = nil
            intervalText = nil
        }
    }
}

/// Race control message from OpenF1.
struct HistoricalRaceControl: Codable {
    let date: String
    let category: String?
    let flag: String?
    let message: String
    let scope: String?
    let sector: Int?
    let driverNumber: Int?
    let lapNumber: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case category
        case flag
        case message
        case scope
        case sector
        case driverNumber = "driver_number"
        case lapNumber = "lap_number"
    }
}

/// Car telemetry data from OpenF1.
struct HistoricalCarData: Codable {
    let driverNumber: Int
    let date: String
    let speed: Int?
    let rpm: Int?
    let gear: Int?
    let throttle: Int?
    let drs: Int?

    let brake: Int?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case date
        case speed
        case rpm
        case gear = "n_gear"
        case throttle
        case brake
        case drs
    }
}

/// Team radio from OpenF1.
struct HistoricalTeamRadio: Codable {
    let driverNumber: Int
    let date: String
    let recordingUrl: String?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case date
        case recordingUrl = "recording_url"
    }
}

/// Weather from OpenF1.
struct HistoricalWeather: Codable {
    let date: String
    let airTemperature: Double?
    let trackTemperature: Double?
    let humidity: Double?
    let pressure: Double?
    let windSpeed: Double?
    let windDirection: Int?
    let rainfall: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case airTemperature = "air_temperature"
        case trackTemperature = "track_temperature"
        case humidity
        case pressure
        case windSpeed = "wind_speed"
        case windDirection = "wind_direction"
        case rainfall
    }
}

/// Location/position data from OpenF1.
struct HistoricalLocation: Codable {
    let driverNumber: Int
    let date: String
    let x: Double
    let y: Double
    let z: Double

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case date, x, y, z
    }
}

// MARK: - Replay Timeline

/// A single event in the replay timeline, sorted by timestamp.
struct ReplayEvent {
    let timestamp: Date
    let kind: ReplayEventKind
}

/// The different kinds of replay events.
enum ReplayEventKind {
    case position(driverNumber: Int, position: Int)
    case lap(HistoricalLap)
    case interval(driverNumber: Int, gapToLeader: Double?, gapToLeaderText: String?, interval: Double?, intervalText: String?)
    case raceControl(HistoricalRaceControl)
    case carData(driverNumber: Int, speed: Int?, rpm: Int?, gear: Int?, throttle: Int?, brake: Int?, drs: Int?)
    case teamRadio(driverNumber: Int, recordingUrl: String?)
    case weather(HistoricalWeather)
    case location(driverNumber: Int, x: Double, y: Double, z: Double)
    case stint(StintData)
    case pitStop(PitStopData)
}

// MARK: - Replay State

/// Playback speed multiplier.
enum ReplaySpeed: Double, CaseIterable, Identifiable {
    case x1 = 1.0
    case x2 = 2.0
    case x4 = 4.0
    case x8 = 8.0
    case x16 = 16.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .x1: "1x"
        case .x2: "2x"
        case .x4: "4x"
        case .x8: "8x"
        case .x16: "16x"
        }
    }
}

/// Current state of the replay engine.
enum ReplayState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case finished
    case error(String)

    var isActive: Bool {
        switch self {
        case .playing, .paused: true
        default: false
        }
    }
}

// MARK: - Helpers

extension DateFormatter {
    /// Fallback parser for OpenF1 date strings without 'Z' suffix.
    static let openF1Fallback: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static let openF1WithZ: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

/// Parse an OpenF1 date string to Date.
func parseOpenF1Date(_ string: String) -> Date? {
    // Try ISO8601 first (most common)
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = iso.date(from: string) { return d }

    // Fallback formatters
    if let d = DateFormatter.openF1Fallback.date(from: string) { return d }
    if let d = DateFormatter.openF1WithZ.date(from: string) { return d }

    // Last resort: strip fractional seconds
    let trimmed = string.replacingOccurrences(
        of: "\\.\\d+", with: "", options: .regularExpression
    )
    return ISO8601DateFormatter().date(from: trimmed)
}
