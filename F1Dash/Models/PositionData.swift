import Foundation

/// Position data from the Position.z topic.
/// Contains X, Y, Z coordinates for each driver on the track.
struct DriverPosition: Equatable {
    var x: Double
    var y: Double
    var z: Double
    var status: String  // "OnTrack", "OffTrack"

    var isOnTrack: Bool {
        status == "OnTrack"
    }

    /// Parse position entries from the decompressed Position.z JSON.
    /// Format: {"Position": [{"Timestamp":"...","Entries":{"1":{"X":1234,"Y":5678,"Z":0,"Status":"OnTrack"}}}]}
    static func parseEntries(_ json: Any) -> [String: DriverPosition]? {
        guard let dict = json as? [String: Any],
              let positions = dict["Position"] as? [[String: Any]],
              let lastPosition = positions.last,
              let entries = lastPosition["Entries"] as? [String: Any] else {
            return nil
        }

        var result: [String: DriverPosition] = [:]
        for (driverNumber, posData) in entries {
            guard let posDict = posData as? [String: Any] else { continue }
            result[driverNumber] = DriverPosition(
                x: (posDict["X"] as? Double) ?? Double(posDict["X"] as? Int ?? 0),
                y: (posDict["Y"] as? Double) ?? Double(posDict["Y"] as? Int ?? 0),
                z: (posDict["Z"] as? Double) ?? Double(posDict["Z"] as? Int ?? 0),
                status: posDict["Status"] as? String ?? "OnTrack"
            )
        }
        return result
    }
}
