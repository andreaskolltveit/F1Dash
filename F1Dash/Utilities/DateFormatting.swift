import Foundation

/// Date utilities for F1 Live Timing UTC timestamps.
enum DateFormatting {

    /// ISO 8601 formatter for F1 timestamps (e.g., "2026-02-21T12:34:56.789Z")
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Fallback without fractional seconds
    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Time-only formatter for display (HH:mm:ss)
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = .current
        return f
    }()

    /// Parse an F1 UTC timestamp string to Date.
    static func parseUTC(_ string: String) -> Date? {
        isoFormatter.date(from: string) ?? isoFormatterNoFrac.date(from: string)
    }

    /// Format a Date as local time string (HH:mm:ss).
    static func localTimeString(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// Format a Date with track-local time using GmtOffset from SessionInfo.
    /// - Parameter gmtOffset: Offset string like "02:00:00" or "-05:00:00"
    static func trackTimeString(_ date: Date, gmtOffset: String?) -> String {
        guard let gmtOffset = gmtOffset,
              let offsetSeconds = parseGmtOffset(gmtOffset) else {
            return localTimeString(date)
        }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = TimeZone(secondsFromGMT: offsetSeconds)
        return f.string(from: date)
    }

    /// Parse GMT offset string (e.g., "02:00:00") to seconds.
    static func parseGmtOffset(_ offset: String) -> Int? {
        let isNegative = offset.hasPrefix("-")
        let cleaned = offset.trimmingCharacters(in: CharacterSet(charactersIn: "-+"))
        let parts = cleaned.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        let seconds = parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
        return isNegative ? -seconds : seconds
    }
}
