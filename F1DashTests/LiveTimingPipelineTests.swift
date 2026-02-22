import XCTest
import Compression
@testable import F1Dash

/// Tests the full F1 Live Timing "scraping" pipeline:
/// Raw SignalR JSON → StateMerger → decodeTopic → typed models
///
/// These tests simulate real F1 SignalR messages and verify that
/// the entire data pipeline produces correct typed output.
final class LiveTimingPipelineTests: XCTestCase {

    var store: LiveTimingStore!

    @MainActor
    override func setUp() {
        super.setUp()
        store = LiveTimingStore()
    }

    // MARK: - Initial State Load

    @MainActor
    func testInitialStateLoadsAllTopics() {
        // Simulate initial state from SignalR subscribe response
        let initialState: [String: Any] = [
            "DriverList": [
                "1": [
                    "RacingNumber": "1", "Tla": "VER",
                    "FirstName": "Max", "LastName": "Verstappen",
                    "TeamName": "Red Bull Racing", "TeamColour": "3671C6",
                    "Line": 1, "CountryCode": "NED"
                ],
                "44": [
                    "RacingNumber": "44", "Tla": "HAM",
                    "FirstName": "Lewis", "LastName": "Hamilton",
                    "TeamName": "Ferrari", "TeamColour": "E8002D",
                    "Line": 2, "CountryCode": "GBR"
                ]
            ],
            "WeatherData": [
                "AirTemp": "28.5", "TrackTemp": "42.3",
                "Humidity": "45", "Rainfall": "0",
                "WindSpeed": "3.2", "WindDirection": "180", "Pressure": "1013.2"
            ],
            "TrackStatus": ["Status": "1", "Message": "AllClear"],
            "SessionStatus": ["Status": "Started"],
            "LapCount": ["CurrentLap": 1, "TotalLaps": 57],
            "ExtrapolatedClock": [
                "Utc": "2026-03-02T15:00:00.000Z",
                "Remaining": "01:30:00",
                "Extrapolating": true
            ]
        ]

        // Load initial state (same as processInitialState)
        for (topic, data) in initialState {
            store.updateRawState(topic: topic, data: data)
        }
        store.decodeAllFromRawState()

        // Verify all topics decoded
        XCTAssertEqual(store.drivers.count, 2)
        XCTAssertEqual(store.drivers["1"]?.tla, "VER")
        XCTAssertEqual(store.drivers["44"]?.tla, "HAM")
        XCTAssertEqual(store.weatherData?.airTemp, 28.5)
        XCTAssertEqual(store.weatherData?.trackTemp, 42.3)
        XCTAssertFalse(store.weatherData?.rainfall ?? true)
        XCTAssertEqual(store.trackStatus.status, .allClear)
        XCTAssertEqual(store.sessionStatus, .started)
        XCTAssertEqual(store.lapCount?.currentLap, 1)
        XCTAssertEqual(store.lapCount?.totalLaps, 57)
        XCTAssertEqual(store.extrapolatedClock?.remaining, "01:30:00")
    }

    // MARK: - Partial Updates (Sparse Merge)

    @MainActor
    func testTimingDataPartialUpdate() {
        // Load initial TimingData
        let initial: [String: Any] = [
            "TimingData": [
                "Lines": [
                    "1": [
                        "Position": "1",
                        "GapToLeader": "",
                        "IntervalToPositionAhead": ["Value": ""],
                        "LastLapTime": ["Value": "1:32.456"]
                    ],
                    "44": [
                        "Position": "2",
                        "GapToLeader": "+3.456",
                        "IntervalToPositionAhead": ["Value": "+3.456"],
                        "LastLapTime": ["Value": "1:33.012"]
                    ]
                ]
            ]
        ]

        store.updateRawState(topic: "TimingData", data: initial["TimingData"]!)
        store.decodeAllFromRawState()

        XCTAssertEqual(store.timingData["1"]?.position, "1")
        XCTAssertEqual(store.timingData["44"]?.position, "2")
        XCTAssertEqual(store.timingData["44"]?.gapToLeader, "+3.456")

        // Sparse update: only driver 44's gap changes
        let update: [String: Any] = [
            "Lines": [
                "44": [
                    "GapToLeader": "+2.891",
                    "IntervalToPositionAhead": ["Value": "+2.891"]
                ]
            ]
        ]

        store.mergeAndDecode(topic: "TimingData", data: update)

        // Driver 1 should be unchanged
        XCTAssertEqual(store.timingData["1"]?.position, "1")
        // Driver 44 gap updated, position preserved
        XCTAssertEqual(store.timingData["44"]?.position, "2")
        XCTAssertEqual(store.timingData["44"]?.gapToLeader, "+2.891")
    }

