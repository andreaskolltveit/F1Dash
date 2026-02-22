import XCTest
@testable import F1Dash

/// Tests for all OpenF1 API endpoint model decoding.
/// Each test uses realistic JSON matching the actual API response format.
/// Reference: https://openf1.org
final class OpenF1EndpointTests: XCTestCase {

    // MARK: - /v1/sessions

    func testSessionsEndpointFullResponse() throws {
        let json = """
        [
            {
                "session_key": 9158,
                "session_name": "Race",
                "session_type": "Race",
                "date_start": "2023-09-17T13:00:00+00:00",
                "date_end": "2023-09-17T15:00:00+00:00",
                "year": 2023,
                "circuit_key": 61,
                "circuit_short_name": "Marina Bay",
                "country_name": "Singapore",
                "country_code": "SGP",
                "meeting_key": 1219,
                "meeting_name": "Singapore Grand Prix",
                "gmt_offset": "08:00:00",
                "location": "Marina Bay"
            }
        ]
        """.data(using: .utf8)!

        let sessions = try JSONDecoder().decode([OpenF1Session].self, from: json)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]
        XCTAssertEqual(s.sessionKey, 9158)
        XCTAssertEqual(s.sessionName, "Race")
        XCTAssertEqual(s.sessionType, "Race")
        XCTAssertEqual(s.year, 2023)
        XCTAssertEqual(s.circuitKey, 61)
        XCTAssertEqual(s.circuitShortName, "Marina Bay")
        XCTAssertEqual(s.countryName, "Singapore")
        XCTAssertEqual(s.countryCode, "SGP")
        XCTAssertEqual(s.meetingKey, 1219)
        XCTAssertEqual(s.meetingName, "Singapore Grand Prix")
        XCTAssertEqual(s.gmtOffset, "08:00:00")
        XCTAssertEqual(s.location, "Marina Bay")
        XCTAssertEqual(s.id, 9158)
        XCTAssertNotNil(s.startDate)
        XCTAssertEqual(s.displayName, "Singapore Grand Prix")
    }

    func testSessionsEndpointExtraFieldsIgnored() throws {
        // API may add new fields — decoder should ignore unknown keys
        let json = """
        {
            "session_key": 1000,
            "session_name": "Sprint",
            "year": 2025,
            "some_future_field": "value",
            "another_new_field": 42
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(OpenF1Session.self, from: json)
        XCTAssertEqual(session.sessionKey, 1000)
        XCTAssertEqual(session.sessionName, "Sprint")
    }

    func testSessionsEmptyArray() throws {
        let json = "[]".data(using: .utf8)!
        let sessions = try JSONDecoder().decode([OpenF1Session].self, from: json)
        XCTAssertTrue(sessions.isEmpty)
    }

    // MARK: - /v1/drivers

    func testDriversEndpointFullResponse() throws {
        let json = """
        [
            {
                "broadcast_name": "M VERSTAPPEN",
                "driver_number": 1,
                "first_name": "Max",
                "full_name": "Max VERSTAPPEN",
                "headshot_url": "https://www.formula1.com/content/dam/fom-website/drivers/M/MAXVER01_Max_Verstappen/maxver01.png",
                "last_name": "Verstappen",
                "meeting_key": 1219,
                "name_acronym": "VER",
                "session_key": 9158,
                "team_colour": "3671C6",
                "team_name": "Red Bull Racing"
            }
        ]
        """.data(using: .utf8)!

        let drivers = try JSONDecoder().decode([OpenF1Driver].self, from: json)
        XCTAssertEqual(drivers.count, 1)
        let d = drivers[0]
        XCTAssertEqual(d.driverNumber, 1)
        XCTAssertEqual(d.broadcastName, "M VERSTAPPEN")
        XCTAssertEqual(d.fullName, "Max VERSTAPPEN")
        XCTAssertEqual(d.nameAcronym, "VER")
        XCTAssertEqual(d.teamName, "Red Bull Racing")
        XCTAssertEqual(d.teamColour, "3671C6")
        XCTAssertEqual(d.sessionKey, 9158)
        XCTAssertEqual(d.meetingKey, 1219)
        XCTAssertEqual(d.tla, "VER")
        XCTAssertEqual(d.displayName, "Max VERSTAPPEN")
        XCTAssertEqual(d.id, 1)
    }

    func testDriversEndpointMinimalFields() throws {
        let json = """
        {"driver_number": 81}
        """.data(using: .utf8)!

        let d = try JSONDecoder().decode(OpenF1Driver.self, from: json)
        XCTAssertEqual(d.driverNumber, 81)
        XCTAssertNil(d.broadcastName)
        XCTAssertNil(d.fullName)
        XCTAssertNil(d.nameAcronym)
        XCTAssertNil(d.teamName)
        XCTAssertNil(d.teamColour)
        XCTAssertNil(d.countryCode)
        XCTAssertEqual(d.tla, "81")
        XCTAssertEqual(d.displayName, "Driver 81")
    }

    func testDriversEndpointExtraFieldsIgnored() throws {
        // first_name, last_name, headshot_url are in API but not in model — should be ignored
        let json = """
        {
            "driver_number": 44,
            "name_acronym": "HAM",
            "first_name": "Lewis",
            "last_name": "Hamilton",
            "headshot_url": "https://example.com/ham.png"
        }
        """.data(using: .utf8)!

        let d = try JSONDecoder().decode(OpenF1Driver.self, from: json)
        XCTAssertEqual(d.driverNumber, 44)
        XCTAssertEqual(d.tla, "HAM")
    }

    // MARK: - /v1/position

    func testPositionEndpointFullResponse() throws {
        let json = """
        [
            {
                "date": "2023-08-26T09:30:47.199000+00:00",
                "driver_number": 40,
                "meeting_key": 1217,
                "position": 2,
                "session_key": 9144
            }
        ]
        """.data(using: .utf8)!

        let positions = try JSONDecoder().decode([HistoricalPosition].self, from: json)
        XCTAssertEqual(positions.count, 1)
        let p = positions[0]
        XCTAssertEqual(p.driverNumber, 40)
        XCTAssertEqual(p.position, 2)
        XCTAssertEqual(p.date, "2023-08-26T09:30:47.199000+00:00")
    }

    func testPositionEndpointExtraFieldsIgnored() throws {
        let json = """
        {"date": "2024-01-01T00:00:00Z", "driver_number": 1, "position": 1, "meeting_key": 999, "session_key": 999}
        """.data(using: .utf8)!

        let p = try JSONDecoder().decode(HistoricalPosition.self, from: json)
        XCTAssertEqual(p.driverNumber, 1)
        XCTAssertEqual(p.position, 1)
    }

    // MARK: - /v1/laps

    func testLapsEndpointFullResponse() throws {
        let json = """
        [
            {
                "date_start": "2023-09-16T13:59:07.606000+00:00",
                "driver_number": 63,
                "duration_sector_1": 26.966,
                "duration_sector_2": 38.657,
                "duration_sector_3": 26.12,
                "i1_speed": 307,
                "i2_speed": 277,
                "is_pit_out_lap": false,
                "lap_duration": 91.743,
                "lap_number": 8,
                "meeting_key": 1219,
                "segments_sector_1": [2049, 2049, 2049, 2051, 2049, 2051, 2049, 2049],
                "segments_sector_2": [2049, 2049, 2049, 2049, 2049, 2049, 2049, 2049],
                "segments_sector_3": [2048, 2048, 2048, 2048, 2048, 2064, 2064, 2064],
                "session_key": 9161,
                "st_speed": 298
            }
        ]
        """.data(using: .utf8)!

        let laps = try JSONDecoder().decode([HistoricalLap].self, from: json)
        XCTAssertEqual(laps.count, 1)
        let l = laps[0]
        XCTAssertEqual(l.driverNumber, 63)
        XCTAssertEqual(l.lapNumber, 8)
        XCTAssertEqual(l.lapDuration, 91.743)
        XCTAssertEqual(l.durationSector1, 26.966)
        XCTAssertEqual(l.durationSector2, 38.657)
        XCTAssertEqual(l.durationSector3, 26.12)
        XCTAssertEqual(l.isPitOutLap, false)
        XCTAssertEqual(l.dateStart, "2023-09-16T13:59:07.606000+00:00")
    }

    func testLapsEndpointNullOptionals() throws {
        let json = """
        {
            "driver_number": 1,
            "lap_number": 1,
            "lap_duration": null,
            "duration_sector_1": null,
            "duration_sector_2": null,
            "duration_sector_3": null,
            "is_pit_out_lap": true,
            "date_start": null
        }
        """.data(using: .utf8)!

        let l = try JSONDecoder().decode(HistoricalLap.self, from: json)
        XCTAssertEqual(l.driverNumber, 1)
        XCTAssertNil(l.lapDuration)
        XCTAssertNil(l.durationSector1)
        XCTAssertNil(l.dateStart)
        XCTAssertEqual(l.isPitOutLap, true)
    }

    func testLapsEndpointExtraFieldsIgnored() throws {
        // i1_speed, i2_speed, st_speed, segments not in model — should be ignored
        let json = """
        {
            "driver_number": 44,
            "lap_number": 3,
            "i1_speed": 310,
            "i2_speed": 280,
            "st_speed": 300,
            "segments_sector_1": [2048, 2049]
        }
        """.data(using: .utf8)!

        let l = try JSONDecoder().decode(HistoricalLap.self, from: json)
        XCTAssertEqual(l.driverNumber, 44)
        XCTAssertEqual(l.lapNumber, 3)
    }

    // MARK: - /v1/intervals

    func testIntervalsEndpointFullResponse() throws {
        let json = """
        [
            {
                "date": "2023-09-17T13:31:02.395000+00:00",
                "driver_number": 1,
                "gap_to_leader": 0.0,
                "interval": 0.0,
                "meeting_key": 1219,
                "session_key": 9165
            }
        ]
        """.data(using: .utf8)!

        let intervals = try JSONDecoder().decode([HistoricalInterval].self, from: json)
        XCTAssertEqual(intervals.count, 1)
        let i = intervals[0]
        XCTAssertEqual(i.driverNumber, 1)
        XCTAssertEqual(i.gapToLeader, 0.0)
        XCTAssertEqual(i.interval, 0.0)
    }

    func testIntervalsEndpointNullValues() throws {
        let json = """
        {"driver_number": 44, "date": "2024-01-01T00:00:00Z", "gap_to_leader": null, "interval": null}
        """.data(using: .utf8)!

        let i = try JSONDecoder().decode(HistoricalInterval.self, from: json)
        XCTAssertNil(i.gapToLeader)
        XCTAssertNil(i.interval)
    }

    func testIntervalsEndpointLargeValues() throws {
        let json = """
        {"driver_number": 20, "date": "2024-01-01T00:00:00Z", "gap_to_leader": 85.432, "interval": 12.876}
        """.data(using: .utf8)!

        let i = try JSONDecoder().decode(HistoricalInterval.self, from: json)
        XCTAssertEqual(i.gapToLeader!, 85.432, accuracy: 0.001)
        XCTAssertEqual(i.interval!, 12.876, accuracy: 0.001)
    }

    func testIntervalsEndpointStringGapToLeader() throws {
        // Real API returns "+1 LAP" as string for lapped drivers
        let json = """
        {"driver_number": 18, "date": "2024-03-02T16:30:00Z", "gap_to_leader": "+1 LAP", "interval": "+1 LAP"}
        """.data(using: .utf8)!

        let i = try JSONDecoder().decode(HistoricalInterval.self, from: json)
        XCTAssertEqual(i.driverNumber, 18)
        XCTAssertNil(i.gapToLeader)
        XCTAssertEqual(i.gapToLeaderText, "+1 LAP")
        XCTAssertNil(i.interval)
        XCTAssertEqual(i.intervalText, "+1 LAP")
    }

    func testIntervalsEndpointMixedTypes() throws {
        // gap_to_leader is string but interval is double
        let json = """
        {"driver_number": 22, "date": "2024-03-02T16:30:00Z", "gap_to_leader": "+2 LAP", "interval": 3.456}
        """.data(using: .utf8)!

        let i = try JSONDecoder().decode(HistoricalInterval.self, from: json)
        XCTAssertNil(i.gapToLeader)
        XCTAssertEqual(i.gapToLeaderText, "+2 LAP")
        XCTAssertEqual(i.interval!, 3.456, accuracy: 0.001)
        XCTAssertNil(i.intervalText)
    }

    // MARK: - /v1/race_control

    func testRaceControlEndpointFullResponse() throws {
        let json = """
        [
            {
                "category": "Flag",
                "date": "2023-06-04T14:21:01+00:00",
                "driver_number": 1,
                "flag": "BLACK AND WHITE",
                "lap_number": 59,
                "meeting_key": 1211,
                "message": "BLACK AND WHITE FLAG FOR CAR 1 (VER) - TRACK LIMITS",
                "scope": "Driver",
                "sector": null,
                "session_key": 9102
            }
        ]
        """.data(using: .utf8)!

        let messages = try JSONDecoder().decode([HistoricalRaceControl].self, from: json)
        XCTAssertEqual(messages.count, 1)
        let m = messages[0]
        XCTAssertEqual(m.category, "Flag")
        XCTAssertEqual(m.flag, "BLACK AND WHITE")
        XCTAssertEqual(m.driverNumber, 1)
        XCTAssertEqual(m.lapNumber, 59)
        XCTAssertEqual(m.message, "BLACK AND WHITE FLAG FOR CAR 1 (VER) - TRACK LIMITS")
        XCTAssertEqual(m.scope, "Driver")
        XCTAssertNil(m.sector)
    }

    func testRaceControlEndpointSafetyCarMessage() throws {
        let json = """
        {
            "category": "SafetyCar",
            "date": "2024-01-01T00:00:00Z",
            "driver_number": null,
            "flag": "YELLOW",
            "lap_number": 20,
            "message": "SAFETY CAR DEPLOYED",
            "scope": "Track",
            "sector": null
        }
        """.data(using: .utf8)!

        let m = try JSONDecoder().decode(HistoricalRaceControl.self, from: json)
        XCTAssertEqual(m.category, "SafetyCar")
        XCTAssertNil(m.driverNumber)
        XCTAssertEqual(m.scope, "Track")
    }

    func testRaceControlEndpointExtraFieldsIgnored() throws {
        let json = """
        {
            "date": "2024-01-01T00:00:00Z",
            "message": "TEST",
            "qualifying_phase": "Q3",
            "session_key": 999
        }
        """.data(using: .utf8)!

        let m = try JSONDecoder().decode(HistoricalRaceControl.self, from: json)
        XCTAssertEqual(m.message, "TEST")
    }

    // MARK: - /v1/car_data

    func testCarDataEndpointFullResponse() throws {
        let json = """
        [
            {
                "brake": 0,
                "date": "2023-09-15T13:08:19.923000+00:00",
                "driver_number": 55,
                "drs": 12,
                "meeting_key": 1219,
                "n_gear": 8,
                "rpm": 11141,
                "session_key": 9159,
                "speed": 315,
                "throttle": 99
            }
        ]
        """.data(using: .utf8)!

        let carData = try JSONDecoder().decode([HistoricalCarData].self, from: json)
        XCTAssertEqual(carData.count, 1)
        let c = carData[0]
        XCTAssertEqual(c.driverNumber, 55)
        XCTAssertEqual(c.speed, 315)
        XCTAssertEqual(c.rpm, 11141)
        XCTAssertEqual(c.gear, 8)
        XCTAssertEqual(c.throttle, 99)
        XCTAssertEqual(c.drs, 12)
        XCTAssertEqual(c.brake, 0)
        XCTAssertEqual(c.date, "2023-09-15T13:08:19.923000+00:00")
    }

    func testCarDataEndpointBraking() throws {
        let json = """
        {
            "brake": 100,
            "date": "2024-01-01T00:00:00Z",
            "driver_number": 1,
            "drs": 0,
            "n_gear": 3,
            "rpm": 9000,
            "speed": 120,
            "throttle": 0
        }
        """.data(using: .utf8)!

        let c = try JSONDecoder().decode(HistoricalCarData.self, from: json)
        XCTAssertEqual(c.brake, 100)
        XCTAssertEqual(c.throttle, 0)
        XCTAssertEqual(c.gear, 3)
        XCTAssertEqual(c.rpm, 9000)
    }

    func testCarDataEndpointNullOptionals() throws {
        let json = """
        {"driver_number": 44, "date": "2024-01-01T00:00:00Z"}
        """.data(using: .utf8)!

        let c = try JSONDecoder().decode(HistoricalCarData.self, from: json)
        XCTAssertEqual(c.driverNumber, 44)
        XCTAssertNil(c.speed)
        XCTAssertNil(c.rpm)
        XCTAssertNil(c.gear)
        XCTAssertNil(c.throttle)
        XCTAssertNil(c.drs)
        XCTAssertNil(c.brake)
    }

    func testCarDataRpmAndGearAreCorrectlyMapped() throws {
        // Critical test: verify rpm maps to "rpm" and gear maps to "n_gear"
        let json = """
        {"driver_number": 1, "date": "2024-01-01T00:00:00Z", "rpm": 12500, "n_gear": 7}
        """.data(using: .utf8)!

        let c = try JSONDecoder().decode(HistoricalCarData.self, from: json)
        XCTAssertEqual(c.rpm, 12500, "rpm should decode from 'rpm' key, not 'n_gear'")
        XCTAssertEqual(c.gear, 7, "gear should decode from 'n_gear' key")
    }

    // MARK: - /v1/team_radio

    func testTeamRadioEndpointFullResponse() throws {
        let json = """
        [
            {
                "date": "2023-09-15T09:40:43.005000+00:00",
                "driver_number": 11,
                "meeting_key": 1219,
                "recording_url": "https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/SERPER01_11_20230915_104008.mp3",
                "session_key": 9158
            }
        ]
        """.data(using: .utf8)!

        let radios = try JSONDecoder().decode([HistoricalTeamRadio].self, from: json)
        XCTAssertEqual(radios.count, 1)
        let r = radios[0]
        XCTAssertEqual(r.driverNumber, 11)
        XCTAssertTrue(r.recordingUrl?.contains("TeamRadio") ?? false)
    }

    func testTeamRadioEndpointNullUrl() throws {
        let json = """
        {"driver_number": 1, "date": "2024-01-01T00:00:00Z", "recording_url": null}
        """.data(using: .utf8)!

        let r = try JSONDecoder().decode(HistoricalTeamRadio.self, from: json)
        XCTAssertNil(r.recordingUrl)
    }

    // MARK: - /v1/weather

    func testWeatherEndpointFullResponse() throws {
        let json = """
        [
            {
                "air_temperature": 27.8,
                "date": "2023-05-07T18:42:25.233000+00:00",
                "humidity": 58,
                "meeting_key": 1208,
                "pressure": 1018.7,
                "rainfall": 0,
                "session_key": 9078,
                "track_temperature": 52.5,
                "wind_direction": 136,
                "wind_speed": 2.4
            }
        ]
        """.data(using: .utf8)!

        let weather = try JSONDecoder().decode([HistoricalWeather].self, from: json)
        XCTAssertEqual(weather.count, 1)
        let w = weather[0]
        XCTAssertEqual(w.airTemperature, 27.8)
        XCTAssertEqual(w.trackTemperature, 52.5)
        XCTAssertEqual(w.humidity, 58)
        XCTAssertEqual(w.pressure!, 1018.7, accuracy: 0.1)
        XCTAssertEqual(w.rainfall, 0)
        XCTAssertEqual(w.windDirection, 136)
        XCTAssertEqual(w.windSpeed!, 2.4, accuracy: 0.1)
    }

    func testWeatherEndpointHumidityAsInt() throws {
        // API returns humidity as int (58), model expects Double? — should decode fine
        let json = """
        {"date": "2024-01-01T00:00:00Z", "humidity": 58}
        """.data(using: .utf8)!

        let w = try JSONDecoder().decode(HistoricalWeather.self, from: json)
        XCTAssertEqual(w.humidity, 58.0)
    }

    func testWeatherEndpointRainyConditions() throws {
        let json = """
        {"date": "2024-01-01T00:00:00Z", "rainfall": 1, "humidity": 95, "air_temperature": 18.2, "track_temperature": 22.1}
        """.data(using: .utf8)!

        let w = try JSONDecoder().decode(HistoricalWeather.self, from: json)
        XCTAssertEqual(w.rainfall, 1)
        XCTAssertEqual(w.humidity, 95)
    }

    func testWeatherEndpointNullOptionals() throws {
        let json = """
        {"date": "2024-01-01T00:00:00Z"}
        """.data(using: .utf8)!

        let w = try JSONDecoder().decode(HistoricalWeather.self, from: json)
        XCTAssertNil(w.airTemperature)
        XCTAssertNil(w.trackTemperature)
        XCTAssertNil(w.humidity)
        XCTAssertNil(w.pressure)
        XCTAssertNil(w.windSpeed)
        XCTAssertNil(w.windDirection)
        XCTAssertNil(w.rainfall)
    }

    // MARK: - /v1/location

    func testLocationEndpointFullResponse() throws {
        let json = """
        [
            {
                "date": "2023-09-16T13:03:35.292000+00:00",
                "driver_number": 81,
                "meeting_key": 1219,
                "session_key": 9161,
                "x": 567,
                "y": 3195,
                "z": 187
            }
        ]
        """.data(using: .utf8)!

        let locations = try JSONDecoder().decode([HistoricalLocation].self, from: json)
        XCTAssertEqual(locations.count, 1)
        let loc = locations[0]
        XCTAssertEqual(loc.driverNumber, 81)
        XCTAssertEqual(loc.x, 567)
        XCTAssertEqual(loc.y, 3195)
        XCTAssertEqual(loc.z, 187)
    }

    func testLocationEndpointIntCoordinatesDecodeAsDouble() throws {
        // API returns x/y/z as int, model uses Double — verify int→Double works
        let json = """
        {"driver_number": 1, "date": "2024-01-01T00:00:00Z", "x": 1000, "y": 2000, "z": 50}
        """.data(using: .utf8)!

        let loc = try JSONDecoder().decode(HistoricalLocation.self, from: json)
        XCTAssertEqual(loc.x, 1000.0)
        XCTAssertEqual(loc.y, 2000.0)
        XCTAssertEqual(loc.z, 50.0)
    }

    func testLocationEndpointNegativeCoordinates() throws {
        let json = """
        {"driver_number": 44, "date": "2024-01-01T00:00:00Z", "x": -500, "y": -1200, "z": 0}
        """.data(using: .utf8)!

        let loc = try JSONDecoder().decode(HistoricalLocation.self, from: json)
        XCTAssertEqual(loc.x, -500)
        XCTAssertEqual(loc.y, -1200)
    }

    // MARK: - /v1/stints

    func testStintsEndpointFullResponse() throws {
        let json = """
        [
            {
                "compound": "SOFT",
                "driver_number": 16,
                "lap_end": 20,
                "lap_start": 1,
                "meeting_key": 1219,
                "session_key": 9165,
                "stint_number": 1,
                "tyre_age_at_start": 3
            }
        ]
        """.data(using: .utf8)!

        let stints = try JSONDecoder().decode([StintData].self, from: json)
        XCTAssertEqual(stints.count, 1)
        let s = stints[0]
        XCTAssertEqual(s.driverNumber, 16)
        XCTAssertEqual(s.stintNumber, 1)
        XCTAssertEqual(s.compound, .soft)
        XCTAssertEqual(s.lapStart, 1)
        XCTAssertEqual(s.lapEnd, 20)
        XCTAssertEqual(s.tyreAgeAtStart, 3)
        XCTAssertEqual(s.id, "16-1")
    }

    func testStintsEndpointAllCompounds() throws {
        let compounds = ["SOFT", "MEDIUM", "HARD", "INTERMEDIATE", "WET"]
        let expected: [TireCompound] = [.soft, .medium, .hard, .intermediate, .wet]

        for (i, compound) in compounds.enumerated() {
            let json = """
            {"driver_number": 1, "stint_number": \(i + 1), "compound": "\(compound)"}
            """.data(using: .utf8)!

            let s = try JSONDecoder().decode(StintData.self, from: json)
            XCTAssertEqual(s.compound, expected[i], "Compound \(compound) should decode to \(expected[i])")
        }
    }

    func testStintsEndpointUnknownCompound() throws {
        let json = """
        {"driver_number": 1, "stint_number": 1, "compound": "HYPERSOFT"}
        """.data(using: .utf8)!

        let s = try JSONDecoder().decode(StintData.self, from: json)
        XCTAssertEqual(s.compound, .unknown, "Unknown compound should fall back to .unknown")
    }

    func testStintsEndpointCurrentAge() throws {
        let json = """
        {"driver_number": 1, "stint_number": 1, "compound": "MEDIUM", "tyre_age_at_start": 3, "lap_start": 10}
        """.data(using: .utf8)!

        let s = try JSONDecoder().decode(StintData.self, from: json)
        XCTAssertEqual(s.currentAge(currentLap: 15), 8) // 3 + (15 - 10) = 8
        XCTAssertEqual(s.currentAge(currentLap: 10), 3) // 3 + (10 - 10) = 3
    }

    func testStintsEndpointNullOptionals() throws {
        let json = """
        {"driver_number": 44, "stint_number": 2, "compound": "HARD"}
        """.data(using: .utf8)!

        let s = try JSONDecoder().decode(StintData.self, from: json)
        XCTAssertNil(s.lapStart)
        XCTAssertNil(s.lapEnd)
        XCTAssertNil(s.tyreAgeAtStart)
    }

    // MARK: - /v1/pit

    func testPitEndpointFullResponse() throws {
        let json = """
        [
            {
                "date": "2023-09-17T13:38:41.738000+00:00",
                "driver_number": 16,
                "lap_number": 31,
                "meeting_key": 1219,
                "pit_duration": 22.215,
                "session_key": 9165
            }
        ]
        """.data(using: .utf8)!

        let pitStops = try JSONDecoder().decode([PitStopData].self, from: json)
        XCTAssertEqual(pitStops.count, 1)
        let p = pitStops[0]
        XCTAssertEqual(p.driverNumber, 16)
        XCTAssertEqual(p.lapNumber, 31)
        XCTAssertEqual(p.pitDuration!, 22.215, accuracy: 0.001)
        XCTAssertEqual(p.date, "2023-09-17T13:38:41.738000+00:00")
        XCTAssertEqual(p.id, "16-31")
    }

    func testPitEndpointNullDuration() throws {
        let json = """
        {"driver_number": 1, "lap_number": 15, "pit_duration": null}
        """.data(using: .utf8)!

        let p = try JSONDecoder().decode(PitStopData.self, from: json)
        XCTAssertEqual(p.lapNumber, 15)
        XCTAssertNil(p.pitDuration)
    }

    func testPitEndpointExtraFieldsIgnored() throws {
        // API has lane_duration and stop_duration — should be ignored
        let json = """
        {
            "driver_number": 44,
            "lap_number": 20,
            "pit_duration": 25.5,
            "lane_duration": 25.5,
            "stop_duration": 2.3,
            "date": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let p = try JSONDecoder().decode(PitStopData.self, from: json)
        XCTAssertEqual(p.driverNumber, 44)
        XCTAssertEqual(p.lapNumber, 20)
    }

    // MARK: - TireCompound

    func testTireCompoundAbbreviations() {
        XCTAssertEqual(TireCompound.soft.abbreviation, "S")
        XCTAssertEqual(TireCompound.medium.abbreviation, "M")
        XCTAssertEqual(TireCompound.hard.abbreviation, "H")
        XCTAssertEqual(TireCompound.intermediate.abbreviation, "I")
        XCTAssertEqual(TireCompound.wet.abbreviation, "W")
        XCTAssertEqual(TireCompound.unknown.abbreviation, "?")
    }

    func testTireCompoundRawValues() {
        XCTAssertEqual(TireCompound.soft.rawValue, "SOFT")
        XCTAssertEqual(TireCompound.medium.rawValue, "MEDIUM")
        XCTAssertEqual(TireCompound.hard.rawValue, "HARD")
        XCTAssertEqual(TireCompound.intermediate.rawValue, "INTERMEDIATE")
        XCTAssertEqual(TireCompound.wet.rawValue, "WET")
        XCTAssertEqual(TireCompound.unknown.rawValue, "UNKNOWN")
    }

    func testTireCompoundDecodesFromJSON() throws {
        let json = "\"MEDIUM\"".data(using: .utf8)!
        let compound = try JSONDecoder().decode(TireCompound.self, from: json)
        XCTAssertEqual(compound, .medium)
    }

    func testTireCompoundUnknownValueFallback() throws {
        let json = "\"SUPERSOFT\"".data(using: .utf8)!
        let compound = try JSONDecoder().decode(TireCompound.self, from: json)
        XCTAssertEqual(compound, .unknown)
    }

    func testTireCompoundAllCases() {
        XCTAssertEqual(TireCompound.allCases.count, 6)
    }

    // MARK: - Array Decoding (simulates full API response)

    func testDecodeLargePositionArray() throws {
        var positions: [[String: Any]] = []
        for i in 1...20 {
            positions.append([
                "driver_number": i,
                "date": "2024-01-01T00:00:0\(i % 10).000Z",
                "position": i
            ])
        }
        let data = try JSONSerialization.data(withJSONObject: positions)
        let decoded = try JSONDecoder().decode([HistoricalPosition].self, from: data)
        XCTAssertEqual(decoded.count, 20)
        XCTAssertEqual(decoded.first?.position, 1)
        XCTAssertEqual(decoded.last?.position, 20)
    }

    func testDecodeEmptyArrayForAllTypes() throws {
        let empty = "[]".data(using: .utf8)!

        XCTAssertTrue(try JSONDecoder().decode([OpenF1Session].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([OpenF1Driver].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([HistoricalPosition].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([HistoricalLap].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([HistoricalInterval].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([HistoricalRaceControl].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([HistoricalCarData].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([HistoricalTeamRadio].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([HistoricalWeather].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([HistoricalLocation].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([StintData].self, from: empty).isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([PitStopData].self, from: empty).isEmpty)
    }

    // MARK: - Date Format Variations

    func testDateFormatsAcrossEndpoints() {
        // Different endpoints use different date formats
        let formats = [
            "2023-09-16T13:03:35.292000+00:00",  // location, car_data (with microseconds + offset)
            "2023-06-04T14:21:01+00:00",          // race_control (no fractional seconds)
            "2023-05-07T18:42:25.233000+00:00",   // weather (milliseconds + offset)
            "2024-03-02T15:30:00.000Z",           // standard ISO8601 with Z
            "2024-03-02T15:30:00Z",               // without fractional
        ]

        for format in formats {
            let date = parseOpenF1Date(format)
            XCTAssertNotNil(date, "Failed to parse date format: \(format)")
        }
    }
}
