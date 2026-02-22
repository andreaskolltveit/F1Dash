import XCTest
@testable import F1Dash

final class ModelParsingTests: XCTestCase {

    // MARK: - Driver Parsing

    func testDriverFromDict() {
        let dict: [String: Any] = [
            "RacingNumber": "1",
            "Tla": "VER",
            "FirstName": "Max",
            "LastName": "Verstappen",
            "FullName": "Max Verstappen",
            "TeamName": "Red Bull Racing",
            "TeamColour": "3671C6",
            "Line": 1,
            "CountryCode": "NED"
        ]
        let driver = Driver.from(key: "1", dict: dict)

        XCTAssertEqual(driver.id, "1")
        XCTAssertEqual(driver.tla, "VER")
        XCTAssertEqual(driver.firstName, "Max")
        XCTAssertEqual(driver.lastName, "Verstappen")
        XCTAssertEqual(driver.teamName, "Red Bull Racing")
        XCTAssertEqual(driver.teamColour, "3671C6")
        XCTAssertEqual(driver.line, 1)
    }

    func testDriverFromEmptyDict() {
        let driver = Driver.from(key: "99", dict: [:])
        XCTAssertEqual(driver.id, "99")
        XCTAssertEqual(driver.tla, "???")
        XCTAssertEqual(driver.racingNumber, "99")
    }

    func testDriverFromDictWithNewFields() {
        let dict: [String: Any] = [
            "RacingNumber": "1", "Tla": "VER",
            "FirstName": "Max", "LastName": "Verstappen", "FullName": "Max Verstappen",
            "TeamName": "Red Bull Racing", "TeamColour": "3671C6",
            "Line": 1, "CountryCode": "NED",
            "BroadcastName": "M VERSTAPPEN",
            "HeadshotUrl": "https://example.com/ver.png",
            "Reference": "MAXVER01"
        ]
        let driver = Driver.from(key: "1", dict: dict)

        XCTAssertEqual(driver.broadcastName, "M VERSTAPPEN")
        XCTAssertEqual(driver.headshotUrl, "https://example.com/ver.png")
        XCTAssertEqual(driver.reference, "MAXVER01")
    }

    func testDriverFromDictNewFieldsDefaults() {
        // Without new fields — should get defaults
        let driver = Driver.from(key: "1", dict: [:])
        XCTAssertEqual(driver.broadcastName, "")
        XCTAssertNil(driver.headshotUrl)
        XCTAssertNil(driver.reference)
    }

    // MARK: - Race Control Message Parsing