    @MainActor
    func testRaceControlMessagesAccumulate() {
        // Initial: one message
        let initial: [String: Any] = [
            "Messages": [
                "0": [
                    "Utc": "2026-03-02T15:00:00.000Z",
                    "Category": "Other",
                    "Message": "LIGHTS OUT AND AWAY WE GO",
                    "Flag": "GREEN"
                ]
            ]
        ]

        store.updateRawState(topic: "RaceControlMessages", data: initial)
        store.decodeAllFromRawState()

        XCTAssertEqual(store.raceControlMessages.count, 1)
        XCTAssertTrue(store.raceControlMessages[0].message.contains("LIGHTS OUT"))

        // Update: add a second message (sparse — only new key)
        let update: [String: Any] = [
            "Messages": [
                "1": [
                    "Utc": "2026-03-02T15:05:00.000Z",
                    "Category": "Flag",
                    "Message": "YELLOW FLAG IN SECTOR 2",
                    "Flag": "YELLOW",
                    "Scope": "Sector",
                    "Sector": 2
                ]
            ]
        ]

        store.mergeAndDecode(topic: "RaceControlMessages", data: update)

        XCTAssertEqual(store.raceControlMessages.count, 2)
        XCTAssertTrue(store.raceControlMessages[1].message.contains("YELLOW"))
        XCTAssertEqual(store.raceControlMessages[1].flag, .yellow)
    }

    @MainActor
    func testTeamRadioAccumulates() {
        let initial: [String: Any] = [
            "Captures": [
                "0": [
                    "Utc": "2026-03-02T15:10:00.000Z",
                    "RacingNumber": "1",
                    "Path": "TeamRadio/VER_lap5.m4a"
                ]
            ]
        ]

        store.updateRawState(topic: "TeamRadio", data: initial)
        store.decodeAllFromRawState()

        XCTAssertEqual(store.teamRadioCaptures.count, 1)
        XCTAssertEqual(store.teamRadioCaptures[0].racingNumber, "1")

        // Add a second capture
        let update: [String: Any] = [
            "Captures": [
                "1": [
                    "Utc": "2026-03-02T15:12:00.000Z",
                    "RacingNumber": "44",
                    "Path": "TeamRadio/HAM_lap6.m4a"
                ]
            ]
        ]

        store.mergeAndDecode(topic: "TeamRadio", data: update)

        XCTAssertEqual(store.teamRadioCaptures.count, 2)
        XCTAssertEqual(store.teamRadioCaptures[1].racingNumber, "44")
    }

    // MARK: - Compressed Topic Pipeline (.z)

