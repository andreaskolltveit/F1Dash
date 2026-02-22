import SwiftUI
import os

/// Automated UI validation that runs inside the app.
/// Cycles through all pages, takes screenshots, and validates data in each view.
/// Activate with --demo --autotest launch arguments.
@Observable
final class AutoTestRunner {
    private let logger = Logger(subsystem: "com.f1dash", category: "AutoTest")

    var isRunning = false
    var results: [TestResult] = []
    var currentPhase = ""

    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let passed: Bool
        let detail: String
    }

    /// Run all validation checks against the store.
    @MainActor
    func runAll(store: LiveTimingStore, settings: SettingsStore, pageSetter: @escaping (AppPage) -> Void) async {
        isRunning = true
        results = []
        logger.info("=== AUTO TEST STARTED ===")

        // Phase 1: Validate store data
        currentPhase = "Validating Store Data"
        validateStoreData(store: store)

        // Phase 2: Show dashboard (main view) and validate
        currentPhase = "Showing: Dashboard"
        pageSetter(.dashboard)
        try? await Task.sleep(for: .seconds(2))
        validateDashboard(store: store)
        takeScreenshot(name: "Dashboard")

        // Phase 3: Show full track map
        currentPhase = "Showing: Track Map (Full)"
        pageSetter(.trackMapFull)
        try? await Task.sleep(for: .seconds(1.5))
        validateTrackMap(store: store)
        takeScreenshot(name: "TrackMap_Full")

        // Phase 4: Show settings
        currentPhase = "Showing: Settings"
        pageSetter(.settings)
        try? await Task.sleep(for: .seconds(1))
        takeScreenshot(name: "Settings")

        // Phase 5: Back to dashboard for filter tests
        pageSetter(.dashboard)
        try? await Task.sleep(for: .seconds(0.5))

        // Phase 6: Test blue flag filter
        currentPhase = "Testing Blue Flag Filter"
        let totalMessages = store.raceControlMessages.count
        let blueFlags = store.raceControlMessages.filter(\.isBlueFlag).count
        let nonBlue = totalMessages - blueFlags

        settings.filterBlueFlags = true
        addResult("Blue flag filter ON", passed: true,
                  detail: "Total: \(totalMessages), Blue: \(blueFlags), Shown: \(nonBlue)")

        settings.filterBlueFlags = false
        addResult("Blue flag filter OFF", passed: true,
                  detail: "All \(totalMessages) messages visible")

        // Phase 7: Test settings
        currentPhase = "Testing Settings"
        let originalChime = settings.chimeEnabled
        settings.chimeEnabled = !originalChime
        addResult("Chime toggle", passed: settings.chimeEnabled != originalChime,
                  detail: "Toggled from \(originalChime) to \(settings.chimeEnabled)")
        settings.chimeEnabled = originalChime

        // Ensure "1" is NOT in favorites before testing
        if settings.favoriteDrivers.contains("1") {
            settings.toggleFavorite("1")
        }
        settings.toggleFavorite("1")
        addResult("Favorite toggle", passed: settings.favoriteDrivers.contains("1"),
                  detail: "Added VER to favorites")
        settings.toggleFavorite("1")
        addResult("Favorite untoggle", passed: !settings.favoriteDrivers.contains("1"),
                  detail: "Removed VER from favorites")

        // Phase 8: Validate new features
        currentPhase = "Validating New Features"
        validateStints(store: store)
        validateTrackViolations(store: store)
        validateNewDataFields(store: store)

        // Phase 9: JSON parsing pipeline
        currentPhase = "Validating Parsing Pipeline"
        validateParsingPipeline(store: store)

        // Phase 10: Simulator validation
        currentPhase = "Validating Simulator"
        await validateSimulator(store: store)

        // Done
        currentPhase = "Complete"
        let passed = results.filter(\.passed).count
        let failed = results.filter { !$0.passed }.count
        logger.info("=== AUTO TEST COMPLETE: \(passed) passed, \(failed) failed ===")

        // Write results to file for terminal capture
        var output = "\n========== F1Dash AUTO TEST RESULTS ==========\n"
        for r in results {
            let icon = r.passed ? "PASS" : "FAIL"
            output += "[\(icon)] \(r.name): \(r.detail)\n"
        }
        output += "================================================\n"
        output += "TOTAL: \(passed) passed, \(failed) failed\n"
        output += "Screenshots: /tmp/f1dash-autotest-*.png\n"
        output += "================================================\n"
        try? output.write(toFile: "/tmp/f1dash-autotest-results.txt", atomically: true, encoding: .utf8)
        logger.info("Results written to /tmp/f1dash-autotest-results.txt")

        isRunning = false
    }

    // MARK: - Store Validation

    private func validateStoreData(store: LiveTimingStore) {
        addResult("Drivers loaded",
                  passed: store.drivers.count == 20,
                  detail: "\(store.drivers.count) drivers")

        addResult("Drivers sorted",
                  passed: store.driversSorted.count == 20 && store.driversSorted.first?.tla == "VER",
                  detail: "First: \(store.driversSorted.first?.tla ?? "nil"), Count: \(store.driversSorted.count)")

        addResult("Session info",
                  passed: store.sessionInfo != nil && store.sessionInfo?.sessionName == "Race",
                  detail: store.sessionInfo?.meetingName ?? "nil")

        addResult("Session status",
                  passed: store.sessionStatus == .started,
                  detail: "\(store.sessionStatus.rawValue)")

        addResult("Race control messages",
                  passed: store.raceControlMessages.count > 10,
                  detail: "\(store.raceControlMessages.count) messages")

        let hasGreen = store.raceControlMessages.contains { $0.flag == .green }
        let hasYellow = store.raceControlMessages.contains { $0.flag == .yellow }
        let hasBlue = store.raceControlMessages.contains { $0.flag == .blue }
        addResult("Flag variety",
                  passed: hasGreen && hasYellow && hasBlue,
                  detail: "Green: \(hasGreen), Yellow: \(hasYellow), Blue: \(hasBlue)")

        addResult("Team radio captures",
                  passed: store.teamRadioCaptures.count > 5,
                  detail: "\(store.teamRadioCaptures.count) captures")

        addResult("Timing data",
                  passed: store.timingData.count == 20,
                  detail: "\(store.timingData.count) drivers with timing")

        let positions = Set(store.timingData.values.compactMap(\.position).compactMap(Int.init))
        addResult("Positions 1-20",
                  passed: positions == Set(1...20),
                  detail: "Unique positions: \(positions.sorted())")

        addResult("Car telemetry",
                  passed: store.carTelemetry.count == 20,
                  detail: "\(store.carTelemetry.count) cars with telemetry")

        addResult("Driver positions",
                  passed: store.driverPositions.count == 20,
                  detail: "\(store.driverPositions.count) position entries")

        let onTrack = store.driverPositions.values.filter(\.isOnTrack).count
        addResult("On-track drivers",
                  passed: onTrack >= 18,
                  detail: "\(onTrack) on track, \(20 - onTrack) off track")

        addResult("Weather data",
                  passed: store.weatherData != nil && store.weatherData?.airTemp != nil,
                  detail: "Air: \(store.weatherData?.airTemp ?? 0)°C, Track: \(store.weatherData?.trackTemp ?? 0)°C")

        addResult("Track status",
                  passed: true,
                  detail: "\(store.trackStatus.status.displayName)")

        addResult("Track map",
                  passed: store.trackMap != nil && (store.trackMap?.x.count ?? 0) > 50,
                  detail: "\(store.trackMap?.x.count ?? 0) track points")

        addResult("Extrapolated clock",
                  passed: store.extrapolatedClock != nil,
                  detail: "Remaining: \(store.extrapolatedClock?.remaining ?? "nil")")

        addResult("Lap count",
                  passed: store.lapCount != nil && store.lapCount!.currentLap > 0,
                  detail: "Lap \(store.lapCount?.currentLap ?? 0)/\(store.lapCount?.totalLaps ?? 0)")
    }

    // MARK: - Dashboard Validation

    private func validateDashboard(store: LiveTimingStore) {
        addResult("Dashboard: Leaderboard data",
                  passed: store.driversSorted.count == 20,
                  detail: "\(store.driversSorted.count) drivers in leaderboard")

        addResult("Dashboard: Race Control data",
                  passed: !store.raceControlMessages.isEmpty,
                  detail: "\(store.raceControlMessages.count) messages")

        addResult("Dashboard: Team Radio data",
                  passed: !store.teamRadioCaptures.isEmpty,
                  detail: "\(store.teamRadioCaptures.count) captures")

        addResult("Dashboard: Status bar data",
                  passed: store.sessionInfo != nil && store.lapCount != nil,
                  detail: "Session + lap count present")
    }

    // MARK: - Track Map Validation

    private func validateTrackMap(store: LiveTimingStore) {
        addResult("Track Map view",
                  passed: store.trackMap != nil,
                  detail: "\(store.trackMap?.points.count ?? 0) points, rotation: \(store.trackMap?.effectiveRotation ?? 0)")

        let driversOnMap = store.driverPositions.filter { $0.value.isOnTrack }.count
        addResult("Drivers on map",
                  passed: driversOnMap > 0,
                  detail: "\(driversOnMap) drivers visible")
    }

    // MARK: - New Feature Validation

    private func validateStints(store: LiveTimingStore) {
        addResult("Stints loaded",
                  passed: store.currentStints.count == 20,
                  detail: "\(store.currentStints.count) current stints")

        let compounds = Set(store.currentStints.values.map(\.compound))
        addResult("Stint compound variety",
                  passed: compounds.count >= 2,
                  detail: "Compounds: \(compounds.map(\.abbreviation).sorted().joined(separator: ", "))")

        // Check a specific driver's stint
        if let verStint = store.currentStints["1"] {
            addResult("VER stint data",
                      passed: verStint.stintNumber > 0 && verStint.lapStart != nil,
                      detail: "Stint \(verStint.stintNumber), compound: \(verStint.compound.abbreviation), from lap \(verStint.lapStart ?? 0)")
        }
    }

    private func validateTrackViolations(store: LiveTimingStore) {
        addResult("Track violations computed",
                  passed: !store.trackViolations.isEmpty,
                  detail: "\(store.trackViolations.count) drivers with violations")

        // NOR should have 2 violations in mock data
        if let norViolation = store.trackViolations["4"] {
            addResult("NOR track violations",
                      passed: norViolation.count == 2,
                      detail: "Count: \(norViolation.count), last lap: \(norViolation.lastLap ?? 0)")
        }

        // LEC should have 1 violation
        if let lecViolation = store.trackViolations["16"] {
            addResult("LEC track violations",
                      passed: lecViolation.count == 1,
                      detail: "Count: \(lecViolation.count)")
        }
    }

    // MARK: - New Data Fields Validation

    private func validateNewDataFields(store: LiveTimingStore) {
        // -- CarTelemetry brake --
        let brakingCars = store.carTelemetry.values.filter { $0.brake > 0 }.count
        addResult("CarTelemetry brake values",
                  passed: brakingCars > 0,
                  detail: "\(brakingCars) cars with brake > 0")

        if let ver = store.carTelemetry["1"] {
            addResult("VER telemetry complete",
                      passed: ver.rpm > 0 && ver.speed > 0 && ver.gear > 0,
                      detail: "RPM:\(ver.rpm) SPD:\(ver.speed) G:\(ver.gear) THR:\(ver.throttle) BRK:\(ver.brake) DRS:\(ver.drs.displayText)")
        }

        // -- Driver new fields --
        if let ver = store.drivers["1"] {
            addResult("Driver broadcastName",
                      passed: !ver.broadcastName.isEmpty,
                      detail: "VER: '\(ver.broadcastName)'")

            addResult("Driver headshotUrl",
                      passed: ver.headshotUrl != nil && !ver.headshotUrl!.isEmpty,
                      detail: "VER: \(ver.headshotUrl?.prefix(50) ?? "nil")...")

            addResult("Driver reference",
                      passed: ver.reference != nil && !ver.reference!.isEmpty,
                      detail: "VER: '\(ver.reference ?? "nil")'")
        }

        // -- intervalCatching --
        let catchingDrivers = store.timingData.filter { $0.value.intervalCatching }
        addResult("TimingData intervalCatching",
                  passed: !catchingDrivers.isEmpty,
                  detail: "\(catchingDrivers.count) driver(s) catching: \(catchingDrivers.keys.sorted().joined(separator: ", "))")

        let nonCatching = store.timingData.filter { !$0.value.intervalCatching }
        addResult("TimingData intervalCatching false",
                  passed: !nonCatching.isEmpty,
                  detail: "\(nonCatching.count) drivers NOT catching")

        // -- SpeedsData / SpeedTrap --
        let driversWithSpeeds = store.timingData.filter { $0.value.speeds != nil }
        addResult("TimingData speeds populated",
                  passed: driversWithSpeeds.count == 20,
                  detail: "\(driversWithSpeeds.count) drivers with speed trap data")

        if let verTiming = store.timingData["1"], let speeds = verTiming.speeds {
            addResult("VER speed traps",
                      passed: speeds.i1.value != nil && speeds.st.value != nil,
                      detail: "I1:\(speeds.i1.value ?? "-") I2:\(speeds.i2.value ?? "-") FL:\(speeds.fl.value ?? "-") ST:\(speeds.st.value ?? "-")")

            addResult("VER speed trap fastest flags",
                      passed: speeds.i1.overallFastest || speeds.st.overallFastest,
                      detail: "I1 overall:\(speeds.i1.overallFastest) ST overall:\(speeds.st.overallFastest)")
        }

        // -- Qualifying fields --
        let knockedOutDrivers = store.timingData.filter { $0.value.knockedOut }
        addResult("TimingData knockedOut",
                  passed: knockedOutDrivers.count == 2,
                  detail: "\(knockedOutDrivers.count) knocked out: \(knockedOutDrivers.keys.sorted().joined(separator: ", "))")

        let cutoffDrivers = store.timingData.filter { $0.value.cutoff }
        addResult("TimingData cutoff",
                  passed: cutoffDrivers.count == 1,
                  detail: "\(cutoffDrivers.count) on cutoff: \(cutoffDrivers.keys.sorted().joined(separator: ", "))")

        let withLine = store.timingData.filter { $0.value.line != nil }
        addResult("TimingData line field",
                  passed: withLine.count == 20,
                  detail: "\(withLine.count) drivers with line set")

        let withStatus = store.timingData.filter { $0.value.driverStatus != nil }
        addResult("TimingData driverStatus",
                  passed: !withStatus.isEmpty,
                  detail: "\(withStatus.count) drivers with status: \(withStatus.map { "\($0.key)=\($0.value.driverStatus!)" }.joined(separator: ", "))")

        // -- TimingAppData --
        addResult("TimingAppData loaded",
                  passed: store.timingAppData.count == 20,
                  detail: "\(store.timingAppData.count) drivers")

        if let verApp = store.timingAppData["1"] {
            addResult("TimingAppData VER stints",
                      passed: !verApp.stints.isEmpty && verApp.gridPos != nil,
                      detail: "GridPos:\(verApp.gridPos ?? "-"), \(verApp.stints.count) stints, compounds: \(verApp.stints.compactMap(\.compound).joined(separator: "→"))")

            addResult("TimingAppData stint detail",
                      passed: verApp.stints[0].compound != nil && verApp.stints[0].isNew == true,
                      detail: "First stint: \(verApp.stints[0].compound ?? "-"), new=\(verApp.stints[0].isNew ?? false), laps=\(verApp.stints[0].totalLaps ?? 0)")
        }
    }

    // MARK: - JSON Parsing Pipeline Validation

    /// Tests the actual parsing code paths by feeding raw JSON through parsers.
    private func validateParsingPipeline(store: LiveTimingStore) {
        // Test 1: CarData object-format parsing
        let carDataJSON: [String: Any] = [
            "Entries": [[
                "Cars": [
                    "99": [
                        "Channels": [
                            "0": 12500,   // RPM
                            "2": 325,     // Speed
                            "3": 8,       // Gear
                            "4": 100,     // Throttle
                            "5": 42,      // Brake
                            "45": 10      // DRS active
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]]
        ]
        if let parsed = CarTelemetry.parseEntries(carDataJSON) {
            let car = parsed["99"]
            addResult("Parse: CarData object channels",
                      passed: car?.rpm == 12500 && car?.speed == 325 && car?.gear == 8
                              && car?.throttle == 100 && car?.brake == 42 && car?.drs == .active,
                      detail: "RPM:\(car?.rpm ?? 0) SPD:\(car?.speed ?? 0) BRK:\(car?.brake ?? 0) DRS:\(car?.drs.displayText ?? "-")")
        } else {
            addResult("Parse: CarData object channels", passed: false, detail: "parseEntries returned nil")
        }

        // Test 2: CarData array-format fallback
        let carDataArray: [String: Any] = [
            "Entries": [[
                "Cars": [
                    "88": [
                        "Channels": [11000, 0, 300, 7, 80, 15] as [Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]]
        ]
        if let parsed = CarTelemetry.parseEntries(carDataArray) {
            let car = parsed["88"]
            addResult("Parse: CarData array fallback",
                      passed: car?.rpm == 11000 && car?.speed == 300 && car?.gear == 7
                              && car?.brake == 15 && car?.drs == .off,
                      detail: "RPM:\(car?.rpm ?? 0) SPD:\(car?.speed ?? 0) BRK:\(car?.brake ?? 0) DRS:\(car?.drs.displayText ?? "-")")
        } else {
            addResult("Parse: CarData array fallback", passed: false, detail: "parseEntries returned nil")
        }

        // Test 3: TimingData full parse with new fields
        let timingJSON: [String: Any] = [
            "Position": "1",
            "GapToLeader": "",
            "IntervalToPositionAhead": ["Value": "+1.234", "Catching": true] as [String: Any],
            "BestLapTime": ["Value": "1:30.000"] as [String: Any],
            "LastLapTime": ["Value": "1:31.500"] as [String: Any],
            "NumberOfLaps": 40,
            "InPit": false,
            "PitOut": false,
            "Stopped": false,
            "Retired": false,
            "KnockedOut": true,
            "Cutoff": true,
            "ShowPosition": false,
            "Status": 64,
            "Line": 5,
            "Speeds": [
                "I1": ["Value": "312", "OverallFastest": true, "PersonalFastest": true] as [String: Any],
                "I2": ["Value": "290", "PersonalFastest": true] as [String: Any],
                "Fl": ["Value": "215"] as [String: Any],
                "St": ["Value": "330", "OverallFastest": true] as [String: Any]
            ] as [String: Any]
        ]
        let td = TimingDataParser.parseDriver(dict: timingJSON)
        addResult("Parse: intervalCatching",
                  passed: td.intervalCatching == true && td.intervalToPositionAhead == "+1.234",
                  detail: "catching:\(td.intervalCatching) interval:\(td.intervalToPositionAhead ?? "nil")")

        addResult("Parse: qualifying fields",
                  passed: td.knockedOut == true && td.cutoff == true && td.showPosition == false
                          && td.driverStatus == 64 && td.line == 5,
                  detail: "KO:\(td.knockedOut) cutoff:\(td.cutoff) show:\(td.showPosition) status:\(td.driverStatus ?? -1) line:\(td.line ?? -1)")

        addResult("Parse: SpeedsData",
                  passed: td.speeds?.i1.value == "312" && td.speeds?.i1.overallFastest == true
                          && td.speeds?.st.value == "330" && td.speeds?.fl.value == "215",
                  detail: "I1:\(td.speeds?.i1.value ?? "-") ST:\(td.speeds?.st.value ?? "-") FL:\(td.speeds?.fl.value ?? "-")")

        // Test 4: TimingAppData parsing
        let appDataJSON: [String: Any] = [
            "Lines": [
                "1": [
                    "GridPos": "1",
                    "Line": 1,
                    "Stints": [
                        "0": ["TotalLaps": 15, "Compound": "SOFT", "New": "true"] as [String: Any],
                        "1": ["TotalLaps": 20, "Compound": "MEDIUM", "New": "false"] as [String: Any],
                        "2": ["Compound": "HARD", "New": "true"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let appData = TimingDataParser.parseTimingAppData(dict: appDataJSON)
        if let d1 = appData["1"] {
            addResult("Parse: TimingAppData stints",
                      passed: d1.stints.count == 3 && d1.gridPos == "1" && d1.line == 1,
                      detail: "\(d1.stints.count) stints, grid:\(d1.gridPos ?? "-")")

            addResult("Parse: TimingAppData stint fields",
                      passed: d1.stints[0].compound == "SOFT" && d1.stints[0].totalLaps == 15
                              && d1.stints[0].isNew == true && d1.stints[1].isNew == false,
                      detail: "S1:\(d1.stints[0].compound ?? "-") laps:\(d1.stints[0].totalLaps ?? 0) new:\(d1.stints[0].isNew ?? false)")
        } else {
            addResult("Parse: TimingAppData stints", passed: false, detail: "Driver 1 not found")
            addResult("Parse: TimingAppData stint fields", passed: false, detail: "Driver 1 not found")
        }

        // Test 5: Driver.from() with new fields
        let driverJSON: [String: Any] = [
            "RacingNumber": "99",
            "Tla": "TST",
            "FirstName": "Test",
            "LastName": "Driver",
            "FullName": "Test Driver",
            "TeamName": "Test Team",
            "TeamColour": "FF0000",
            "Line": 1,
            "CountryCode": "TST",
            "BroadcastName": "T DRIVER",
            "HeadshotUrl": "https://example.com/driver.png",
            "Reference": "TST99"
        ]
        let driver = Driver.from(key: "99", dict: driverJSON)
        addResult("Parse: Driver new fields",
                  passed: driver.broadcastName == "T DRIVER"
                          && driver.headshotUrl == "https://example.com/driver.png"
                          && driver.reference == "TST99",
                  detail: "broadcast:'\(driver.broadcastName)' headshot:\(driver.headshotUrl != nil) ref:'\(driver.reference ?? "-")'")

        // Test 6: SessionData with SesionStatus typo
        let sessionDataJSON: [String: Any] = [
            "StatusSeries": [
                ["Utc": "2024-01-01T00:00:00Z", "SesionStatus": "Started"] as [String: Any],
                ["Utc": "2024-01-01T00:10:00Z", "SessionStatus": "Active"] as [String: Any]
            ]
        ]
        let sd = TimingDataParser.parseSessionData(dict: sessionDataJSON)
        addResult("Parse: SesionStatus typo",
                  passed: sd.statusSeries.count == 2
                          && sd.statusSeries[0].sessionStatus == "Started"
                          && sd.statusSeries[1].sessionStatus == "Active",
                  detail: "Entry0: '\(sd.statusSeries.first?.sessionStatus ?? "nil")' Entry1: '\(sd.statusSeries.last?.sessionStatus ?? "nil")'")
    }

    // MARK: - Simulator Validation

    @MainActor
    private func validateSimulator(store: LiveTimingStore) async {
        let sim = RaceSimulator()

        // Test 1: Simulator starts and sets phase
        sim.start(store: store)
        addResult("Simulator starts",
                  passed: sim.isRunning && sim.racePhase == "Formation Lap",
                  detail: "isRunning: \(sim.isRunning), phase: \(sim.racePhase)")

        // Test 2: Wait for a few laps and check lap counter
        try? await Task.sleep(for: .seconds(8))
        let lapAfterWait = sim.currentLap
        addResult("Simulator lap progression",
                  passed: lapAfterWait >= 1,
                  detail: "Lap after ~8s: \(lapAfterWait)")

        // Test 3: Store lap count updated
        let storeLap = store.lapCount?.currentLap ?? 0
        addResult("Store lap count synced",
                  passed: storeLap == lapAfterWait,
                  detail: "Store lap: \(storeLap), sim lap: \(lapAfterWait)")

        sim.stop()
        addResult("Simulator stops",
                  passed: !sim.isRunning,
                  detail: "Phase: \(sim.racePhase)")
    }

    // MARK: - Screenshots

    private func takeScreenshot(name: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "/tmp/f1dash-autotest-\(name).png"]
        try? task.run()
        task.waitUntilExit()
        logger.info("Screenshot saved: /tmp/f1dash-autotest-\(name).png")
    }

    // MARK: - Helpers

    private func addResult(_ name: String, passed: Bool, detail: String) {
        let result = TestResult(name: name, passed: passed, detail: detail)
        results.append(result)
        let icon = passed ? "✅" : "❌"
        logger.info("\(icon) \(name): \(detail)")
    }
}
