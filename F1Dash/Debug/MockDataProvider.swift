import Foundation

/// Provides realistic mock F1 data for all views.
/// Activate via menu: Debug → Load Demo Data, or launch argument --demo
enum MockDataProvider {

    // MARK: - 2024 Grid

    static let drivers: [String: Driver] = {
        let grid: [(num: String, tla: String, first: String, last: String, team: String, color: String, line: Int)] = [
            ("1",  "VER", "Max",      "Verstappen",   "Red Bull Racing",        "3671C6", 1),
            ("11", "PER", "Sergio",   "Perez",        "Red Bull Racing",        "3671C6", 2),
            ("44", "HAM", "Lewis",    "Hamilton",     "Ferrari",                 "E80020", 3),
            ("16", "LEC", "Charles",  "Leclerc",      "Ferrari",                 "E80020", 4),
            ("4",  "NOR", "Lando",    "Norris",       "McLaren",                 "FF8000", 5),
            ("81", "PIA", "Oscar",    "Piastri",      "McLaren",                 "FF8000", 6),
            ("63", "RUS", "George",   "Russell",      "Mercedes",                "27F4D2", 7),
            ("12", "ANT", "Kimi",     "Antonelli",    "Mercedes",                "27F4D2", 8),
            ("14", "ALO", "Fernando", "Alonso",       "Aston Martin",            "229971", 9),
            ("18", "STR", "Lance",    "Stroll",       "Aston Martin",            "229971", 10),
            ("10", "GAS", "Pierre",   "Gasly",        "Alpine",                  "FF87BC", 11),
            ("7",  "DOO", "Jack",     "Doohan",       "Alpine",                  "FF87BC", 12),
            ("22", "TSU", "Yuki",     "Tsunoda",      "RB",                      "6692FF", 13),
            ("30", "LAW", "Liam",     "Lawson",       "RB",                      "6692FF", 14),
            ("23", "ALB", "Alex",     "Albon",        "Williams",                "64C4FF", 15),
            ("55", "SAI", "Carlos",   "Sainz",        "Williams",                "64C4FF", 16),
            ("27", "HUL", "Nico",     "Hulkenberg",   "Sauber",                  "52E252", 17),
            ("87", "BOR", "Gabriel",  "Bortoleto",    "Sauber",                  "52E252", 18),
            ("31", "OCO", "Esteban",  "Ocon",         "Haas F1 Team",            "B6BABD", 19),
            ("50", "BEA", "Oliver",   "Bearman",      "Haas F1 Team",            "B6BABD", 20),
        ]
        var result: [String: Driver] = [:]
        for d in grid {
            result[d.num] = Driver(
                id: d.num, racingNumber: d.num, tla: d.tla,
                firstName: d.first, lastName: d.last, fullName: "\(d.first) \(d.last)",
                teamName: d.team, teamColour: d.color, line: d.line, countryCode: "",
                broadcastName: "\(d.first.prefix(1)) \(d.last.uppercased())",
                headshotUrl: "https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/\(d.tla).png",
                reference: "\(d.tla)\(d.num)"
            )
        }
        return result
    }()

    // MARK: - Session Info (Bahrain GP Race)

    static let sessionInfo = SessionInfo(
        meetingName: "Bahrain Grand Prix",
        meetingOfficialName: "FORMULA 1 GULF AIR BAHRAIN GRAND PRIX 2026",
        meetingCountryName: "Bahrain",
        meetingCircuitShortName: "Sakhir",
        meetingCircuitKey: 63,
        sessionName: "Race",
        sessionType: "Race",
        sessionPath: "2026/2026-03-02_Bahrain_Grand_Prix/2026-03-02_Race/",
        gmtOffset: "03:00:00",
        startDate: Date(),
        endDate: Date().addingTimeInterval(7200),
        year: 2026
    )

    // MARK: - Race Control Messages

