import Foundation

/// Car telemetry data from the CarData.z topic.
/// Channels: 0=RPM, 2=Speed, 3=Gear, 4=Throttle, 5=Brake, 45=DRS
struct CarTelemetry {
    var rpm: Int
    var speed: Int
    var gear: Int
    var throttle: Int
    var brake: Int = 0
    var drs: DRSStatus

    enum DRSStatus: Int {
        case off = 0
        case eligible = 8
        case active = 10
        case detected = 12
        case possible = 14

        init(from value: Int) {
            self = DRSStatus(rawValue: value) ?? .off
        }

        var isOpen: Bool {
            self == .active || self == .detected
        }

        var displayText: String {
            switch self {
            case .off: "OFF"
            case .eligible: "ELIG"
            case .active: "OPEN"
            case .detected: "DET"
            case .possible: "POSS"
            }
        }
    }

    /// Parse car data entries from the decompressed CarData.z JSON.
    /// Supports both object-format channels ({"0":rpm,"2":speed,...}) and array-format.
    static func parseEntries(_ json: Any) -> [String: CarTelemetry]? {
        guard let dict = json as? [String: Any],
              let entries = dict["Entries"] as? [[String: Any]],
              let lastEntry = entries.last,
              let cars = lastEntry["Cars"] as? [String: Any] else {
            return nil
        }

        var result: [String: CarTelemetry] = [:]
        for (driverNumber, carData) in cars {
            guard let carDict = carData as? [String: Any] else { continue }

            if let channels = carDict["Channels"] as? [String: Any] {
                // Object format (web app definition): "0"=RPM, "2"=Speed, "3"=Gear, "4"=Throttle, "5"=Brake, "45"=DRS
                result[driverNumber] = CarTelemetry(
                    rpm: channels["0"] as? Int ?? 0,
                    speed: channels["2"] as? Int ?? 0,
                    gear: channels["3"] as? Int ?? 0,
                    throttle: channels["4"] as? Int ?? 0,
                    brake: channels["5"] as? Int ?? 0,
                    drs: DRSStatus(from: channels["45"] as? Int ?? 0)
                )
            } else if let channels = carDict["Channels"] as? [Any] {
                // Array fallback
                let ch = channels.map { ($0 as? Int) ?? 0 }
                guard ch.count >= 6 else { continue }
                result[driverNumber] = CarTelemetry(
                    rpm: ch[0],
                    speed: ch.count > 2 ? ch[2] : 0,
                    gear: ch.count > 3 ? ch[3] : 0,
                    throttle: ch.count > 4 ? ch[4] : 0,
                    brake: ch.count > 5 ? ch[5] : 0,
                    drs: DRSStatus(from: ch.count > 45 ? ch[45] : 0)
                )
            }
        }
        return result
    }
}
