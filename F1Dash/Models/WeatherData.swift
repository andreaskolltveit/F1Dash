import Foundation

/// Weather data from the WeatherData topic.
struct WeatherData {
    var airTemp: Double?
    var trackTemp: Double?
    var humidity: Double?
    var pressure: Double?
    var windSpeed: Double?
    var windDirection: Double?
    var rainfall: Bool

    /// Parse from raw JSON dictionary.
    static func from(dict: [String: Any]) -> WeatherData {
        WeatherData(
            airTemp: parseDouble(dict["AirTemp"]),
            trackTemp: parseDouble(dict["TrackTemp"]),
            humidity: parseDouble(dict["Humidity"]),
            pressure: parseDouble(dict["Pressure"]),
            windSpeed: parseDouble(dict["WindSpeed"]),
            windDirection: parseDouble(dict["WindDirection"]),
            rainfall: dict["Rainfall"] as? String == "1" || dict["Rainfall"] as? Bool == true
        )
    }

    private static func parseDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let s = value as? String { return Double(s) }
        if let i = value as? Int { return Double(i) }
        return nil
    }
}