    func testRaceControlMessageFromDict() {
        let dict: [String: Any] = [
            "Utc": "2026-03-02T15:30:00.000Z",
            "Category": "Flag",
            "Message": "YELLOW FLAG IN SECTOR 2",
            "Flag": "YELLOW",
            "Scope": "Sector",
            "Sector": 2,
            "Lap": 15,
            "RacingNumber": "44"
        ]
        let msg = RaceControlMessage.from(dict: dict)

        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.category, .flag)
        XCTAssertEqual(msg?.flag, .yellow)
        XCTAssertEqual(msg?.scope, .sector)
        XCTAssertEqual(msg?.sector, 2)
        XCTAssertEqual(msg?.lap, 15)
        XCTAssertEqual(msg?.racingNumber, "44")
        XCTAssertTrue(msg?.message.contains("YELLOW") ?? false)
    }

    func testRaceControlMessageBlueFlag() {
        let dict: [String: Any] = [
            "Utc": "2026-03-02T15:30:00.000Z",
            "Category": "Flag",
            "Message": "BLUE FLAG - CAR 18",
            "Flag": "BLUE",
            "Scope": "Driver",
            "RacingNumber": "18"
        ]
        let msg = RaceControlMessage.from(dict: dict)
        XCTAssertTrue(msg?.isBlueFlag ?? false)
    }

    func testRaceControlMessageMissingUtcReturnsNil() {
        let dict: [String: Any] = [
            "Message": "Some message"
        ]
        XCTAssertNil(RaceControlMessage.from(dict: dict))
    }

    // MARK: - Team Radio Parsing

    func testRadioCaptureFromDict() {
        let dict: [String: Any] = [
            "Utc": "2026-03-02T15:45:00.000Z",
            "RacingNumber": "1",
            "Path": "TeamRadio/driver1_lap30.m4a"
        ]
        let capture = RadioCapture.from(dict: dict)

        XCTAssertNotNil(capture)
        XCTAssertEqual(capture?.racingNumber, "1")
        XCTAssertEqual(capture?.path, "TeamRadio/driver1_lap30.m4a")
    }

    func testRadioCaptureAudioURL() {
        let capture = RadioCapture(
            utc: Date(),
            racingNumber: "1",
            path: "TeamRadio/driver1.m4a"
        )
        let url = capture.audioURL(sessionPath: "2026/2026-03-02_Bahrain/Race/")
        XCTAssertEqual(
            url?.absoluteString,
            "https://livetiming.formula1.com/static/2026/2026-03-02_Bahrain/Race/TeamRadio/driver1.m4a"
        )
    }

    // MARK: - Session Info Parsing

    func testSessionInfoFromDict() {
        let dict: [String: Any] = [
            "Meeting": [
                "Name": "Bahrain GP",
                "OfficialName": "FORMULA 1 BAHRAIN GP",
                "Country": ["Name": "Bahrain"],
                "Circuit": ["ShortName": "Sakhir", "Key": 63]
            ],
            "Name": "Race",
            "Type": "Race",
            "Path": "2026/Race/",
            "GmtOffset": "03:00:00"
        ]
        let info = SessionInfo.from(dict: dict)

        XCTAssertNotNil(info)
        XCTAssertEqual(info?.meetingName, "Bahrain GP")
        XCTAssertEqual(info?.meetingCircuitShortName, "Sakhir")
        XCTAssertEqual(info?.meetingCircuitKey, 63)
        XCTAssertEqual(info?.sessionName, "Race")
        XCTAssertEqual(info?.gmtOffset, "03:00:00")
    }

    // MARK: - Track Status Parsing

    func testTrackStatusCodes() {
        XCTAssertEqual(TrackStatus.TrackStatusCode(from: "1"), .allClear)
        XCTAssertEqual(TrackStatus.TrackStatusCode(from: "2"), .yellowFlag)
        XCTAssertEqual(TrackStatus.TrackStatusCode(from: "4"), .safetyCar)
        XCTAssertEqual(TrackStatus.TrackStatusCode(from: "5"), .redFlag)
        XCTAssertEqual(TrackStatus.TrackStatusCode(from: "6"), .vscDeployed)
        XCTAssertEqual(TrackStatus.TrackStatusCode(from: "7"), .vscEnding)
        XCTAssertEqual(TrackStatus.TrackStatusCode(from: nil), .allClear)
        XCTAssertEqual(TrackStatus.TrackStatusCode(from: "999"), .allClear)
    }

    func testTrackStatusHazard() {
        XCTAssertFalse(TrackStatus.TrackStatusCode.allClear.isHazard)
        XCTAssertTrue(TrackStatus.TrackStatusCode.yellowFlag.isHazard)
        XCTAssertTrue(TrackStatus.TrackStatusCode.safetyCar.isHazard)
        XCTAssertTrue(TrackStatus.TrackStatusCode.redFlag.isHazard)
        XCTAssertTrue(TrackStatus.TrackStatusCode.vscDeployed.isHazard)
    }

    // MARK: - Weather Parsing

    func testWeatherDataFromDict() {
        let dict: [String: Any] = [
            "AirTemp": "28.5",
            "TrackTemp": "42.3",
            "Humidity": "45",
            "Rainfall": "0"
        ]
        let weather = WeatherData.from(dict: dict)
        XCTAssertEqual(weather.airTemp, 28.5)
        XCTAssertEqual(weather.trackTemp, 42.3)
        XCTAssertEqual(weather.humidity, 45.0)
        XCTAssertFalse(weather.rainfall)
    }

    func testWeatherDataRainfall() {
        let dict: [String: Any] = ["Rainfall": "1"]
        let weather = WeatherData.from(dict: dict)
        XCTAssertTrue(weather.rainfall)
    }

    // MARK: - Segment Status

    func testSegmentStatusCodes() {
        XCTAssertEqual(SegmentStatus(from: 0), .none)
        XCTAssertEqual(SegmentStatus(from: 2048), .amber)
        XCTAssertEqual(SegmentStatus(from: 2049), .green)
        XCTAssertEqual(SegmentStatus(from: 2051), .purple)
        XCTAssertEqual(SegmentStatus(from: 2052), .amberCompleted)
        XCTAssertEqual(SegmentStatus(from: 2064), .blue)
        XCTAssertEqual(SegmentStatus(from: 9999), .none) // Unknown
    }

    func testSegmentStatusActive() {
        XCTAssertFalse(SegmentStatus.none.isActive)
        XCTAssertTrue(SegmentStatus.amber.isActive)
        XCTAssertTrue(SegmentStatus.green.isActive)
        XCTAssertTrue(SegmentStatus.purple.isActive)
    }

    // MARK: - Car Telemetry Parsing

    func testCarTelemetryParseEntriesObjectFormat() {
        // Object-format channels (web app definition): "0"=RPM, "2"=Speed, "3"=Gear, "4"=Throttle, "5"=Brake, "45"=DRS
        let json: [String: Any] = [
            "Entries": [
                [
                    "Utc": "2026-03-02T15:00:00Z",
                    "Cars": [
                        "1": ["Channels": ["0": 10500, "2": 315, "3": 8, "4": 100, "5": 50, "45": 10]],
                        "44": ["Channels": ["0": 11000, "2": 300, "3": 7, "4": 95, "5": 0, "45": 0]]
                    ]
                ]
            ]
        ]
        let result = CarTelemetry.parseEntries(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["1"]?.rpm, 10500)
        XCTAssertEqual(result?["1"]?.speed, 315)
        XCTAssertEqual(result?["1"]?.gear, 8)
        XCTAssertEqual(result?["1"]?.throttle, 100)
        XCTAssertEqual(result?["1"]?.brake, 50)
        XCTAssertTrue(result?["1"]?.drs.isOpen ?? false) // DRS 10 = active
        XCTAssertEqual(result?["44"]?.speed, 300)
        XCTAssertEqual(result?["44"]?.brake, 0)
        XCTAssertFalse(result?["44"]?.drs.isOpen ?? true)
    }

    func testCarTelemetryParseEntriesArrayFallback() {
        // Array-format fallback: [rpm, ?, speed, gear, throttle, brake, ...]
        let json: [String: Any] = [
            "Entries": [
                [
                    "Utc": "2026-03-02T15:00:00Z",
                    "Cars": [
                        "1": ["Channels": [10500, 0, 315, 8, 100, 80]]
                    ]
                ]
            ]
        ]
        let result = CarTelemetry.parseEntries(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["1"]?.rpm, 10500)
        XCTAssertEqual(result?["1"]?.speed, 315)
        XCTAssertEqual(result?["1"]?.gear, 8)
        XCTAssertEqual(result?["1"]?.throttle, 100)
        XCTAssertEqual(result?["1"]?.brake, 80)
        // DRS from ch[45] — array only has 6 elements, so DRS defaults to .off
        XCTAssertEqual(result?["1"]?.drs, .off)
    }

    // MARK: - Position Data Parsing

    func testPositionDataParseEntries() {
        let json: [String: Any] = [
            "Position": [
                [
                    "Timestamp": "2026-03-02T15:00:00Z",
                    "Entries": [
                        "1": ["X": 1234.5, "Y": 5678.9, "Z": 0.0, "Status": "OnTrack"],
                        "44": ["X": 2000, "Y": 3000, "Z": 0, "Status": "OffTrack"]
                    ]
                ]
            ]
        ]
        let result = DriverPosition.parseEntries(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["1"]?.x, 1234.5)
        XCTAssertEqual(result?["1"]?.y, 5678.9)
        XCTAssertTrue(result?["1"]?.isOnTrack ?? false)
        XCTAssertFalse(result?["44"]?.isOnTrack ?? true)
    }

    // MARK: - Extrapolated Clock

    func testExtrapolatedClockFromDict() {
        let dict: [String: Any] = [
            "Utc": "2026-03-02T15:30:00.000Z",
            "Remaining": "01:23:45",
            "Extrapolating": true
        ]
        let clock = ExtrapolatedClock.from(dict: dict)
        XCTAssertNotNil(clock)
        XCTAssertEqual(clock?.remaining, "01:23:45")
        XCTAssertTrue(clock?.extrapolating ?? false)
    }

    // MARK: - Lap Count

    func testLapCountFromDict() {
        let dict: [String: Any] = ["CurrentLap": 45, "TotalLaps": 57]
        let laps = LapCount.from(dict: dict)
        XCTAssertEqual(laps.currentLap, 45)
        XCTAssertEqual(laps.totalLaps, 57)
    }

    // MARK: - TimingData New Fields

    func testTimingDataIntervalCatching() {
        let dict: [String: Any] = [
            "Position": "2",
            "IntervalToPositionAhead": ["Value": "+0.456", "Catching": true] as [String: Any]
        ]
        let driver = TimingDataParser.parseDriver(dict: dict)

        XCTAssertEqual(driver.intervalToPositionAhead, "+0.456")
        XCTAssertTrue(driver.intervalCatching)
    }

    func testTimingDataIntervalCatchingFalseByDefault() {
        let dict: [String: Any] = [
            "Position": "1",
            "IntervalToPositionAhead": "+1.234"
        ]
        let driver = TimingDataParser.parseDriver(dict: dict)

        XCTAssertEqual(driver.intervalToPositionAhead, "+1.234")
        XCTAssertFalse(driver.intervalCatching)
    }

    func testTimingDataSpeedTraps() {
        let dict: [String: Any] = [
            "Position": "1",
            "Speeds": [
                "I1": ["Value": "305", "OverallFastest": true, "PersonalFastest": true] as [String: Any],
                "I2": ["Value": "280"] as [String: Any],
                "Fl": ["Value": "210", "PersonalFastest": true] as [String: Any],
                "St": ["Value": "320"] as [String: Any]
            ] as [String: Any]
        ]
        let driver = TimingDataParser.parseDriver(dict: dict)

        XCTAssertNotNil(driver.speeds)
        XCTAssertEqual(driver.speeds?.i1.value, "305")
        XCTAssertTrue(driver.speeds?.i1.overallFastest ?? false)
        XCTAssertTrue(driver.speeds?.i1.personalFastest ?? false)
        XCTAssertEqual(driver.speeds?.i2.value, "280")
        XCTAssertFalse(driver.speeds?.i2.overallFastest ?? true)
        XCTAssertEqual(driver.speeds?.fl.value, "210")
        XCTAssertTrue(driver.speeds?.fl.personalFastest ?? false)
        XCTAssertEqual(driver.speeds?.st.value, "320")
    }

    func testTimingDataSpeedsNilWhenMissing() {
        let dict: [String: Any] = ["Position": "5"]
        let driver = TimingDataParser.parseDriver(dict: dict)
        XCTAssertNil(driver.speeds)
    }

    func testTimingDataQualifyingFields() {
        let dict: [String: Any] = [
            "Position": "16",
            "KnockedOut": true,
            "Cutoff": true,
            "ShowPosition": false,
            "Status": 64,
            "Line": 16
        ]
        let driver = TimingDataParser.parseDriver(dict: dict)

        XCTAssertTrue(driver.knockedOut)
        XCTAssertTrue(driver.cutoff)
        XCTAssertFalse(driver.showPosition)
        XCTAssertEqual(driver.driverStatus, 64)
        XCTAssertEqual(driver.line, 16)
    }

    func testTimingDataQualifyingFieldsDefaults() {
        let dict: [String: Any] = ["Position": "1"]
        let driver = TimingDataParser.parseDriver(dict: dict)

        XCTAssertFalse(driver.knockedOut)
        XCTAssertFalse(driver.cutoff)
        XCTAssertTrue(driver.showPosition)
        XCTAssertNil(driver.driverStatus)
        XCTAssertNil(driver.line)
    }

    // MARK: - TimingAppData Parsing

    func testTimingAppDataParsing() {
        let dict: [String: Any] = [
            "Lines": [
                "1": [
                    "GridPos": "1",
                    "Line": 1,
                    "Stints": [
                        "0": ["TotalLaps": 20, "Compound": "SOFT", "New": "true"] as [String: Any],
                        "1": ["TotalLaps": 25, "Compound": "HARD", "New": "false"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any],
                "44": [
                    "GridPos": "5",
                    "Stints": [
                        "0": ["TotalLaps": 22, "Compound": "MEDIUM", "New": "true"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]

        let result = TimingDataParser.parseTimingAppData(dict: dict)

        XCTAssertEqual(result.count, 2)

        let driver1 = result["1"]
        XCTAssertNotNil(driver1)
        XCTAssertEqual(driver1?.gridPos, "1")
        XCTAssertEqual(driver1?.line, 1)
        XCTAssertEqual(driver1?.stints.count, 2)
        XCTAssertEqual(driver1?.stints[0].compound, "SOFT")
        XCTAssertEqual(driver1?.stints[0].totalLaps, 20)
        XCTAssertEqual(driver1?.stints[0].isNew, true)
        XCTAssertEqual(driver1?.stints[1].compound, "HARD")
        XCTAssertEqual(driver1?.stints[1].isNew, false)

        let driver44 = result["44"]
        XCTAssertEqual(driver44?.gridPos, "5")
        XCTAssertEqual(driver44?.stints.count, 1)
        XCTAssertEqual(driver44?.stints[0].compound, "MEDIUM")
    }

    func testTimingAppDataEmptyLines() {
        let dict: [String: Any] = [:]
        let result = TimingDataParser.parseTimingAppData(dict: dict)
        XCTAssertTrue(result.isEmpty)
    }
}
