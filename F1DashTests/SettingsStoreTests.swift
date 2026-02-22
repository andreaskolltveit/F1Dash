import XCTest
@testable import F1Dash

final class SettingsStoreTests: XCTestCase {

    // MARK: - SpeedUnit

    func testSpeedUnitKmhConvert() {
        XCTAssertEqual(SpeedUnit.kmh.convert(300), 300)
        XCTAssertEqual(SpeedUnit.kmh.convert(0), 0)
    }

    func testSpeedUnitMphConvert() {
        let mph = SpeedUnit.mph.convert(300)
        XCTAssertEqual(mph, 186)  // 300 * 0.621371 = 186.4

        XCTAssertEqual(SpeedUnit.mph.convert(0), 0)
        XCTAssertEqual(SpeedUnit.mph.convert(100), 62)  // 100 * 0.621371 = 62.1
    }

    func testSpeedUnitRawValues() {
        XCTAssertEqual(SpeedUnit.kmh.rawValue, "km/h")
        XCTAssertEqual(SpeedUnit.mph.rawValue, "mph")
    }

    func testSpeedUnitAllCases() {
        XCTAssertEqual(SpeedUnit.allCases.count, 2)
        XCTAssertTrue(SpeedUnit.allCases.contains(.kmh))
        XCTAssertTrue(SpeedUnit.allCases.contains(.mph))
    }

    func testSpeedUnitIdentifiable() {
        XCTAssertEqual(SpeedUnit.kmh.id, "km/h")
        XCTAssertEqual(SpeedUnit.mph.id, "mph")
    }

    func testSpeedUnitFromRawValue() {
        XCTAssertEqual(SpeedUnit(rawValue: "km/h"), .kmh)
        XCTAssertEqual(SpeedUnit(rawValue: "mph"), .mph)
        XCTAssertNil(SpeedUnit(rawValue: "invalid"))
    }

    // MARK: - SettingsStore Defaults

    func testSettingsStoreDefaults() {
        // Clear any stored values for testing
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "delaySeconds")
        defaults.removeObject(forKey: "showCornerNumbers")
        defaults.removeObject(forKey: "speedUnit")
        defaults.removeObject(forKey: "oledMode")
        defaults.removeObject(forKey: "favoriteDrivers")

        let settings = SettingsStore()

        XCTAssertEqual(settings.delaySeconds, 0)
        XCTAssertFalse(settings.showCornerNumbers)
        XCTAssertEqual(settings.speedUnit, .kmh)
        XCTAssertFalse(settings.oledMode)
        XCTAssertTrue(settings.favoriteDrivers.isEmpty)
    }

    func testSettingsStoreFavoriteToggle() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "favoriteDrivers")

        let settings = SettingsStore()

        // Toggle on
        settings.toggleFavorite("1")
        XCTAssertTrue(settings.favoriteDrivers.contains("1"))

        // Toggle off
        settings.toggleFavorite("1")
        XCTAssertFalse(settings.favoriteDrivers.contains("1"))
    }

    func testSettingsStoreMultipleFavorites() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "favoriteDrivers")

        let settings = SettingsStore()
        settings.toggleFavorite("1")
        settings.toggleFavorite("44")
        settings.toggleFavorite("16")

        XCTAssertEqual(settings.favoriteDrivers.count, 3)
        XCTAssertTrue(settings.favoriteDrivers.contains("1"))
        XCTAssertTrue(settings.favoriteDrivers.contains("44"))
        XCTAssertTrue(settings.favoriteDrivers.contains("16"))

        settings.toggleFavorite("44")
        XCTAssertEqual(settings.favoriteDrivers.count, 2)
        XCTAssertFalse(settings.favoriteDrivers.contains("44"))
    }

    func testSettingsStorePersistence() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "delaySeconds")
        defaults.removeObject(forKey: "speedUnit")
        defaults.removeObject(forKey: "oledMode")

        let settings = SettingsStore()
        settings.delaySeconds = 30
        settings.speedUnit = .mph
        settings.oledMode = true

        // Verify UserDefaults was updated
        XCTAssertEqual(defaults.integer(forKey: "delaySeconds"), 30)
        XCTAssertEqual(defaults.string(forKey: "speedUnit"), "mph")
        XCTAssertTrue(defaults.bool(forKey: "oledMode"))

        // Create a new instance and verify persistence
        let settings2 = SettingsStore()
        XCTAssertEqual(settings2.delaySeconds, 30)
        XCTAssertEqual(settings2.speedUnit, .mph)
        XCTAssertTrue(settings2.oledMode)

        // Clean up
        defaults.removeObject(forKey: "delaySeconds")
        defaults.removeObject(forKey: "speedUnit")
        defaults.removeObject(forKey: "oledMode")
    }

    // MARK: - DRSStatus

    func testDRSStatusValues() {
        XCTAssertEqual(CarTelemetry.DRSStatus(rawValue: 0), .off)
        XCTAssertEqual(CarTelemetry.DRSStatus(rawValue: 8), .eligible)
        XCTAssertEqual(CarTelemetry.DRSStatus(rawValue: 10), .active)
        XCTAssertEqual(CarTelemetry.DRSStatus(rawValue: 12), .detected)
        XCTAssertEqual(CarTelemetry.DRSStatus(rawValue: 14), .possible)
    }

    func testDRSStatusIsOpen() {
        XCTAssertFalse(CarTelemetry.DRSStatus.off.isOpen)
        XCTAssertFalse(CarTelemetry.DRSStatus.eligible.isOpen)
        XCTAssertTrue(CarTelemetry.DRSStatus.active.isOpen)
        XCTAssertTrue(CarTelemetry.DRSStatus.detected.isOpen)
        XCTAssertFalse(CarTelemetry.DRSStatus.possible.isOpen)
    }

    func testDRSStatusDisplayText() {
        XCTAssertNotNil(CarTelemetry.DRSStatus.off.displayText)
        XCTAssertNotNil(CarTelemetry.DRSStatus.active.displayText)
        XCTAssertNotNil(CarTelemetry.DRSStatus.eligible.displayText)
    }
}
