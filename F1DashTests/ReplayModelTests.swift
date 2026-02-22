import XCTest
@testable import F1Dash

final class ReplayModelTests: XCTestCase {

    // MARK: - OpenF1Session Parsing

    func testOpenF1SessionDecodesFullJSON() throws {
        let json = """
        {
            "session_key": 9158,
            "session_name": "Race",
            "session_type": "Race",
            "date_start": "2024-03-02T15:00:00+00:00",
            "date_end": "2024-03-02T17:00:00+00:00",
            "year": 2024,
            "circuit_key": 63,
            "circuit_short_name": "Sakhir",
            "country_name": "Bahrain",
            "country_code": "BHR",
            "meeting_key": 1229,
            "meeting_name": "Bahrain Grand Prix",
            "gmt_offset": "03:00:00",
            "location": "Sakhir"
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(OpenF1Session.self, from: json)
        XCTAssertEqual(session.sessionKey, 9158)
        XCTAssertEqual(session.sessionName, "Race")
        XCTAssertEqual(session.sessionType, "Race")
        XCTAssertEqual(session.year, 2024)
        XCTAssertEqual(session.circuitKey, 63)
        XCTAssertEqual(session.circuitShortName, "Sakhir")
        XCTAssertEqual(session.countryName, "Bahrain")
        XCTAssertEqual(session.countryCode, "BHR")
        XCTAssertEqual(session.meetingKey, 1229)
        XCTAssertEqual(session.meetingName, "Bahrain Grand Prix")
        XCTAssertEqual(session.displayName, "Bahrain Grand Prix")
        XCTAssertNotNil(session.startDate)
    }

    func testOpenF1SessionDecodesMinimalJSON() throws {
        let json = """
        {
            "session_key": 1000,
            "session_name": "Practice 1",
            "year": 2024
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(OpenF1Session.self, from: json)
        XCTAssertEqual(session.sessionKey, 1000)
        XCTAssertEqual(session.sessionName, "Practice 1")
        XCTAssertNil(session.sessionType)
        XCTAssertNil(session.circuitKey)
        XCTAssertNil(session.circuitShortName)
        XCTAssertNil(session.countryName)
        XCTAssertNil(session.meetingName)
        XCTAssertEqual(session.displayName, "Session 1000")
    }

    func testOpenF1SessionDisplayNameFallbacks() throws {
        // Priority: meetingName → location → countryName → "Session {key}"

        // 1. meetingName present → use meetingName
        let json1 = """
        {"session_key": 1, "session_name": "Race", "year": 2024, "meeting_name": "Spanish GP", "location": "Barcelona", "country_name": "Spain"}
        """.data(using: .utf8)!
        let s1 = try JSONDecoder().decode(OpenF1Session.self, from: json1)
        XCTAssertEqual(s1.displayName, "Spanish GP")

        // 2. No meetingName, location present → use location
        let json2 = """
        {"session_key": 2, "session_name": "Race", "year": 2024, "location": "Las Vegas", "country_name": "United States"}
        """.data(using: .utf8)!
        let s2 = try JSONDecoder().decode(OpenF1Session.self, from: json2)
        XCTAssertEqual(s2.displayName, "Las Vegas")

        // 3. No meetingName or location, countryName present → use countryName
        let json3 = """
        {"session_key": 3, "session_name": "Race", "year": 2024, "country_name": "Spain"}
        """.data(using: .utf8)!
        let s3 = try JSONDecoder().decode(OpenF1Session.self, from: json3)
        XCTAssertEqual(s3.displayName, "Spain")

        // 4. Nothing → fallback "Session {key}"
        let json4 = """
        {"session_key": 4, "session_name": "Race", "year": 2024}
        """.data(using: .utf8)!
        let s4 = try JSONDecoder().decode(OpenF1Session.self, from: json4)
        XCTAssertEqual(s4.displayName, "Session 4")
    }

    /// Regression test: OpenF1 API returns meeting_name=null for all sessions.
    /// displayName must use location to distinguish US GPs (Miami, Austin, Las Vegas).
    func testDisplayNameDistinguishesUSGrandPrix() throws {
        let miami = """
        {"session_key": 100, "session_name": "Race", "year": 2024, "location": "Miami", "country_name": "United States"}
        """.data(using: .utf8)!
        let austin = """
        {"session_key": 101, "session_name": "Race", "year": 2024, "location": "Austin", "country_name": "United States"}
        """.data(using: .utf8)!
        let vegas = """
        {"session_key": 102, "session_name": "Race", "year": 2024, "location": "Las Vegas", "country_name": "United States"}
        """.data(using: .utf8)!

        let sMiami = try JSONDecoder().decode(OpenF1Session.self, from: miami)
        let sAustin = try JSONDecoder().decode(OpenF1Session.self, from: austin)
        let sVegas = try JSONDecoder().decode(OpenF1Session.self, from: vegas)

        // Each must have a unique displayName
        XCTAssertEqual(sMiami.displayName, "Miami")
        XCTAssertEqual(sAustin.displayName, "Austin")
        XCTAssertEqual(sVegas.displayName, "Las Vegas")
        XCTAssertNotEqual(sMiami.displayName, sAustin.displayName)
        XCTAssertNotEqual(sAustin.displayName, sVegas.displayName)
    }

    func testOpenF1SessionHashable() throws {
        let json = """
        {"session_key": 100, "session_name": "Q", "year": 2024}
        """.data(using: .utf8)!
        let s1 = try JSONDecoder().decode(OpenF1Session.self, from: json)
        let s2 = try JSONDecoder().decode(OpenF1Session.self, from: json)
        XCTAssertEqual(s1, s2)
        XCTAssertEqual(s1.hashValue, s2.hashValue)
    }

    func testOpenF1SessionId() throws {
        let json = """
        {"session_key": 42, "session_name": "Race", "year": 2024}
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(OpenF1Session.self, from: json)
        XCTAssertEqual(session.id, 42)
    }

    // MARK: - OpenF1Driver Parsing

    func testOpenF1DriverDecodesFullJSON() throws {
        let json = """
        {
            "driver_number": 1,
            "broadcast_name": "M VERSTAPPEN",
            "full_name": "Max VERSTAPPEN",
            "name_acronym": "VER",
            "team_name": "Red Bull Racing",
            "team_colour": "3671C6",
            "country_code": "NED",
            "session_key": 9158,
            "meeting_key": 1229
        }
        """.data(using: .utf8)!

        let driver = try JSONDecoder().decode(OpenF1Driver.self, from: json)
        XCTAssertEqual(driver.driverNumber, 1)
        XCTAssertEqual(driver.broadcastName, "M VERSTAPPEN")
        XCTAssertEqual(driver.fullName, "Max VERSTAPPEN")
        XCTAssertEqual(driver.tla, "VER")
        XCTAssertEqual(driver.displayName, "Max VERSTAPPEN")
        XCTAssertEqual(driver.teamName, "Red Bull Racing")
        XCTAssertEqual(driver.teamColour, "3671C6")
    }

    func testOpenF1DriverMinimalJSON() throws {
        let json = """
        {"driver_number": 99}
        """.data(using: .utf8)!

        let driver = try JSONDecoder().decode(OpenF1Driver.self, from: json)
        XCTAssertEqual(driver.driverNumber, 99)
        XCTAssertEqual(driver.tla, "99")
        XCTAssertEqual(driver.displayName, "Driver 99")
    }

    // MARK: - Historical Data Parsing

    func testHistoricalPositionDecode() throws {
        let json = """
        {"driver_number": 44, "date": "2024-03-02T15:30:00.000+00:00", "position": 3}
        """.data(using: .utf8)!

        let pos = try JSONDecoder().decode(HistoricalPosition.self, from: json)
        XCTAssertEqual(pos.driverNumber, 44)
        XCTAssertEqual(pos.position, 3)
    }

    func testHistoricalLapDecode() throws {
        let json = """
        {
            "driver_number": 1,
            "lap_number": 15,
            "lap_duration": 92.456,
            "duration_sector_1": 28.123,
            "duration_sector_2": 33.789,
            "duration_sector_3": 30.544,
            "is_pit_out_lap": false,
            "date_start": "2024-03-02T15:30:00.000+00:00"
        }
        """.data(using: .utf8)!

        let lap = try JSONDecoder().decode(HistoricalLap.self, from: json)
        XCTAssertEqual(lap.driverNumber, 1)
        XCTAssertEqual(lap.lapNumber, 15)
        XCTAssertEqual(lap.lapDuration, 92.456)
        XCTAssertEqual(lap.durationSector1, 28.123)
        XCTAssertEqual(lap.durationSector2, 33.789)
        XCTAssertEqual(lap.durationSector3, 30.544)
        XCTAssertEqual(lap.isPitOutLap, false)
    }

    func testHistoricalLapDecodeMinimal() throws {
        let json = """
        {"driver_number": 44, "lap_number": 1}
        """.data(using: .utf8)!

        let lap = try JSONDecoder().decode(HistoricalLap.self, from: json)
        XCTAssertEqual(lap.driverNumber, 44)
        XCTAssertEqual(lap.lapNumber, 1)
        XCTAssertNil(lap.lapDuration)
        XCTAssertNil(lap.durationSector1)
        XCTAssertNil(lap.dateStart)
    }

    func testHistoricalIntervalDecode() throws {
        let json = """
        {"driver_number": 1, "date": "2024-03-02T15:30:00Z", "gap_to_leader": 0.0, "interval": 0.0}
        """.data(using: .utf8)!

        let interval = try JSONDecoder().decode(HistoricalInterval.self, from: json)
        XCTAssertEqual(interval.driverNumber, 1)
        XCTAssertEqual(interval.gapToLeader, 0.0)
        XCTAssertEqual(interval.interval, 0.0)
        XCTAssertNil(interval.gapToLeaderText)
        XCTAssertNil(interval.intervalText)
    }

    func testHistoricalIntervalStringValues() throws {
        let json = """
        {"driver_number": 18, "date": "2024-03-02T16:30:00Z", "gap_to_leader": "+1 LAP", "interval": "+1 LAP"}
        """.data(using: .utf8)!

        let interval = try JSONDecoder().decode(HistoricalInterval.self, from: json)
        XCTAssertEqual(interval.driverNumber, 18)
        XCTAssertNil(interval.gapToLeader)
        XCTAssertEqual(interval.gapToLeaderText, "+1 LAP")
        XCTAssertNil(interval.interval)
        XCTAssertEqual(interval.intervalText, "+1 LAP")
    }

    func testHistoricalRaceControlDecode() throws {
        let json = """
        {
            "date": "2024-03-02T15:30:00Z",
            "category": "Flag",
            "flag": "GREEN",
            "message": "GREEN LIGHT - PIT LANE OPEN",
            "scope": "Track",
            "sector": null,
            "driver_number": null,
            "lap_number": 1
        }
        """.data(using: .utf8)!

        let rc = try JSONDecoder().decode(HistoricalRaceControl.self, from: json)
        XCTAssertEqual(rc.category, "Flag")
        XCTAssertEqual(rc.flag, "GREEN")
        XCTAssertEqual(rc.message, "GREEN LIGHT - PIT LANE OPEN")
        XCTAssertEqual(rc.scope, "Track")
        XCTAssertNil(rc.sector)
        XCTAssertNil(rc.driverNumber)
        XCTAssertEqual(rc.lapNumber, 1)
    }

    func testHistoricalTeamRadioDecode() throws {
        let json = """
        {
            "driver_number": 1,
            "date": "2024-03-02T15:30:00Z",
            "recording_url": "https://example.com/radio.mp3"
        }
        """.data(using: .utf8)!

        let radio = try JSONDecoder().decode(HistoricalTeamRadio.self, from: json)
        XCTAssertEqual(radio.driverNumber, 1)
        XCTAssertEqual(radio.recordingUrl, "https://example.com/radio.mp3")
    }

    func testHistoricalWeatherDecode() throws {
        let json = """
        {
            "date": "2024-03-02T15:30:00Z",
            "air_temperature": 28.5,
            "track_temperature": 42.3,
            "humidity": 45.0,
            "pressure": 1013.0,
            "wind_speed": 3.2,
            "wind_direction": 180,
            "rainfall": 0
        }
        """.data(using: .utf8)!

        let weather = try JSONDecoder().decode(HistoricalWeather.self, from: json)
        XCTAssertEqual(weather.airTemperature, 28.5)
        XCTAssertEqual(weather.trackTemperature, 42.3)
        XCTAssertEqual(weather.humidity, 45.0)
        XCTAssertEqual(weather.pressure, 1013.0)
        XCTAssertEqual(weather.windSpeed, 3.2)
        XCTAssertEqual(weather.windDirection, 180)
        XCTAssertEqual(weather.rainfall, 0)
    }

    func testHistoricalLocationDecode() throws {
        let json = """
        {"driver_number": 1, "date": "2024-03-02T15:30:00Z", "x": 1234.5, "y": 5678.9, "z": 0.0}
        """.data(using: .utf8)!

        let loc = try JSONDecoder().decode(HistoricalLocation.self, from: json)
        XCTAssertEqual(loc.driverNumber, 1)
        XCTAssertEqual(loc.x, 1234.5)
        XCTAssertEqual(loc.y, 5678.9)
        XCTAssertEqual(loc.z, 0.0)
    }

    func testHistoricalCarDataDecode() throws {
        // Uses actual API field names: "rpm" for RPM, "n_gear" for gear
        let json = """
        {
            "driver_number": 1,
            "date": "2024-03-02T15:30:00Z",
            "speed": 315,
            "rpm": 11141,
            "n_gear": 8,
            "throttle": 100,
            "brake": 0,
            "drs": 10
        }
        """.data(using: .utf8)!

        let car = try JSONDecoder().decode(HistoricalCarData.self, from: json)
        XCTAssertEqual(car.driverNumber, 1)
        XCTAssertEqual(car.speed, 315)
        XCTAssertEqual(car.rpm, 11141)
        XCTAssertEqual(car.gear, 8)
        XCTAssertEqual(car.throttle, 100)
        XCTAssertEqual(car.brake, 0)
        XCTAssertEqual(car.drs, 10)
    }

    func testHistoricalCarDataDecodeMinimal() throws {
        let json = """
        {"driver_number": 44, "date": "2024-03-02T15:30:00Z"}
        """.data(using: .utf8)!

        let car = try JSONDecoder().decode(HistoricalCarData.self, from: json)
        XCTAssertEqual(car.driverNumber, 44)
        XCTAssertNil(car.speed)
        XCTAssertNil(car.rpm)
        XCTAssertNil(car.gear)
        XCTAssertNil(car.throttle)
        XCTAssertNil(car.brake)
        XCTAssertNil(car.drs)
    }

    // MARK: - OpenF1 Date Parsing

    func testParseOpenF1DateISO8601() {
        let date = parseOpenF1Date("2024-03-02T15:30:00.000Z")
        XCTAssertNotNil(date)

        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 2)
        XCTAssertEqual(components.hour, 15)
        XCTAssertEqual(components.minute, 30)
    }

    func testParseOpenF1DateWithOffset() {
        let date = parseOpenF1Date("2024-03-02T15:30:00.000000+00:00")
        XCTAssertNotNil(date)
    }

    func testParseOpenF1DateWithoutZ() {
        let date = parseOpenF1Date("2024-03-02T15:30:00.000000")
        XCTAssertNotNil(date)
    }

    func testParseOpenF1DateInvalid() {
        XCTAssertNil(parseOpenF1Date("not-a-date"))
    }

    func testParseOpenF1DateWithoutFractional() {
        let date = parseOpenF1Date("2024-03-02T15:30:00Z")
        XCTAssertNotNil(date)
    }

    /// Regression: OpenF1 session dates have no fractional seconds but include timezone offset.
    /// e.g. "2024-11-24T06:00:00+00:00" — must parse correctly for replay to work.
    func testParseOpenF1DateSessionFormat() {
        let date = parseOpenF1Date("2024-11-24T06:00:00+00:00")
        XCTAssertNotNil(date, "Session date format (no fractional seconds, +00:00 offset) must parse")

        if let date {
            let cal = Calendar(identifier: .gregorian)
            let comps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
            XCTAssertEqual(comps.year, 2024)
            XCTAssertEqual(comps.month, 11)
            XCTAssertEqual(comps.day, 24)
            XCTAssertEqual(comps.hour, 6)
        }
    }

    /// Test all date formats seen in OpenF1 API responses.
    func testParseOpenF1DateAllFormats() {
        // Intervals/positions: microseconds + offset
        XCTAssertNotNil(parseOpenF1Date("2024-11-24T05:07:15.960000+00:00"))
        // Standard ISO8601 with Z
        XCTAssertNotNil(parseOpenF1Date("2024-03-02T15:30:00.000Z"))
        // Session dates: no fractional, with offset
        XCTAssertNotNil(parseOpenF1Date("2024-11-24T06:00:00+00:00"))
        // Without timezone
        XCTAssertNotNil(parseOpenF1Date("2024-03-02T15:30:00.000000"))
        // Plain Z suffix
        XCTAssertNotNil(parseOpenF1Date("2024-03-02T15:30:00Z"))
    }

    /// Verify parsed dates have correct chronological order.
    func testParseOpenF1DateChronologicalOrder() {
        let d1 = parseOpenF1Date("2024-11-24T05:00:00+00:00")!
        let d2 = parseOpenF1Date("2024-11-24T06:00:00.000000+00:00")!
        let d3 = parseOpenF1Date("2024-11-24T07:00:00Z")!
        XCTAssertTrue(d1 < d2)
        XCTAssertTrue(d2 < d3)
    }

    // MARK: - ReplaySpeed

    func testReplaySpeedValues() {
        XCTAssertEqual(ReplaySpeed.x1.rawValue, 1.0)
        XCTAssertEqual(ReplaySpeed.x2.rawValue, 2.0)
        XCTAssertEqual(ReplaySpeed.x4.rawValue, 4.0)
        XCTAssertEqual(ReplaySpeed.x8.rawValue, 8.0)
        XCTAssertEqual(ReplaySpeed.x16.rawValue, 16.0)
    }

    func testReplaySpeedLabels() {
        XCTAssertEqual(ReplaySpeed.x1.label, "1x")
        XCTAssertEqual(ReplaySpeed.x2.label, "2x")
        XCTAssertEqual(ReplaySpeed.x4.label, "4x")
        XCTAssertEqual(ReplaySpeed.x8.label, "8x")
        XCTAssertEqual(ReplaySpeed.x16.label, "16x")
    }

    func testReplaySpeedAllCases() {
        XCTAssertEqual(ReplaySpeed.allCases.count, 5)
    }

    // MARK: - ReplayState

    func testReplayStateIsActive() {
        XCTAssertFalse(ReplayState.idle.isActive)
        XCTAssertFalse(ReplayState.loading.isActive)
        XCTAssertFalse(ReplayState.ready.isActive)
        XCTAssertTrue(ReplayState.playing.isActive)
        XCTAssertTrue(ReplayState.paused.isActive)
        XCTAssertFalse(ReplayState.finished.isActive)
        XCTAssertFalse(ReplayState.error("test").isActive)
    }

    func testReplayStateEquatable() {
        XCTAssertEqual(ReplayState.idle, ReplayState.idle)
        XCTAssertEqual(ReplayState.playing, ReplayState.playing)
        XCTAssertEqual(ReplayState.error("a"), ReplayState.error("a"))
        XCTAssertNotEqual(ReplayState.error("a"), ReplayState.error("b"))
        XCTAssertNotEqual(ReplayState.idle, ReplayState.playing)
    }

    // MARK: - ReplayEvent

    func testReplayEventTimestamp() {
        let date = Date(timeIntervalSince1970: 1000)
        let event = ReplayEvent(
            timestamp: date,
            kind: .position(driverNumber: 1, position: 1)
        )
        XCTAssertEqual(event.timestamp, date)
    }
}