    static let raceControlMessages: [RaceControlMessage] = {
        let now = Date()
        return [
            RaceControlMessage(utc: now.addingTimeInterval(-3600), category: .flag, message: "GREEN LIGHT - PIT EXIT OPEN", flag: .green, scope: .track, sector: nil, lap: nil, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-3500), category: .other, message: "DRS ENABLED", flag: nil, scope: .track, sector: nil, lap: 3, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-3000), category: .flag, message: "YELLOW FLAG IN SECTOR 2", flag: .yellow, scope: .sector, sector: 2, lap: 8, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-2900), category: .flag, message: "GREEN FLAG IN SECTOR 2", flag: .green, scope: .sector, sector: 2, lap: 8, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-2500), category: .flag, message: "BLUE FLAG - CAR 18 (STR)", flag: .blue, scope: .driver, sector: nil, lap: 12, racingNumber: "18"),
            RaceControlMessage(utc: now.addingTimeInterval(-2400), category: .flag, message: "BLUE FLAG - CAR 18 (STR)", flag: .blue, scope: .driver, sector: nil, lap: 12, racingNumber: "18"),
            RaceControlMessage(utc: now.addingTimeInterval(-2000), category: .flag, message: "TRACK LIMITS - CAR 4 (NOR) - LAP 15 TURN 4 - TRACK LIMITS EXCEEDED", flag: .blackAndWhite, scope: .driver, sector: nil, lap: 15, racingNumber: "4"),
            RaceControlMessage(utc: now.addingTimeInterval(-1800), category: .flag, message: "TRACK LIMITS - CAR 16 (LEC) - LAP 18 TURN 10 - TRACK LIMITS EXCEEDED", flag: .blackAndWhite, scope: .driver, sector: nil, lap: 18, racingNumber: "16"),
            RaceControlMessage(utc: now.addingTimeInterval(-1600), category: .flag, message: "TRACK LIMITS - CAR 4 (NOR) - LAP 20 TURN 4 - TRACK LIMITS EXCEEDED", flag: .blackAndWhite, scope: .driver, sector: nil, lap: 20, racingNumber: "4"),
            RaceControlMessage(utc: now.addingTimeInterval(-1500), category: .safetycar, message: "SAFETY CAR DEPLOYED", flag: .yellow, scope: .track, sector: nil, lap: 20, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-1200), category: .flag, message: "DOUBLE YELLOW FLAG IN SECTOR 1", flag: .doubleYellow, scope: .sector, sector: 1, lap: 20, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-1000), category: .other, message: "DRS DISABLED", flag: nil, scope: .track, sector: nil, lap: 20, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-800), category: .safetycar, message: "SAFETY CAR IN THIS LAP", flag: .yellow, scope: .track, sector: nil, lap: 23, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-600), category: .flag, message: "GREEN FLAG - SAFETY CAR ENDING", flag: .green, scope: .track, sector: nil, lap: 24, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-400), category: .other, message: "DRS ENABLED", flag: nil, scope: .track, sector: nil, lap: 26, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-200), category: .flag, message: "VIRTUAL SAFETY CAR DEPLOYED", flag: .yellow, scope: .track, sector: nil, lap: 35, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-100), category: .flag, message: "VSC ENDING", flag: .green, scope: .track, sector: nil, lap: 37, racingNumber: nil),
            RaceControlMessage(utc: now.addingTimeInterval(-30), category: .flag, message: "BLACK AND ORANGE FLAG - CAR 31 (OCO) - FRONT WING DAMAGE", flag: .black, scope: .driver, sector: nil, lap: 42, racingNumber: "31"),
        ]
    }()

    // MARK: - Team Radio

    static let teamRadioCaptures: [RadioCapture] = {
        let now = Date()
        let nums = ["1", "44", "4", "16", "63", "81", "14", "11", "10", "22"]
        return nums.enumerated().map { i, num in
            RadioCapture(
                utc: now.addingTimeInterval(Double(-600 + i * 60)),
                racingNumber: num,
                path: "TeamRadio/driver\(num)_lap\(30 + i).m4a"
            )
        }
    }()

    // MARK: - Timing Data

    static let timingData: [String: TimingDataDriver] = {
        let driverOrder = ["1", "4", "16", "44", "81", "63", "14", "12", "11", "18",
                           "10", "7", "22", "30", "23", "55", "27", "87", "31", "50"]
        let gaps = ["", "+2.341", "+5.672", "+8.123", "+12.456", "+15.789", "+18.234",
                    "+22.567", "+25.890", "+30.123", "+33.456", "+38.789", "+42.012",
                    "+45.345", "+50.678", "+55.901", "+62.234", "+68.567", "+75.890", "+1 LAP"]
        let intervals = ["", "+2.341", "+3.331", "+2.451", "+4.333", "+3.333", "+2.445",
                          "+4.333", "+3.323", "+4.233", "+3.333", "+5.333", "+3.223",
                          "+3.333", "+5.333", "+5.223", "+6.333", "+6.333", "+7.323", "+1 LAP"]
        let bestLaps = ["1:31.234", "1:31.456", "1:31.678", "1:31.890", "1:32.012",
                        "1:32.234", "1:32.456", "1:32.678", "1:32.890", "1:33.012",
                        "1:33.234", "1:33.456", "1:33.678", "1:33.890", "1:34.012",
                        "1:34.234", "1:34.456", "1:34.678", "1:34.890", "1:35.012"]
        let lastLaps = ["1:32.456", "1:32.123", "1:32.890", "1:33.012", "1:32.567",
                        "1:33.345", "1:33.678", "1:33.901", "1:34.123", "1:33.456",
                        "1:34.567", "1:34.789", "1:34.901", "1:35.123", "1:35.345",
                        "1:35.567", "1:35.789", "1:35.901", "1:36.123", "1:36.345"]

        var result: [String: TimingDataDriver] = [:]
        for (i, num) in driverOrder.enumerated() {
            let segmentStatuses: [[SegmentStatus]] = (0..<3).map { sector in
                (0..<8).map { seg in
                    if sector < 2 || (sector == 2 && seg < 5) {
                        // Completed segments — random status
                        let options: [SegmentStatus] = [.amber, .amberCompleted, .green, .purple]
                        return options[(i + sector + seg) % options.count]
                    } else {
                        return .none
                    }
                }
            }

            // Speed trap data for each driver
            let speedI1 = "\(295 + (20 - i) * 2)"
            let speedI2 = "\(275 + (20 - i))"
            let speedFl = "\(200 + (20 - i))"
            let speedSt = "\(310 + (20 - i) * 2)"
            let speeds = TimingDataDriver.SpeedsData(
                i1: TimingDataDriver.SpeedTrap(value: speedI1, overallFastest: i == 0, personalFastest: i < 3),
                i2: TimingDataDriver.SpeedTrap(value: speedI2, overallFastest: i == 1, personalFastest: i < 5),
                fl: TimingDataDriver.SpeedTrap(value: speedFl, overallFastest: i == 2, personalFastest: i < 4),
                st: TimingDataDriver.SpeedTrap(value: speedSt, overallFastest: i == 0, personalFastest: i < 3)
            )

            result[num] = TimingDataDriver(
                position: "\(i + 1)",
                gapToLeader: gaps[i],
                intervalToPositionAhead: intervals[i],
                intervalCatching: i == 1 || i == 4,  // NOR (P2) and PIA (P5) are catching
                bestLapTime: bestLaps[i],
                lastLapTime: lastLaps[i],
                numberOfLaps: 45 - (i > 18 ? 1 : 0),
                sectors: segmentStatuses.enumerated().map { sectorIdx, segments in
                    TimingDataDriver.SectorTiming(
                        value: "3\(sectorIdx + 1).\(100 + i * 10 + sectorIdx * 3)",
                        personalFastest: i == 0 && sectorIdx == 1,
                        overallFastest: i == 0 && sectorIdx == 0,
                        segments: segments
                    )
                },
                segments: segmentStatuses,
                inPit: num == "31",
                pitOut: false,
                stopped: false,
                retired: false,
                speeds: speeds,
                knockedOut: i >= 18,   // Last 2 drivers "knocked out" (simulates Q1 elimination)
                cutoff: i == 14,       // P15 is on the cutoff line
                showPosition: true,
                driverStatus: num == "31" ? 64 : nil,  // OCO has special status (in pit)
                line: i + 1
            )
        }
        return result
    }()

    // MARK: - Car Telemetry

    static let carTelemetry: [String: CarTelemetry] = {
        let driverOrder = ["1", "4", "16", "44", "81", "63", "14", "12", "11", "18",
                           "10", "7", "22", "30", "23", "55", "27", "87", "31", "50"]
        var result: [String: CarTelemetry] = [:]
        for (i, num) in driverOrder.enumerated() {
            result[num] = CarTelemetry(
                rpm: 10500 + (i % 5) * 200,
                speed: 310 - i * 3,
                gear: i < 3 ? 8 : (i < 10 ? 7 : 6),
                throttle: i < 5 ? 100 : 95,
                brake: i >= 10 ? (i * 5) : 0,  // Trailing drivers braking
                drs: i < 3 ? .active : (i < 8 ? .eligible : .off)
            )
        }
        return result
    }()

    // MARK: - Driver Positions (Bahrain circuit approximate coordinates)

    static let driverPositions: [String: DriverPosition] = {
        let driverOrder = ["1", "4", "16", "44", "81", "63", "14", "12", "11", "18",
                           "10", "7", "22", "30", "23", "55", "27", "87", "31", "50"]
        // Bahrain circuit approximate track coordinates
        // Distribute drivers along the track
        let trackLength = 300  // arbitrary units
        var result: [String: DriverPosition] = [:]
        for (i, num) in driverOrder.enumerated() {
            let angle = Double(i) / Double(driverOrder.count) * 2.0 * .pi
            let radius = 4000.0
            let cx = 1000.0
            let cy = 1000.0
            result[num] = DriverPosition(
                x: cx + radius * cos(angle),
                y: cy + radius * sin(angle),
                z: 0,
                status: num == "31" ? "OffTrack" : "OnTrack"
            )
        }
        return result
    }()

    // MARK: - Weather

    static let weather = WeatherData(
        airTemp: 28.5,
        trackTemp: 42.3,
        humidity: 45.0,
        pressure: 1013.2,
        windSpeed: 3.4,
        windDirection: 220.0,
        rainfall: false
    )

    // MARK: - Track Status

    static let trackStatus = TrackStatus(
        status: .allClear,
        message: "AllClear"
    )

    // MARK: - Clock & Laps

    static let extrapolatedClock = ExtrapolatedClock(
        utc: Date(),
        remaining: "00:23:45",
        extrapolating: true
    )

    static let lapCount = LapCount(
        currentLap: 45,
        totalLaps: 57
    )

    // MARK: - Track Map (simplified Bahrain-like circuit)

    static let trackMap: TrackMap = {
        // Generate a Bahrain-like track shape
        var xs: [Double] = []
        var ys: [Double] = []

        let points = 200
        for i in 0..<points {
            let t = Double(i) / Double(points) * 2.0 * .pi

            // Bahrain-inspired shape: long straight + technical section
            let baseX = 4000.0 * cos(t)
            let baseY = 2500.0 * sin(t)

            // Add some perturbation for a more realistic shape
            let pertX = 500.0 * cos(3.0 * t) + 300.0 * sin(5.0 * t)
            let pertY = 400.0 * sin(2.0 * t) + 200.0 * cos(4.0 * t)

            xs.append(baseX + pertX + 5000.0)
            ys.append(baseY + pertY + 3000.0)
        }

        return TrackMap(
            x: xs, y: ys, rotation: -10,
            marshalLights: nil, marshalSectors: nil
        )
    }()

    // MARK: - Mock Stints (varied compounds per driver)

    static let stints: [String: StintData] = {
        let driverOrder = ["1", "4", "16", "44", "81", "63", "14", "12", "11", "18",
                           "10", "7", "22", "30", "23", "55", "27", "87", "31", "50"]
        let compounds: [TireCompound] = [.medium, .hard, .soft, .hard, .medium, .soft,
                                          .hard, .medium, .hard, .soft,
                                          .medium, .hard, .soft, .medium, .hard,
                                          .soft, .medium, .hard, .medium, .soft]
        let stintNumbers = [3, 3, 2, 3, 2, 2, 3, 2, 3, 2, 2, 3, 2, 2, 3, 2, 2, 3, 2, 2]
        let lapStarts   = [32, 30, 25, 28, 26, 24, 31, 27, 29, 23, 25, 30, 24, 26, 28, 22, 25, 29, 20, 23]

        var result: [String: StintData] = [:]
        for (i, num) in driverOrder.enumerated() {
            result[num] = StintData(
                driverNumber: Int(num)!,
                stintNumber: stintNumbers[i],
                compound: compounds[i],
                tyreAgeAtStart: 0,
                lapStart: lapStarts[i],
                lapEnd: nil
            )
        }
        return result
    }()

    // MARK: - TimingAppData (stint history per driver)

    static let timingAppData: [String: TimingAppDriverData] = {
        let driverOrder = ["1", "4", "16", "44", "81", "63", "14", "12", "11", "18",
                           "10", "7", "22", "30", "23", "55", "27", "87", "31", "50"]
        let compoundSets: [[String]] = [
            ["SOFT", "MEDIUM", "HARD"],  // 3-stop strategy
            ["SOFT", "HARD"],            // 2-stop strategy
            ["MEDIUM", "HARD", "MEDIUM"] // 3-stop alt
        ]

        var result: [String: TimingAppDriverData] = [:]
        for (i, num) in driverOrder.enumerated() {
            let compounds = compoundSets[i % compoundSets.count]
            var stints: [TimingAppDriverData.StintInfo] = []
            for (j, compound) in compounds.enumerated() {
                stints.append(TimingAppDriverData.StintInfo(
                    totalLaps: j == compounds.count - 1 ? nil : (10 + j * 5),
                    compound: compound,
                    isNew: j == 0
                ))
            }
            result[num] = TimingAppDriverData(
                stints: stints,
                gridPos: "\(i + 1)",
                line: i + 1
            )
        }
        return result
    }()

    // MARK: - Load Race Start (for simulator)

    /// Loads grid setup for formation lap: drivers, session, track, weather.
    /// Dynamic data (timing, positions, RC messages) left for RaceSimulator.
    static func loadRaceStart(_ store: LiveTimingStore) {
        store.drivers = drivers
        store.sessionInfo = sessionInfo
        store.trackMap = trackMap
        store.weatherData = weather
        store.sessionStatus = .started
    }

    // MARK: - Load into Store

    static func loadIntoStore(_ store: LiveTimingStore) {
        store.drivers = drivers
        store.sessionInfo = sessionInfo
        store.raceControlMessages = raceControlMessages
        store.teamRadioCaptures = teamRadioCaptures
        store.timingData = timingData
        store.carTelemetry = carTelemetry
        store.driverPositions = driverPositions
        store.weatherData = weather
        store.trackStatus = trackStatus
        store.extrapolatedClock = extrapolatedClock
        store.lapCount = lapCount
        store.trackMap = trackMap
        store.sessionStatus = .started
        store.currentStints = stints
        store.timingAppData = timingAppData
        store.computeTrackViolations()
    }
}
