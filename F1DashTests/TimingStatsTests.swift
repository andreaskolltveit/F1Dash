import XCTest
@testable import F1Dash

final class TimingStatsTests: XCTestCase {

    // MARK: - TimingStats

    func testParseTimingStats() {
        let raw: [String: Any] = [
            "SessionType": "Race",
            "Lines": [
                "1": [
                    "PersonalBestLapTime": ["Value": "1:32.456", "Position": 1] as [String: Any],
                    "BestSectors": [
                        "0": ["Value": "28.123", "Position": 2] as [String: Any],
                        "1": ["Value": "33.456", "Position": 1] as [String: Any],
                        "2": ["Value": "30.877", "Position": 3] as [String: Any]
                    ] as [String: Any],
                    "BestSpeeds": [
                        "I1": ["Value": "305", "Position": 4] as [String: Any],
                        "I2": ["Value": "280", "Position": 2] as [String: Any],
                        "Fl": ["Value": "210", "Position": 10] as [String: Any],
                        "St": ["Value": "320", "Position": 1] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any],
                "44": [
                    "PersonalBestLapTime": ["Value": "1:32.789", "Position": 3] as [String: Any],
                    "BestSectors": [:] as [String: Any],
                    "BestSpeeds": [:] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]

        let stats = TimingDataParser.parseTimingStats(dict: raw)

        XCTAssertEqual(stats.sessionType, "Race")
        XCTAssertEqual(stats.drivers.count, 2)

        let driver1 = stats.drivers["1"]!
        XCTAssertEqual(driver1.personalBestLapTime, "1:32.456")
        XCTAssertEqual(driver1.personalBestLapPosition, 1)
        XCTAssertTrue(driver1.hasFastestLap)
        XCTAssertEqual(driver1.bestSectors.count, 3)
        XCTAssertEqual(driver1.bestSectors[1].value, "33.456")
        XCTAssertEqual(driver1.bestSectors[1].position, 1)
        XCTAssertEqual(driver1.bestSpeeds.st.value, "320")
        XCTAssertEqual(driver1.bestSpeeds.st.position, 1)
        XCTAssertEqual(driver1.bestSpeeds.i1.value, "305")

        let driver44 = stats.drivers["44"]!
        XCTAssertEqual(driver44.personalBestLapTime, "1:32.789")
        XCTAssertEqual(driver44.personalBestLapPosition, 3)
        XCTAssertFalse(driver44.hasFastestLap)
    }

    func testParseTimingStatsEmpty() {
        let raw: [String: Any] = [:]
        let stats = TimingDataParser.parseTimingStats(dict: raw)
        XCTAssertTrue(stats.drivers.isEmpty)
        XCTAssertNil(stats.sessionType)
    }

    // MARK: - ChampionshipPrediction

    func testParseChampionshipPrediction() {
        let raw: [String: Any] = [
            "Drivers": [
                "0": [
                    "RacingNumber": "1",
                    "CurrentPosition": 1,
                    "PredictedPosition": 1,
                    "CurrentPoints": 200,
                    "PredictedPoints": 225
                ] as [String: Any],
                "1": [
                    "RacingNumber": "44",
                    "CurrentPosition": 3,
                    "PredictedPosition": 2,
                    "CurrentPoints": 150,
                    "PredictedPoints": 168
                ] as [String: Any]
            ] as [String: Any],
            "Teams": [
                "0": [
                    "TeamName": "Red Bull Racing",
                    "CurrentPosition": 1,
                    "PredictedPosition": 1,
                    "CurrentPoints": 400,
                    "PredictedPoints": 440
                ] as [String: Any]
            ] as [String: Any]
        ]

        let prediction = TimingDataParser.parseChampionshipPrediction(dict: raw)

        XCTAssertEqual(prediction.drivers.count, 2)
        // Sorted by predictedPosition
        XCTAssertEqual(prediction.drivers[0].racingNumber, "1")
        XCTAssertEqual(prediction.drivers[1].racingNumber, "44")
        XCTAssertEqual(prediction.drivers[0].pointsDelta, 25.0)
        XCTAssertEqual(prediction.drivers[1].positionDelta, 1) // moved up 1 position (3 → 2)
        XCTAssertEqual(prediction.drivers[1].pointsDelta, 18.0)

        XCTAssertEqual(prediction.teams.count, 1)
        XCTAssertEqual(prediction.teams[0].teamName, "Red Bull Racing")
        XCTAssertEqual(prediction.teams[0].pointsDelta, 40.0)
    }

    func testChampionshipPredictionEmpty() {
        let raw: [String: Any] = [:]
        let prediction = TimingDataParser.parseChampionshipPrediction(dict: raw)
        XCTAssertTrue(prediction.drivers.isEmpty)
        XCTAssertTrue(prediction.teams.isEmpty)
    }

    // MARK: - SessionData

    func testParseSessionData() {
        let raw: [String: Any] = [
            "Series": [
                ["Utc": "2024-03-02T15:00:00.000Z", "Lap": 1] as [String: Any],
                ["Utc": "2024-03-02T15:01:30.000Z", "Lap": 2] as [String: Any],
                ["Utc": "2024-03-02T15:03:00.000Z", "Lap": 3] as [String: Any]
            ],
            "StatusSeries": [
                ["Utc": "2024-03-02T15:00:00.000Z", "SessionStatus": "Started"] as [String: Any],
                ["Utc": "2024-03-02T15:20:00.000Z", "TrackStatus": "Yellow", "SessionStatus": "Active"] as [String: Any]
            ]
        ]

        let sessionData = TimingDataParser.parseSessionData(dict: raw)

        XCTAssertEqual(sessionData.lapSeries.count, 3)
        XCTAssertEqual(sessionData.lapSeries[0].lap, 1)
        XCTAssertEqual(sessionData.lapSeries[2].lap, 3)

        XCTAssertEqual(sessionData.statusSeries.count, 2)
        XCTAssertEqual(sessionData.statusSeries[0].sessionStatus, "Started")
        XCTAssertNil(sessionData.statusSeries[0].trackStatus)
        XCTAssertEqual(sessionData.statusSeries[1].trackStatus, "Yellow")
    }

    func testParseSessionDataEmpty() {
        let raw: [String: Any] = [:]
        let sessionData = TimingDataParser.parseSessionData(dict: raw)
        XCTAssertTrue(sessionData.lapSeries.isEmpty)
        XCTAssertTrue(sessionData.statusSeries.isEmpty)
    }

    func testParseSessionDataWithSesionStatusTypo() {
        // F1 API has a known typo: "SesionStatus" instead of "SessionStatus"
        let raw: [String: Any] = [
            "StatusSeries": [
                ["Utc": "2024-03-02T15:00:00.000Z", "SesionStatus": "Started"] as [String: Any],
                ["Utc": "2024-03-02T15:20:00.000Z", "SesionStatus": "Active"] as [String: Any]
            ]
        ]

        let sessionData = TimingDataParser.parseSessionData(dict: raw)
        XCTAssertEqual(sessionData.statusSeries.count, 2)
        XCTAssertEqual(sessionData.statusSeries[0].sessionStatus, "Started")
        XCTAssertEqual(sessionData.statusSeries[1].sessionStatus, "Active")
    }

    func testParseSessionDataSessionStatusFallback() {
        // Correct spelling should also work as fallback
        let raw: [String: Any] = [
            "StatusSeries": [
                ["Utc": "2024-03-02T15:00:00.000Z", "SessionStatus": "Started"] as [String: Any]
            ]
        ]

        let sessionData = TimingDataParser.parseSessionData(dict: raw)
        XCTAssertEqual(sessionData.statusSeries.count, 1)
        XCTAssertEqual(sessionData.statusSeries[0].sessionStatus, "Started")
    }

    // MARK: - Store decoding integration

    @MainActor
    func testStoreDecodesTimingStats() {
        let store = LiveTimingStore()
        store.updateRawState(topic: "TimingStats", data: [
            "Lines": [
                "1": [
                    "PersonalBestLapTime": ["Value": "1:30.000", "Position": 1] as [String: Any],
                    "BestSectors": [:] as [String: Any],
                    "BestSpeeds": [:] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any])
        store.decodeTopic("TimingStats")

        XCTAssertNotNil(store.timingStats)
        XCTAssertEqual(store.timingStats?.drivers["1"]?.personalBestLapTime, "1:30.000")
        XCTAssertTrue(store.timingStats?.drivers["1"]?.hasFastestLap ?? false)
    }

    @MainActor
    func testStoreDecodesChampionshipPrediction() {
        let store = LiveTimingStore()
        store.updateRawState(topic: "ChampionshipPrediction", data: [
            "Drivers": [
                "0": [
                    "RacingNumber": "1",
                    "CurrentPosition": 1,
                    "PredictedPosition": 1,
                    "CurrentPoints": 100,
                    "PredictedPoints": 125
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any])
        store.decodeTopic("ChampionshipPrediction")

        XCTAssertNotNil(store.championshipPrediction)
        XCTAssertEqual(store.championshipPrediction?.drivers.count, 1)
        XCTAssertEqual(store.championshipPrediction?.drivers.first?.pointsDelta, 25.0)
    }

    @MainActor
    func testStoreDecodesTimingAppData() {
        let store = LiveTimingStore()
        store.updateRawState(topic: "TimingAppData", data: [
            "Lines": [
                "1": [
                    "GridPos": "1",
                    "Line": 1,
                    "Stints": [
                        "0": ["TotalLaps": 20, "Compound": "SOFT", "New": "true"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any])
        store.decodeTopic("TimingAppData")

        XCTAssertEqual(store.timingAppData.count, 1)
        XCTAssertEqual(store.timingAppData["1"]?.gridPos, "1")
        XCTAssertEqual(store.timingAppData["1"]?.stints.count, 1)
        XCTAssertEqual(store.timingAppData["1"]?.stints[0].compound, "SOFT")
        XCTAssertEqual(store.timingAppData["1"]?.stints[0].totalLaps, 20)
        XCTAssertEqual(store.timingAppData["1"]?.stints[0].isNew, true)
    }

    @MainActor
    func testStoreDecodesSessionData() {
        let store = LiveTimingStore()
        store.updateRawState(topic: "SessionData", data: [
            "Series": [
                ["Utc": "2024-03-02T15:00:00Z", "Lap": 1] as [String: Any]
            ],
            "StatusSeries": [
                ["Utc": "2024-03-02T15:00:00Z", "SessionStatus": "Started"] as [String: Any]
            ]
        ] as [String: Any])
        store.decodeTopic("SessionData")

        XCTAssertNotNil(store.sessionData)
        XCTAssertEqual(store.sessionData?.lapSeries.count, 1)
        XCTAssertEqual(store.sessionData?.statusSeries.count, 1)
    }
}