    func testCompressedCarDataPipeline() throws {
        // Simulate what CarData.z looks like after decompression — object-format channels
        let carDataJSON: [String: Any] = [
            "Entries": [
                [
                    "Utc": "2026-03-02T15:00:00Z",
                    "Cars": [
                        "1": ["Channels": ["0": 10500, "2": 315, "3": 8, "4": 100, "5": 30, "45": 10]],
                        "44": ["Channels": ["0": 11200, "2": 298, "3": 7, "4": 85, "5": 0, "45": 0]]
                    ]
                ]
            ]
        ]

        // Compress to simulate .z topic
        let jsonData = try JSONSerialization.data(withJSONObject: carDataJSON)
        let compressed = try compressData(jsonData)
        let base64 = compressed.base64EncodedString()

        // Decompress (same as F1LiveTimingService.routeMessage)
        let decompressed = try Decompressor.decompress(base64)

        // Parse car telemetry
        let parsed = CarTelemetry.parseEntries(decompressed)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?["1"]?.rpm, 10500)
        XCTAssertEqual(parsed?["1"]?.speed, 315)
        XCTAssertEqual(parsed?["1"]?.gear, 8)
        XCTAssertEqual(parsed?["1"]?.throttle, 100)
        XCTAssertEqual(parsed?["1"]?.brake, 30)
        XCTAssertTrue(parsed?["1"]?.drs.isOpen ?? false) // DRS 10 = active
        XCTAssertEqual(parsed?["44"]?.rpm, 11200)
        XCTAssertEqual(parsed?["44"]?.speed, 298)
        XCTAssertEqual(parsed?["44"]?.brake, 0)
        XCTAssertFalse(parsed?["44"]?.drs.isOpen ?? true)
    }

    func testCompressedPositionPipeline() throws {
        let positionJSON: [String: Any] = [
            "Position": [
                [
                    "Timestamp": "2026-03-02T15:00:00Z",
                    "Entries": [
                        "1": ["X": 1234.5, "Y": 5678.9, "Z": 0.0, "Status": "OnTrack"],
                        "44": ["X": 2000.0, "Y": 3000.0, "Z": 0.0, "Status": "OnTrack"]
                    ]
                ]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: positionJSON)
        let compressed = try compressData(jsonData)
        let base64 = compressed.base64EncodedString()

        let decompressed = try Decompressor.decompress(base64)

        let parsed = DriverPosition.parseEntries(decompressed)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?["1"]?.x, 1234.5)
        XCTAssertEqual(parsed?["1"]?.y, 5678.9)
        XCTAssertTrue(parsed?["1"]?.isOnTrack ?? false)
    }

    // MARK: - Full mergeAndDecode Pipeline

    @MainActor
    func testDriverListUpdateMerge() {
        // Initial: 2 drivers
        let initial: [String: Any] = [
            "1": [
                "RacingNumber": "1", "Tla": "VER",
                "FirstName": "Max", "LastName": "Verstappen",
                "TeamName": "Red Bull Racing", "TeamColour": "3671C6",
                "Line": 1
            ],
            "44": [
                "RacingNumber": "44", "Tla": "HAM",
                "FirstName": "Lewis", "LastName": "Hamilton",
                "TeamName": "Ferrari", "TeamColour": "E8002D",
                "Line": 2
            ]
        ]

        store.updateRawState(topic: "DriverList", data: initial)
        store.decodeAllFromRawState()

        XCTAssertEqual(store.drivers.count, 2)
        XCTAssertEqual(store.drivers["1"]?.teamName, "Red Bull Racing")

        // Partial update: only change driver 44's line (position swap)
        let update: [String: Any] = [
            "44": ["Line": 1],
            "1": ["Line": 2]
        ]

        store.mergeAndDecode(topic: "DriverList", data: update)

        // Both drivers should still exist with updated lines
        XCTAssertEqual(store.drivers.count, 2)
        XCTAssertEqual(store.drivers["44"]?.line, 1)
        XCTAssertEqual(store.drivers["1"]?.line, 2)
        // Other fields preserved
        XCTAssertEqual(store.drivers["44"]?.tla, "HAM")
        XCTAssertEqual(store.drivers["1"]?.teamName, "Red Bull Racing")
    }

    @MainActor
    func testWeatherDataUpdate() {
        let initial: [String: Any] = [
            "AirTemp": "28.5", "TrackTemp": "42.3",
            "Humidity": "45", "Rainfall": "0",
            "WindSpeed": "3.2", "WindDirection": "180", "Pressure": "1013.2"
        ]

        store.updateRawState(topic: "WeatherData", data: initial)
        store.decodeAllFromRawState()

        XCTAssertEqual(store.weatherData?.airTemp, 28.5)
        XCTAssertFalse(store.weatherData?.rainfall ?? true)

        // Weather changes: rain starts!
        let update: [String: Any] = [
            "AirTemp": "26.0",
            "Rainfall": "1"
        ]

        store.mergeAndDecode(topic: "WeatherData", data: update)

        XCTAssertEqual(store.weatherData?.airTemp, 26.0)
        XCTAssertTrue(store.weatherData?.rainfall ?? false)
        // Unchanged fields preserved
        XCTAssertEqual(store.weatherData?.trackTemp, 42.3)
    }

    @MainActor
    func testSessionStatusProgression() {
        // Session starts
        store.mergeAndDecode(topic: "SessionStatus", data: ["Status": "Started"])
        XCTAssertEqual(store.sessionStatus, .started)

        // Session finishes
        store.mergeAndDecode(topic: "SessionStatus", data: ["Status": "Finished"])
        XCTAssertEqual(store.sessionStatus, .finished)

        // Session finalised
        store.mergeAndDecode(topic: "SessionStatus", data: ["Status": "Finalised"])
        XCTAssertEqual(store.sessionStatus, .finalised)
    }

    @MainActor
    func testTrackStatusFlagChanges() {
        // Green flag
        store.mergeAndDecode(topic: "TrackStatus", data: ["Status": "1", "Message": "AllClear"])
        XCTAssertEqual(store.trackStatus.status, .allClear)
        XCTAssertFalse(store.trackStatus.status.isHazard)

        // Safety car
        store.mergeAndDecode(topic: "TrackStatus", data: ["Status": "4", "Message": "SafetyCar"])
        XCTAssertEqual(store.trackStatus.status, .safetyCar)
        XCTAssertTrue(store.trackStatus.status.isHazard)

        // Red flag
        store.mergeAndDecode(topic: "TrackStatus", data: ["Status": "5", "Message": "RedFlag"])
        XCTAssertEqual(store.trackStatus.status, .redFlag)
        XCTAssertTrue(store.trackStatus.status.isHazard)
    }

    @MainActor
    func testLapCountProgression() {
        store.mergeAndDecode(topic: "LapCount", data: ["CurrentLap": 1, "TotalLaps": 57])
        XCTAssertEqual(store.lapCount?.currentLap, 1)

        // Lap 2
        store.mergeAndDecode(topic: "LapCount", data: ["CurrentLap": 2])
        XCTAssertEqual(store.lapCount?.currentLap, 2)
        XCTAssertEqual(store.lapCount?.totalLaps, 57)
    }

    // MARK: - Track Violation Pipeline

    @MainActor
    func testTrackViolationsFromRaceControl() {
        let initial: [String: Any] = [
            "Messages": [
                "0": [
                    "Utc": "2026-03-02T15:10:00.000Z",
                    "Category": "Flag",
                    "Message": "TRACK LIMITS - CAR 1 (VER) - LAP 5 - TURN 4",
                    "Flag": "BLACK AND WHITE",
                    "RacingNumber": "1",
                    "Lap": 5
                ],
                "1": [
                    "Utc": "2026-03-02T15:15:00.000Z",
                    "Category": "Flag",
                    "Message": "TRACK LIMITS - CAR 1 (VER) - LAP 8 - TURN 4",
                    "Flag": "BLACK AND WHITE",
                    "RacingNumber": "1",
                    "Lap": 8
                ],
                "2": [
                    "Utc": "2026-03-02T15:20:00.000Z",
                    "Category": "Flag",
                    "Message": "TRACK LIMITS - CAR 44 (HAM) - LAP 10 - TURN 4",
                    "Flag": "BLACK AND WHITE",
                    "RacingNumber": "44",
                    "Lap": 10
                ]
            ]
        ]

        store.updateRawState(topic: "RaceControlMessages", data: initial)
        store.decodeAllFromRawState()

        XCTAssertEqual(store.trackViolations["1"]?.count, 2)
        XCTAssertEqual(store.trackViolations["1"]?.lastLap, 8)
        XCTAssertEqual(store.trackViolations["44"]?.count, 1)
    }

    // MARK: - Timing Data with Sectors

    @MainActor
    func testTimingDataWithSectors() {
        let timing: [String: Any] = [
            "Lines": [
                "1": [
                    "Position": "1",
                    "GapToLeader": "",
                    "IntervalToPositionAhead": ["Value": ""],
                    "LastLapTime": ["Value": "1:32.456", "PersonalFastest": true],
                    "BestLapTime": ["Value": "1:31.200"],
                    "NumberOfLaps": 15,
                    "Sectors": [
                        "0": ["Value": "28.123", "Segments": [
                            "0": ["Status": 2049],
                            "1": ["Status": 2049],
                            "2": ["Status": 2049]
                        ]],
                        "1": ["Value": "34.567"],
                        "2": ["Value": "29.766"]
                    ]
                ]
            ]
        ]

        store.updateRawState(topic: "TimingData", data: timing)
        store.decodeAllFromRawState()

        let driver = store.timingData["1"]
        XCTAssertNotNil(driver)
        XCTAssertEqual(driver?.position, "1")
        XCTAssertEqual(driver?.lastLapTime, "1:32.456")
        XCTAssertEqual(driver?.bestLapTime, "1:31.200")
        XCTAssertEqual(driver?.numberOfLaps, 15)
        XCTAssertEqual(driver?.sectors.count, 3)
    }

    // MARK: - TimingAppData Pipeline

    @MainActor
    func testTimingAppDataDecodePipeline() {
        let timingAppData: [String: Any] = [
            "Lines": [
                "1": [
                    "GridPos": "1",
                    "Line": 1,
                    "Stints": [
                        "0": ["TotalLaps": 20, "Compound": "SOFT", "New": "true"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]

        store.updateRawState(topic: "TimingAppData", data: timingAppData)
        store.decodeAllFromRawState()

        XCTAssertEqual(store.timingAppData.count, 1)
        XCTAssertEqual(store.timingAppData["1"]?.gridPos, "1")
        XCTAssertEqual(store.timingAppData["1"]?.stints.count, 1)
        XCTAssertEqual(store.timingAppData["1"]?.stints[0].compound, "SOFT")
    }

    @MainActor
    func testTimingAppDataMergeUpdate() {
        let initial: [String: Any] = [
            "Lines": [
                "1": [
                    "GridPos": "1",
                    "Stints": [
                        "0": ["TotalLaps": 20, "Compound": "SOFT", "New": "true"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]

        store.updateRawState(topic: "TimingAppData", data: initial)
        store.decodeAllFromRawState()
        XCTAssertEqual(store.timingAppData["1"]?.stints.count, 1)

        // Add a second stint via merge
        let update: [String: Any] = [
            "Lines": [
                "1": [
                    "Stints": [
                        "1": ["TotalLaps": 25, "Compound": "HARD", "New": "true"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]

        store.mergeAndDecode(topic: "TimingAppData", data: update)
        XCTAssertEqual(store.timingAppData["1"]?.stints.count, 2)
        XCTAssertEqual(store.timingAppData["1"]?.stints[1].compound, "HARD")
    }

    // MARK: - Session Info

    @MainActor
    func testSessionInfoDecode() {
        let info: [String: Any] = [
            "Meeting": [
                "Name": "Bahrain GP",
                "OfficialName": "FORMULA 1 BAHRAIN GP",
                "Country": ["Name": "Bahrain", "Code": "BRN"],
                "Circuit": ["ShortName": "Sakhir", "Key": 63]
            ],
            "Name": "Race",
            "Type": "Race",
            "Path": "2026/2026-03-02_Bahrain/Race/",
            "GmtOffset": "03:00:00"
        ]

        store.updateRawState(topic: "SessionInfo", data: info)
        store.decodeAllFromRawState()

        XCTAssertEqual(store.sessionInfo?.meetingName, "Bahrain GP")
        XCTAssertEqual(store.sessionInfo?.sessionName, "Race")
        XCTAssertEqual(store.sessionInfo?.meetingCircuitShortName, "Sakhir")
        XCTAssertEqual(store.sessionInfo?.meetingCircuitKey, 63)
    }

    // MARK: - Helper

    private func compressData(_ data: Data) throws -> Data {
        let destinationSize = data.count + 1024
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { sourcePtr -> Int in
            guard let baseAddress = sourcePtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer, destinationSize,
                baseAddress, data.count,
                nil, COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else {
            throw NSError(domain: "test", code: 1)
        }

        return Data(bytes: destinationBuffer, count: compressedSize)
    }
}
