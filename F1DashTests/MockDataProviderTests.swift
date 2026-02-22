import XCTest
@testable import F1Dash

final class MockDataProviderTests: XCTestCase {

    // MARK: - Verify all mock data is populated

    func testDriversComplete() {
        let drivers = MockDataProvider.drivers
        XCTAssertEqual(drivers.count, 20, "Full 2025 grid should have 20 drivers")

        // Check some known drivers
        XCTAssertEqual(drivers["1"]?.tla, "VER")
        XCTAssertEqual(drivers["44"]?.tla, "HAM")
        XCTAssertEqual(drivers["4"]?.tla, "NOR")
        XCTAssertEqual(drivers["16"]?.tla, "LEC")

        // Every driver should have a team colour
        for (_, driver) in drivers {
            XCTAssertFalse(driver.teamColour.isEmpty, "Driver \(driver.tla) missing team colour")
            XCTAssertFalse(driver.tla.isEmpty, "Driver \(driver.id) missing TLA")
            XCTAssertFalse(driver.fullName.isEmpty, "Driver \(driver.tla) missing full name")
        }
    }

    func testSessionInfo() {
        let info = MockDataProvider.sessionInfo
        XCTAssertEqual(info.meetingName, "Bahrain Grand Prix")
        XCTAssertEqual(info.sessionName, "Race")
        XCTAssertEqual(info.meetingCircuitKey, 63)
        XCTAssertFalse(info.sessionPath.isEmpty)
    }

    func testRaceControlMessages() {
        let msgs = MockDataProvider.raceControlMessages
        XCTAssertGreaterThan(msgs.count, 10, "Should have multiple RC messages")

        // Should contain different flag types
        let flags = Set(msgs.compactMap(\.flag))
        XCTAssertTrue(flags.contains(.green))
        XCTAssertTrue(flags.contains(.yellow))
        XCTAssertTrue(flags.contains(.blue))
        XCTAssertTrue(flags.contains(.doubleYellow))

        // Should contain blue flags (for filter testing)
        let blueFlags = msgs.filter(\.isBlueFlag)
        XCTAssertGreaterThan(blueFlags.count, 0)

        // Messages should be in chronological order
        for i in 1..<msgs.count {
            XCTAssertGreaterThanOrEqual(msgs[i].utc, msgs[i-1].utc,
                "Messages should be chronologically ordered")
        }
    }

    func testTeamRadioCaptures() {
        let captures = MockDataProvider.teamRadioCaptures
        XCTAssertGreaterThan(captures.count, 5, "Should have multiple radio captures")

        // Each should have a valid racing number
        for capture in captures {
            XCTAssertFalse(capture.racingNumber.isEmpty)
            XCTAssertFalse(capture.path.isEmpty)
            XCTAssertNotNil(MockDataProvider.drivers[capture.racingNumber],
                "Radio capture should reference a known driver")
        }
    }

    func testTimingData() {
        let timing = MockDataProvider.timingData
        XCTAssertEqual(timing.count, 20, "All 20 drivers should have timing data")

        // Check positions are 1-20
        let positions = Set(timing.values.compactMap(\.position).compactMap(Int.init))
        XCTAssertEqual(positions, Set(1...20))

        // Leader should have empty gap
        let leader = timing.values.first { $0.position == "1" }
        XCTAssertEqual(leader?.gapToLeader, "")

        // All should have sectors with segments
        for (num, driver) in timing {
            XCTAssertEqual(driver.sectors.count, 3, "Driver \(num) should have 3 sectors")
            for (i, sector) in driver.sectors.enumerated() {
                XCTAssertEqual(sector.segments.count, 8,
                    "Driver \(num) sector \(i) should have 8 segments")
            }
        }
    }

    func testCarTelemetry() {
        let telemetry = MockDataProvider.carTelemetry
        XCTAssertEqual(telemetry.count, 20)

        for (_, car) in telemetry {
            XCTAssertGreaterThan(car.rpm, 0)
            XCTAssertGreaterThan(car.speed, 0)
            XCTAssertGreaterThan(car.gear, 0)
        }
    }

    func testDriverPositions() {
        let positions = MockDataProvider.driverPositions
        XCTAssertEqual(positions.count, 20)

        // Most should be on track
        let onTrack = positions.values.filter(\.isOnTrack)
        XCTAssertGreaterThan(onTrack.count, 15)

        // At least one off track (OCO in pit)
        let offTrack = positions.values.filter { !$0.isOnTrack }
        XCTAssertGreaterThan(offTrack.count, 0)
    }

    func testWeatherData() {
        let weather = MockDataProvider.weather
        XCTAssertNotNil(weather.airTemp)
        XCTAssertNotNil(weather.trackTemp)
        XCTAssertNotNil(weather.humidity)
        XCTAssertFalse(weather.rainfall, "Bahrain should not have rain")
    }

    func testTrackMap() {
        let map = MockDataProvider.trackMap
        XCTAssertGreaterThan(map.x.count, 50, "Track should have many points")
        XCTAssertEqual(map.x.count, map.y.count, "X and Y arrays must match")
        XCTAssertGreaterThan(map.points.count, 50)
    }

    func testLapCount() {
        let laps = MockDataProvider.lapCount
        XCTAssertGreaterThan(laps.currentLap, 0)
        XCTAssertGreaterThan(laps.totalLaps, laps.currentLap)
    }

    // MARK: - Store Loading

    func testLoadIntoStore() {
        let store = LiveTimingStore()
        MockDataProvider.loadIntoStore(store)

        XCTAssertEqual(store.drivers.count, 20)
        XCTAssertGreaterThan(store.raceControlMessages.count, 0)
        XCTAssertGreaterThan(store.teamRadioCaptures.count, 0)
        XCTAssertNotNil(store.sessionInfo)
        XCTAssertEqual(store.sessionStatus, .started)
        XCTAssertNotNil(store.weatherData)
        XCTAssertNotNil(store.extrapolatedClock)
        XCTAssertNotNil(store.lapCount)
        XCTAssertNotNil(store.trackMap)
        XCTAssertEqual(store.timingData.count, 20)
        XCTAssertEqual(store.carTelemetry.count, 20)
        XCTAssertEqual(store.driverPositions.count, 20)
        XCTAssertEqual(store.driversSorted.count, 20)

        // Verify sort order
        let sorted = store.driversSorted
        XCTAssertEqual(sorted.first?.tla, "VER", "First driver should be VER (line 1)")
    }
}
