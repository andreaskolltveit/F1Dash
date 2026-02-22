import Foundation
import SwiftUI

/// Speed unit for display.
enum SpeedUnit: String, CaseIterable, Identifiable {
    case kmh = "km/h"
    case mph = "mph"

    var id: String { rawValue }

    func convert(_ kmh: Int) -> Int {
        switch self {
        case .kmh: kmh
        case .mph: Int(Double(kmh) * 0.621371)
        }
    }
}

/// User settings backed by UserDefaults.
@Observable
final class SettingsStore {
    private let defaults = UserDefaults.standard

    /// Whether to play chime on race control messages.
    var chimeEnabled: Bool {
        didSet { defaults.set(chimeEnabled, forKey: "chimeEnabled") }
    }

    /// Chime volume (0.0 to 1.0).
    var chimeVolume: Float {
        didSet { defaults.set(chimeVolume, forKey: "chimeVolume") }
    }

    /// Whether to filter out blue flag messages in Race Control view.
    var filterBlueFlags: Bool {
        didSet { defaults.set(filterBlueFlags, forKey: "filterBlueFlags") }
    }

    /// Favorite driver numbers for highlighting.
    var favoriteDrivers: Set<String> {
        didSet {
            defaults.set(Array(favoriteDrivers), forKey: "favoriteDrivers")
        }
    }

    /// Auto-reconnect on disconnect.
    var autoReconnect: Bool {
        didSet { defaults.set(autoReconnect, forKey: "autoReconnect") }
    }

    /// Show car metrics (gear, speed, throttle/brake) in leaderboard.
    var showCarMetrics: Bool {
        didSet { defaults.set(showCarMetrics, forKey: "showCarMetrics") }
    }

    /// Whether sidebar is collapsed.
    var sidebarCollapsed: Bool {
        didSet { defaults.set(sidebarCollapsed, forKey: "sidebarCollapsed") }
    }

    // MARK: - New Settings (Fase 4)

    /// Delay buffer in seconds (0-120). Delays all data for spoiler-free viewing.
    var delaySeconds: Int {
        didSet { defaults.set(delaySeconds, forKey: "delaySeconds") }
    }

    /// Show corner numbers on track map.
    var showCornerNumbers: Bool {
        didSet { defaults.set(showCornerNumbers, forKey: "showCornerNumbers") }
    }

    /// Speed display unit (km/h or mph).
    var speedUnit: SpeedUnit {
        didSet { defaults.set(speedUnit.rawValue, forKey: "speedUnit") }
    }

    /// OLED mode — pure black background for OLED displays.
    var oledMode: Bool {
        didSet { defaults.set(oledMode, forKey: "oledMode") }
    }

    init() {
        self.chimeEnabled = defaults.object(forKey: "chimeEnabled") as? Bool ?? true
        self.chimeVolume = defaults.object(forKey: "chimeVolume") as? Float ?? 0.5
        self.filterBlueFlags = defaults.object(forKey: "filterBlueFlags") as? Bool ?? true
        self.autoReconnect = defaults.object(forKey: "autoReconnect") as? Bool ?? true
        self.showCarMetrics = defaults.object(forKey: "showCarMetrics") as? Bool ?? false
        self.sidebarCollapsed = defaults.object(forKey: "sidebarCollapsed") as? Bool ?? false

        // New settings
        self.delaySeconds = defaults.object(forKey: "delaySeconds") as? Int ?? 0
        self.showCornerNumbers = defaults.object(forKey: "showCornerNumbers") as? Bool ?? false
        self.oledMode = defaults.object(forKey: "oledMode") as? Bool ?? false

        if let speedStr = defaults.string(forKey: "speedUnit"),
           let unit = SpeedUnit(rawValue: speedStr) {
            self.speedUnit = unit
        } else {
            self.speedUnit = .kmh
        }

        if let saved = defaults.stringArray(forKey: "favoriteDrivers") {
            self.favoriteDrivers = Set(saved)
        } else {
            self.favoriteDrivers = []
        }
    }

    func toggleFavorite(_ driverNumber: String) {
        if favoriteDrivers.contains(driverNumber) {
            favoriteDrivers.remove(driverNumber)
        } else {
            favoriteDrivers.insert(driverNumber)
        }
    }
}
