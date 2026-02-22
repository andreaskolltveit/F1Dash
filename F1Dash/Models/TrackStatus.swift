import Foundation
import SwiftUI

/// Track status from the TrackStatus topic.
struct TrackStatus {
    var status: TrackStatusCode
    var message: String

    enum TrackStatusCode: String {
        case allClear = "1"
        case yellowFlag = "2"
        case scFlag = "3"        // Unused in practice but reserved
        case safetyCar = "4"
        case redFlag = "5"
        case vscDeployed = "6"
        case vscEnding = "7"

        init(from value: String?) {
            guard let v = value else { self = .allClear; return }
            self = TrackStatusCode(rawValue: v) ?? .allClear
        }

        var color: Color {
            switch self {
            case .allClear: .green
            case .yellowFlag, .safetyCar, .vscDeployed, .vscEnding: .yellow
            case .redFlag: .red
            case .scFlag: .yellow
            }
        }

        var displayName: String {
            switch self {
            case .allClear: "Track Clear"
            case .yellowFlag: "Yellow Flag"
            case .scFlag: "SC Flag"
            case .safetyCar: "Safety Car"
            case .redFlag: "Red Flag"
            case .vscDeployed: "VSC Deployed"
            case .vscEnding: "VSC Ending"
            }
        }

        var isHazard: Bool {
            self != .allClear
        }
    }

    /// Parse from raw JSON dictionary.
    static func from(dict: [String: Any]) -> TrackStatus {
        TrackStatus(
            status: .init(from: dict["Status"] as? String),
            message: dict["Message"] as? String ?? ""
        )
    }
}
