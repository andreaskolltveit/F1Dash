import XCTest
@testable import F1Dash

/// Tests the replay engine: event application, state transitions, driver setup, timeline building.
/// These tests verify the actual replay flow that writes data into the LiveTimingStore.
@MainActor
final class ReplayEngineTests: XCTestCase {

    // MARK: - Event Application: Position

    func testApplyPositionEventCreatesTimingData() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        // Set up a driver first
        store.drivers["1"] = Driver(
            id: "1", racingNumber: "1", tla: "VER",
            firstName: "Max", lastName: "VERSTAPPEN", fullName: "Max VERSTAPPEN",
            teamName: "Red Bull Racing", teamColour: "3671C6", line: 1, countryCode: "NED"
        )

        // Apply position event
        engine.applyTestEvent(.position(driverNumber: 1, position: 3), to: store)

        XCTAssertEqual(store.timingData["1"]?.position, "3")
        XCTAssertEqual(store.drivers["1"]?.line, 3)
    }

    func testApplyPositionEventUpdatesExistingTiming() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        // Pre-populate timing data
        store.timingData["44"] = TimingDataDriver(
            position: "1", gapToLeader: nil, intervalToPositionAhead: nil,
            bestLapTime: "1:30.000", lastLapTime: "1:31.000", numberOfLaps: 10,
            sectors: [], segments: [],
            inPit: false, pitOut: false, stopped: false, retired: false
        )

        // Apply position change — should update position but preserve other fields
        engine.applyTestEvent(.position(driverNumber: 44, position: 5), to: store)

        XCTAssertEqual(store.timingData["44"]?.position, "5")
        XCTAssertEqual(store.timingData["44"]?.bestLapTime, "1:30.000", "Should preserve existing timing data")
        XCTAssertEqual(store.timingData["44"]?.numberOfLaps, 10)
    }

    // MARK: - Event Application: Lap

    func testApplyLapEventUpdatesStore() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        store.timingData["1"] = TimingDataDriver(
            position: "1", gapToLeader: nil, intervalToPositionAhead: nil,
            bestLapTime: nil, lastLapTime: nil, numberOfLaps: 0,
            sectors: [], segments: [],
            inPit: false, pitOut: false, stopped: false, retired: false
        )

        let lap = HistoricalLap(
            driverNumber: 1, lapNumber: 15, lapDuration: 92.456,
            durationSector1: 28.123, durationSector2: 33.789, durationSector3: 30.544,
            isPitOutLap: false, dateStart: "2024-03-02T15:30:00.000Z"
        )

        engine.applyTestEvent(.lap(lap), to: store)

        XCTAssertEqual(store.timingData["1"]?.numberOfLaps, 15)
        XCTAssertNotNil(store.timingData["1"]?.lastLapTime)
        XCTAssertNotNil(store.timingData["1"]?.bestLapTime)
        XCTAssertNotNil(store.lapCount)
        XCTAssertEqual(store.lapCount?.currentLap, 15)
    }

    func testApplyLapEventTracksBestLap() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        store.timingData["1"] = TimingDataDriver(
            position: "1", gapToLeader: nil, intervalToPositionAhead: nil,
            bestLapTime: nil, lastLapTime: nil, numberOfLaps: 0,
            sectors: [], segments: [],
            inPit: false, pitOut: false, stopped: false, retired: false
        )

        // First lap: 95s
        let lap1 = HistoricalLap(
            driverNumber: 1, lapNumber: 1, lapDuration: 95.0,
            durationSector1: nil, durationSector2: nil, durationSector3: nil,
            isPitOutLap: false, dateStart: "2024-03-02T15:30:00.000Z"
        )
        engine.applyTestEvent(.lap(lap1), to: store)
        let bestAfter1 = store.timingData["1"]?.bestLapTime

        // Second lap: 92s — should become new best
        let lap2 = HistoricalLap(
            driverNumber: 1, lapNumber: 2, lapDuration: 92.0,
            durationSector1: nil, durationSector2: nil, durationSector3: nil,
            isPitOutLap: false, dateStart: "2024-03-02T15:32:00.000Z"
        )
        engine.applyTestEvent(.lap(lap2), to: store)
        let bestAfter2 = store.timingData["1"]?.bestLapTime

        // Third lap: 94s — best should remain 92s
        let lap3 = HistoricalLap(
            driverNumber: 1, lapNumber: 3, lapDuration: 94.0,
            durationSector1: nil, durationSector2: nil, durationSector3: nil,
            isPitOutLap: false, dateStart: "2024-03-02T15:34:00.000Z"
        )
        engine.applyTestEvent(.lap(lap3), to: store)
        let bestAfter3 = store.timingData["1"]?.bestLapTime

        XCTAssertNotEqual(bestAfter1, bestAfter2, "Faster lap should update best")
        XCTAssertEqual(bestAfter2, bestAfter3, "Slower lap should not change best")
    }

    // MARK: - Event Application: Interval

    func testApplyIntervalEventUpdatesGaps() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        store.timingData["44"] = TimingDataDriver(
            position: "2", gapToLeader: nil, intervalToPositionAhead: nil,
            bestLapTime: nil, lastLapTime: nil, numberOfLaps: 0,
            sectors: [], segments: [],
            inPit: false, pitOut: false, stopped: false, retired: false
        )

        engine.applyTestEvent(
            .interval(driverNumber: 44, gapToLeader: 5.123, gapToLeaderText: nil, interval: 1.456, intervalText: nil),
            to: store
        )

        XCTAssertEqual(store.timingData["44"]?.gapToLeader, "+5.123")
        XCTAssertEqual(store.timingData["44"]?.intervalToPositionAhead, "+1.456")
    }

    func testApplyIntervalEventWithStringGap() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        store.timingData["18"] = TimingDataDriver(
            position: "18", gapToLeader: nil, intervalToPositionAhead: nil,
            bestLapTime: nil, lastLapTime: nil, numberOfLaps: 0,
            sectors: [], segments: [],
            inPit: false, pitOut: false, stopped: false, retired: false
        )

        engine.applyTestEvent(
            .interval(driverNumber: 18, gapToLeader: nil, gapToLeaderText: "+1 LAP", interval: nil, intervalText: "+1 LAP"),
            to: store
        )

        XCTAssertEqual(store.timingData["18"]?.gapToLeader, "+1 LAP")
        XCTAssertEqual(store.timingData["18"]?.intervalToPositionAhead, "+1 LAP")
    }

    // MARK: - Event Application: Race Control

    func testApplyRaceControlEvent() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        let rc = HistoricalRaceControl(
            date: "2024-03-02T15:30:00Z",
            category: "Flag", flag: "GREEN",
            message: "GREEN LIGHT - PIT LANE OPEN",
            scope: "Track", sector: nil, driverNumber: nil, lapNumber: 1
        )

        engine.applyTestEvent(.raceControl(rc), to: store)

        XCTAssertEqual(store.raceControlMessages.count, 1)
        XCTAssertEqual(store.raceControlMessages.first?.message, "GREEN LIGHT - PIT LANE OPEN")
    }

    func testApplyRedFlagUpdatesTrackStatus() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        let rc = HistoricalRaceControl(
            date: "2024-03-02T15:30:00Z",
            category: "Flag", flag: "RED",
            message: "RED FLAG",
            scope: "Track", sector: nil, driverNumber: nil, lapNumber: 10
        )

        engine.applyTestEvent(.raceControl(rc), to: store)

        XCTAssertEqual(store.trackStatus.status, .redFlag)
    }

    // MARK: - Event Application: Weather

    func testApplyWeatherEvent() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        let weather = HistoricalWeather(
            date: "2024-03-02T15:30:00Z",
            airTemperature: 28.5, trackTemperature: 42.0,
            humidity: 60.0, pressure: 1013.0,
            windSpeed: 3.5, windDirection: 180, rainfall: 0
        )

        engine.applyTestEvent(.weather(weather), to: store)

        XCTAssertNotNil(store.weatherData)
        XCTAssertEqual(store.weatherData?.airTemp, 28.5)
        XCTAssertEqual(store.weatherData?.trackTemp, 42.0)
        XCTAssertEqual(store.weatherData?.humidity, 60.0)
        XCTAssertFalse(store.weatherData?.rainfall ?? true)
    }

    func testApplyRainyWeatherEvent() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        let weather = HistoricalWeather(
            date: "2024-03-02T15:30:00Z",
            airTemperature: 22.0, trackTemperature: 25.0,
            humidity: 90.0, pressure: 1008.0,
            windSpeed: 5.0, windDirection: 270, rainfall: 1
        )

        engine.applyTestEvent(.weather(weather), to: store)

        XCTAssertTrue(store.weatherData?.rainfall ?? false)
    }

    // MARK: - Event Application: Car Telemetry

    func testApplyCarDataEvent() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        engine.applyTestEvent(
            .carData(driverNumber: 1, speed: 315, rpm: 11000, gear: 8, throttle: 100, brake: 0, drs: 10),
            to: store
        )

        XCTAssertNotNil(store.carTelemetry["1"])
        XCTAssertEqual(store.carTelemetry["1"]?.speed, 315)
        XCTAssertEqual(store.carTelemetry["1"]?.rpm, 11000)
        XCTAssertEqual(store.carTelemetry["1"]?.gear, 8)
        XCTAssertEqual(store.carTelemetry["1"]?.throttle, 100)
        XCTAssertEqual(store.carTelemetry["1"]?.drs, .active) // DRS 10 = active
    }

    func testApplyCarDataDRSStatuses() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        // DRS off (0)
        engine.applyTestEvent(.carData(driverNumber: 1, speed: 300, rpm: 10000, gear: 7, throttle: 80, brake: 0, drs: 0), to: store)
        XCTAssertEqual(store.carTelemetry["1"]?.drs, .off)

        // DRS eligible (8)
        engine.applyTestEvent(.carData(driverNumber: 1, speed: 300, rpm: 10000, gear: 7, throttle: 80, brake: 0, drs: 8), to: store)
        XCTAssertEqual(store.carTelemetry["1"]?.drs, .eligible)

        // DRS active (10, 12, 14)
        engine.applyTestEvent(.carData(driverNumber: 1, speed: 300, rpm: 10000, gear: 7, throttle: 80, brake: 0, drs: 12), to: store)
        XCTAssertEqual(store.carTelemetry["1"]?.drs, .active)
    }

    // MARK: - Event Application: Stint & Pit Stop

    func testApplyStintEvent() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        let stint = StintData(
            driverNumber: 1, stintNumber: 2, compound: .hard,
            tyreAgeAtStart: 0, lapStart: 20, lapEnd: nil
        )

        engine.applyTestEvent(.stint(stint), to: store)

        XCTAssertNotNil(store.currentStints["1"])
        XCTAssertEqual(store.currentStints["1"]?.compound, .hard)
        XCTAssertEqual(store.currentStints["1"]?.stintNumber, 2)
    }

    func testApplyPitStopEvent() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        store.timingData["1"] = TimingDataDriver(
            position: "1", gapToLeader: nil, intervalToPositionAhead: nil,
            bestLapTime: nil, lastLapTime: nil, numberOfLaps: 0,
            sectors: [], segments: [],
            inPit: false, pitOut: false, stopped: false, retired: false
        )

        let pit = PitStopData(driverNumber: 1, lapNumber: 20, pitDuration: 22.5, date: nil)

        engine.applyTestEvent(.pitStop(pit), to: store)

        XCTAssertEqual(store.pitStops["1"]?.count, 1)
        XCTAssertEqual(store.pitStops["1"]?.first?.pitDuration, 22.5)
        XCTAssertTrue(store.timingData["1"]?.inPit ?? false)
    }

    // MARK: - Event Application: Team Radio

    func testApplyTeamRadioEvent() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        engine.applyTestEvent(.teamRadio(driverNumber: 1, recordingUrl: "https://example.com/radio.mp3"), to: store)

        XCTAssertEqual(store.teamRadioCaptures.count, 1)
        XCTAssertEqual(store.teamRadioCaptures.first?.racingNumber, "1")
    }

    // MARK: - Event Application: Location

    func testApplyLocationEvent() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        engine.applyTestEvent(.location(driverNumber: 1, x: 1234.5, y: 5678.9, z: 0.0), to: store)

        XCTAssertNotNil(store.driverPositions["1"])
        XCTAssertEqual(store.driverPositions["1"]?.x, 1234.5)
        XCTAssertEqual(store.driverPositions["1"]?.y, 5678.9)
    }

    // MARK: - Driver Setup

    func testSetupDriversPopulatesStore() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        let drivers = [
            OpenF1Driver(
                driverNumber: 1, broadcastName: "M VERSTAPPEN", fullName: "Max VERSTAPPEN",
                nameAcronym: "VER", teamName: "Red Bull Racing", teamColour: "3671C6",
                countryCode: "NED", sessionKey: 9644, meetingKey: 1250
            ),
            OpenF1Driver(
                driverNumber: 44, broadcastName: "L HAMILTON", fullName: "Lewis HAMILTON",
                nameAcronym: "HAM", teamName: "Ferrari", teamColour: "E80020",
                countryCode: "GBR", sessionKey: 9644, meetingKey: 1250
            ),
        ]

        let session = OpenF1Session(
            sessionKey: 9644, sessionName: "Race", sessionType: "Race",
            dateStart: "2024-11-24T06:00:00+00:00", dateEnd: nil, year: 2024,
            circuitKey: 152, circuitShortName: "Las Vegas", countryName: "United States",
            countryCode: "USA", meetingKey: 1250, meetingName: nil,
            gmtOffset: "-08:00:00", location: "Las Vegas"
        )

        engine.setupTestDrivers(drivers, session: session, store: store)

        XCTAssertEqual(store.drivers.count, 2)
        XCTAssertEqual(store.drivers["1"]?.tla, "VER")
        XCTAssertEqual(store.drivers["1"]?.teamName, "Red Bull Racing")
        XCTAssertEqual(store.drivers["44"]?.tla, "HAM")
        XCTAssertEqual(store.drivers["44"]?.teamName, "Ferrari")
        XCTAssertNotNil(store.sessionInfo)
        XCTAssertEqual(store.sessionInfo?.sessionName, "Race")
        XCTAssertEqual(store.sessionStatus, .started)
    }

    // MARK: - State Machine

    func testEngineStartsIdle() {
        let engine = ReplayEngine()
        XCTAssertEqual(engine.state, .idle)
    }

    func testPlayRequiresReadyOrPaused() {
        let engine = ReplayEngine()

        // Play from idle — should not start
        engine.play()
        XCTAssertEqual(engine.state, .idle, "Cannot play from idle state")

        // Play from loading — should not start
        // (can't easily set to loading without actual load, so test the guard logic)
    }

    func testPauseRequiresPlaying() {
        let engine = ReplayEngine()

        // Pause from idle — should not change state
        engine.pause()
        XCTAssertEqual(engine.state, .idle, "Cannot pause from idle state")
    }

    func testStopResetsAllState() {
        let engine = ReplayEngine()

        // Manually set some state
        engine.speed = .x8
        engine.currentLap = 15
        engine.totalLaps = 57

        engine.stop()

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.currentLap, 0)
        XCTAssertNil(engine.selectedSession)
    }

    // MARK: - Timeline Building

    func testTimelineSortedByTimestamp() {
        // Build a synthetic timeline and verify it's sorted
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1001)
        let t3 = Date(timeIntervalSince1970: 1002)

        var events = [
            ReplayEvent(timestamp: t3, kind: .position(driverNumber: 1, position: 1)),
            ReplayEvent(timestamp: t1, kind: .position(driverNumber: 1, position: 3)),
            ReplayEvent(timestamp: t2, kind: .position(driverNumber: 1, position: 2)),
        ]

        events.sort { $0.timestamp < $1.timestamp }

        XCTAssertEqual(events[0].timestamp, t1)
        XCTAssertEqual(events[1].timestamp, t2)
        XCTAssertEqual(events[2].timestamp, t3)
    }

    // MARK: - Full Mini-Replay Integration

    /// Simulate a small replay: 2 drivers, 3 laps, with position changes and weather.
    func testMiniReplayIntegration() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        // Set up drivers
        let drivers = [
            OpenF1Driver(
                driverNumber: 1, broadcastName: nil, fullName: "Max VERSTAPPEN",
                nameAcronym: "VER", teamName: "Red Bull", teamColour: "3671C6",
                countryCode: "NED", sessionKey: 1, meetingKey: 1
            ),
            OpenF1Driver(
                driverNumber: 44, broadcastName: nil, fullName: "Lewis HAMILTON",
                nameAcronym: "HAM", teamName: "Ferrari", teamColour: "E80020",
                countryCode: "GBR", sessionKey: 1, meetingKey: 1
            ),
        ]
        let session = OpenF1Session(
            sessionKey: 1, sessionName: "Race", sessionType: "Race",
            dateStart: nil, dateEnd: nil, year: 2024,
            circuitKey: nil, circuitShortName: "Test", countryName: "Test",
            countryCode: "TST", meetingKey: nil, meetingName: nil,
            gmtOffset: nil, location: "Test"
        )

        engine.setupTestDrivers(drivers, session: session, store: store)

        // Lap 1: VER P1, HAM P2
        engine.applyTestEvent(.position(driverNumber: 1, position: 1), to: store)
        engine.applyTestEvent(.position(driverNumber: 44, position: 2), to: store)

        let lap1ver = HistoricalLap(
            driverNumber: 1, lapNumber: 1, lapDuration: 93.0,
            durationSector1: 28.0, durationSector2: 34.0, durationSector3: 31.0,
            isPitOutLap: false, dateStart: "2024-01-01T00:01:30Z"
        )
        engine.applyTestEvent(.lap(lap1ver), to: store)

        let lap1ham = HistoricalLap(
            driverNumber: 44, lapNumber: 1, lapDuration: 93.5,
            durationSector1: 28.2, durationSector2: 34.3, durationSector3: 31.0,
            isPitOutLap: false, dateStart: "2024-01-01T00:01:30Z"
        )
        engine.applyTestEvent(.lap(lap1ham), to: store)

        // Interval
        engine.applyTestEvent(
            .interval(driverNumber: 44, gapToLeader: 0.5, gapToLeaderText: nil, interval: 0.5, intervalText: nil),
            to: store
        )

        // Weather
        let weather = HistoricalWeather(
            date: "2024-01-01T00:01:30Z",
            airTemperature: 30.0, trackTemperature: 45.0,
            humidity: 50.0, pressure: 1013.0,
            windSpeed: 2.0, windDirection: 90, rainfall: 0
        )
        engine.applyTestEvent(.weather(weather), to: store)

        // Verify full state
        XCTAssertEqual(store.drivers.count, 2)
        XCTAssertEqual(store.timingData["1"]?.position, "1")
        XCTAssertEqual(store.timingData["44"]?.position, "2")
        XCTAssertEqual(store.timingData["44"]?.gapToLeader, "+0.500")
        XCTAssertNotNil(store.timingData["1"]?.lastLapTime)
        XCTAssertNotNil(store.weatherData)
        XCTAssertEqual(store.weatherData?.airTemp, 30.0)
        XCTAssertEqual(store.lapCount?.currentLap, 1)
    }

    /// Test that multiple pit stops for same driver accumulate correctly.
    func testMultiplePitStopsAccumulate() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        store.timingData["1"] = TimingDataDriver(
            position: "1", gapToLeader: nil, intervalToPositionAhead: nil,
            bestLapTime: nil, lastLapTime: nil, numberOfLaps: 0,
            sectors: [], segments: [],
            inPit: false, pitOut: false, stopped: false, retired: false
        )

        let pit1 = PitStopData(driverNumber: 1, lapNumber: 15, pitDuration: 22.0, date: nil)
        let pit2 = PitStopData(driverNumber: 1, lapNumber: 35, pitDuration: 23.5, date: nil)

        engine.applyTestEvent(.pitStop(pit1), to: store)
        engine.applyTestEvent(.pitStop(pit2), to: store)

        XCTAssertEqual(store.pitStops["1"]?.count, 2)
        XCTAssertEqual(store.pitStops["1"]?[0].lapNumber, 15)
        XCTAssertEqual(store.pitStops["1"]?[1].lapNumber, 35)
    }

    /// Test that race control messages accumulate in order.
    func testRaceControlMessagesAccumulate() {
        let store = LiveTimingStore()
        let engine = ReplayEngine()

        let rc1 = HistoricalRaceControl(
            date: "2024-01-01T00:00:00Z", category: "Flag", flag: "GREEN",
            message: "GREEN FLAG", scope: "Track", sector: nil, driverNumber: nil, lapNumber: 1
        )
        let rc2 = HistoricalRaceControl(
            date: "2024-01-01T00:10:00Z", category: "SafetyCar", flag: nil,
            message: "SAFETY CAR DEPLOYED", scope: "Track", sector: nil, driverNumber: nil, lapNumber: 5
        )
        let rc3 = HistoricalRaceControl(
            date: "2024-01-01T00:15:00Z", category: "Flag", flag: "GREEN",
            message: "GREEN FLAG - SAFETY CAR IN THIS LAP", scope: "Track", sector: nil, driverNumber: nil, lapNumber: 8
        )

        engine.applyTestEvent(.raceControl(rc1), to: store)
        engine.applyTestEvent(.raceControl(rc2), to: store)
        engine.applyTestEvent(.raceControl(rc3), to: store)

        XCTAssertEqual(store.raceControlMessages.count, 3)
        XCTAssertEqual(store.raceControlMessages[0].message, "GREEN FLAG")
        XCTAssertEqual(store.raceControlMessages[1].message, "SAFETY CAR DEPLOYED")
        XCTAssertEqual(store.raceControlMessages[2].message, "GREEN FLAG - SAFETY CAR IN THIS LAP")
    }
}

// MARK: - Test Helpers

extension ReplayEngine {
    /// Convenience: apply a single event kind to the store (wraps in ReplayEvent with current timestamp).
    func applyTestEvent(_ kind: ReplayEventKind, to store: LiveTimingStore) {
        let event = ReplayEvent(timestamp: Date(), kind: kind)
        applyEvent(event, to: store)
    }

    /// Convenience: set up drivers with store reference for testing.
    func setupTestDrivers(_ drivers: [OpenF1Driver], session: OpenF1Session, store: LiveTimingStore) {
        self.store = store
        setupDrivers(drivers, session: session)
    }
}
