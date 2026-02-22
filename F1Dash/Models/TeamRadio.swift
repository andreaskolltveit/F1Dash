import Foundation

/// A team radio capture from the TeamRadio topic.
struct RadioCapture: Identifiable {
    let id = UUID()
    var utc: Date
    var racingNumber: String
    var path: String  // Relative path to audio file

    /// Full URL for the audio file.
    func audioURL(sessionPath: String) -> URL? {
        let base = "https://livetiming.formula1.com/static/"
        let fullPath = sessionPath + path
        return URL(string: base + fullPath)
    }

    /// Parse from raw JSON dictionary.
    static func from(dict: [String: Any]) -> RadioCapture? {
        guard let utcString = dict["Utc"] as? String,
              let utc = DateFormatting.parseUTC(utcString),
              let racingNumber = dict["RacingNumber"] as? String,
              let path = dict["Path"] as? String else {
            return nil
        }
        return RadioCapture(utc: utc, racingNumber: racingNumber, path: path)
    }
}
