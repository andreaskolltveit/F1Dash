import Foundation
import os

/// Simulates a full F1 race from lights out to chequered flag.
/// Bahrain GP, 57 laps, compressed to ~5 minutes (~5s per lap).
@Observable
@MainActor
final class RaceSimulator {
    private let logger = Logger(subsystem: "com.f1dash", category: "Simulator")

    // MARK: - Public State

    var isRunning = false
    var currentLap = 0
    var racePhase = "Not Started"

    // MARK: - Configuration

    private let totalLaps = 57
    private let secondsPerLap: Double = 5.0

    // MARK: - Internal State

    private var store: LiveTimingStore?
    private var simulationTask: Task<Void, Never>?
    private var racePositions: [String] = []           // ordered by race position
    private var accumulatedTime: [String: Double] = [:] // total race time per driver
    private var currentCompound: [String: TireCompound] = [:]
    private var stintStartLap: [String: Int] = [:]
    private var stintNumber: [String: Int] = [:]
    private var retiredDrivers: Set<String> = []
    private var lastLapPitDrivers: Set<String> = []
    private var bestLapTimes: [String: Double] = [:]
    private var overallBestLap: Double = .infinity
    private var overallBestLapDriver: String = ""
    private var overallBestSectors: [Double] = [.infinity, .infinity, .infinity]
    private var drsEnabled = false

    // Base pace in seconds. Top ~91s (1:31), mid ~93s, back ~94s.
    private let baseLapTimes: [String: Double] = [
        "1": 91.2, "4": 91.3, "16": 91.5, "44": 91.8, "81": 91.7,
        "63": 91.9, "14": 92.5, "12": 92.3, "11": 92.1, "18": 93.0,
        "10": 92.8, "7": 93.2, "22": 92.6, "30": 92.9, "23": 93.5,
        "55": 93.3, "27": 93.8, "87": 94.0, "31": 93.6, "50": 93.9,
    ]

    private let startingCompounds: [String: TireCompound] = [
        "1": .medium, "4": .medium, "16": .soft, "44": .soft,
        "81": .medium, "63": .soft, "14": .hard, "12": .soft,
        "11": .medium, "18": .hard, "10": .medium, "7": .medium,
        "22": .soft, "30": .soft, "23": .hard, "55": .hard,
        "27": .medium, "87": .medium, "31": .soft, "50": .soft,
    ]

    // MARK: - Scripted Events

    enum RaceEvent {
        case pitStop(driver: String, newCompound: TireCompound)
        case overtake(driver: String, passedDriver: String)
        case raceControl(
            category: RaceControlMessage.Category, message: String,
            flag: RaceControlMessage.Flag?, scope: RaceControlMessage.Scope,
            sector: Int?, racingNumber: String?
        )
        case trackStatus(TrackStatus.TrackStatusCode, message: String)
        case teamRadio(driver: String)
        case retirement(driver: String)
        case drsChange(enabled: Bool)
    }

    // swiftlint:disable function_body_length
    private var scriptedEvents: [Int: [RaceEvent]] {
        [
            3: [
                .drsChange(enabled: true),
                .raceControl(category: .drs, message: "DRS ENABLED", flag: nil, scope: .track, sector: nil, racingNumber: nil),
            ],
            5: [
                .raceControl(category: .flag, message: "TRACK LIMITS - CAR 4 (NOR) - LAP 5 TURN 4 - TRACK LIMITS EXCEEDED", flag: .blackAndWhite, scope: .driver, sector: nil, racingNumber: "4"),
                .teamRadio(driver: "4"),
            ],
            8: [
                .raceControl(category: .flag, message: "YELLOW FLAG IN SECTOR 2", flag: .yellow, scope: .sector, sector: 2, racingNumber: nil),
                .raceControl(category: .flag, message: "GREEN FLAG IN SECTOR 2", flag: .green, scope: .sector, sector: 2, racingNumber: nil),
            ],
            12: [
                .pitStop(driver: "50", newCompound: .hard),
                .pitStop(driver: "87", newCompound: .hard),
            ],
            13: [
                .pitStop(driver: "31", newCompound: .medium),
                .pitStop(driver: "27", newCompound: .hard),
            ],
            14: [
                .pitStop(driver: "55", newCompound: .medium),
                .pitStop(driver: "23", newCompound: .medium),
            ],
            15: [
                .raceControl(category: .flag, message: "TRACK LIMITS - CAR 16 (LEC) - LAP 15 TURN 10 - TRACK LIMITS EXCEEDED", flag: .blackAndWhite, scope: .driver, sector: nil, racingNumber: "16"),
                .pitStop(driver: "30", newCompound: .hard),
            ],
            18: [
                .pitStop(driver: "22", newCompound: .hard),
                .pitStop(driver: "7", newCompound: .hard),
            ],
            19: [
                .pitStop(driver: "10", newCompound: .medium),
                .pitStop(driver: "18", newCompound: .medium),
            ],
            20: [
                .raceControl(category: .flag, message: "TRACK LIMITS - CAR 4 (NOR) - LAP 20 TURN 4 - TRACK LIMITS EXCEEDED", flag: .blackAndWhite, scope: .driver, sector: nil, racingNumber: "4"),
                .pitStop(driver: "14", newCompound: .medium),
                .pitStop(driver: "12", newCompound: .medium),
                .teamRadio(driver: "14"),
            ],
            21: [
                .overtake(driver: "22", passedDriver: "30"),
            ],
            25: [
                .pitStop(driver: "81", newCompound: .hard),
                .pitStop(driver: "63", newCompound: .hard),
                .teamRadio(driver: "63"),
            ],
            26: [
                .pitStop(driver: "4", newCompound: .hard),
                .pitStop(driver: "44", newCompound: .hard),
            ],
            27: [
                .pitStop(driver: "16", newCompound: .hard),
                .pitStop(driver: "11", newCompound: .hard),
                .teamRadio(driver: "16"),
            ],
            28: [
                .pitStop(driver: "1", newCompound: .hard),
                .overtake(driver: "4", passedDriver: "16"),
            ],
            30: [
                .raceControl(category: .flag, message: "VIRTUAL SAFETY CAR DEPLOYED", flag: .yellow, scope: .track, sector: nil, racingNumber: nil),
                .trackStatus(.vscDeployed, message: "VSC Deployed"),
                .drsChange(enabled: false),
                .raceControl(category: .drs, message: "DRS DISABLED", flag: nil, scope: .track, sector: nil, racingNumber: nil),
                .raceControl(category: .flag, message: "BLACK AND ORANGE FLAG - CAR 31 (OCO) - FRONT WING DAMAGE", flag: .black, scope: .driver, sector: nil, racingNumber: "31"),
                .teamRadio(driver: "31"),
            ],
            32: [
                .trackStatus(.vscEnding, message: "VSC Ending"),
                .raceControl(category: .flag, message: "VSC ENDING", flag: .green, scope: .track, sector: nil, racingNumber: nil),
            ],
            33: [
                .trackStatus(.allClear, message: "AllClear"),
                .drsChange(enabled: true),
                .raceControl(category: .drs, message: "DRS ENABLED", flag: nil, scope: .track, sector: nil, racingNumber: nil),
            ],
            35: [
                .pitStop(driver: "50", newCompound: .medium),
                .pitStop(driver: "87", newCompound: .medium),
                .pitStop(driver: "31", newCompound: .hard),
            ],
            36: [
                .pitStop(driver: "27", newCompound: .medium),
                .pitStop(driver: "55", newCompound: .hard),
            ],
            37: [
                .pitStop(driver: "23", newCompound: .soft),
                .pitStop(driver: "30", newCompound: .medium),
                .overtake(driver: "63", passedDriver: "81"),
            ],
            38: [
                .pitStop(driver: "22", newCompound: .medium),
                .pitStop(driver: "10", newCompound: .soft),
                .teamRadio(driver: "1"),
            ],
            39: [
                .pitStop(driver: "14", newCompound: .soft),
                .pitStop(driver: "12", newCompound: .soft),
            ],
            40: [
                .pitStop(driver: "18", newCompound: .soft),
                .pitStop(driver: "7", newCompound: .medium),
            ],
            42: [
                .raceControl(category: .safetycar, message: "SAFETY CAR DEPLOYED", flag: .yellow, scope: .track, sector: nil, racingNumber: nil),
                .trackStatus(.safetyCar, message: "Safety Car"),
                .drsChange(enabled: false),
                .raceControl(category: .drs, message: "DRS DISABLED", flag: nil, scope: .track, sector: nil, racingNumber: nil),
                .teamRadio(driver: "44"),
            ],
            43: [
                .pitStop(driver: "1", newCompound: .soft),
                .pitStop(driver: "4", newCompound: .soft),
                .pitStop(driver: "16", newCompound: .soft),
                .pitStop(driver: "44", newCompound: .soft),
                .pitStop(driver: "81", newCompound: .soft),
                .pitStop(driver: "63", newCompound: .soft),
                .raceControl(category: .safetycar, message: "SAFETY CAR IN THIS LAP", flag: .yellow, scope: .track, sector: nil, racingNumber: nil),
            ],
            44: [
                .raceControl(category: .flag, message: "GREEN FLAG - SAFETY CAR ENDING", flag: .green, scope: .track, sector: nil, racingNumber: nil),
                .trackStatus(.allClear, message: "AllClear"),
            ],
            45: [
                .drsChange(enabled: true),
                .raceControl(category: .drs, message: "DRS ENABLED", flag: nil, scope: .track, sector: nil, racingNumber: nil),
                .overtake(driver: "4", passedDriver: "44"),
                .teamRadio(driver: "4"),
            ],
            50: [
                .retirement(driver: "87"),
                .raceControl(category: .other, message: "CAR 87 (BOR) STOPPED ON TRACK", flag: nil, scope: .driver, sector: nil, racingNumber: "87"),
                .raceControl(category: .flag, message: "YELLOW FLAG IN SECTOR 1", flag: .yellow, scope: .sector, sector: 1, racingNumber: nil),
                .raceControl(category: .flag, message: "GREEN FLAG IN SECTOR 1", flag: .green, scope: .sector, sector: 1, racingNumber: nil),
            ],
            55: [
                .overtake(driver: "16", passedDriver: "4"),
                .teamRadio(driver: "16"),
                .teamRadio(driver: "4"),
            ],
            57: [
                .raceControl(category: .flag, message: "CHEQUERED FLAG", flag: .chequered, scope: .track, sector: nil, racingNumber: nil),
            ],
        ]
    }
    // swiftlint:enable function_body_length

    // MARK: - Public API

    func start(store: LiveTimingStore) {
        guard !isRunning else { return }
        self.store = store
        isRunning = true
        currentLap = 0
        racePhase = "Formation Lap"

        // Reset state
        retiredDrivers = []
        lastLapPitDrivers = []
        drsEnabled = false
        bestLapTimes = [:]
        overallBestLap = .infinity
        overallBestLapDriver = ""
        overallBestSectors = [.infinity, .infinity, .infinity]

        // Grid order from driver line property
        let sorted = store.driversSorted
        racePositions = sorted.map(\.racingNumber)

        for num in racePositions {
            accumulatedTime[num] = 0
            currentCompound[num] = startingCompounds[num] ?? .medium
            stintStartLap[num] = 1
            stintNumber[num] = 1
        }

        simulationTask = Task {
            await self.runSimulation()
        }
    }

    func stop() {
        simulationTask?.cancel()
        simulationTask = nil
        isRunning = false
        racePhase = "Stopped"
    }

    // MARK: - Simulation Loop

    private func runSimulation() async {
        guard let store else { return }
        logger.info("Race simulation starting")

        // Formation lap
        setupFormationLap(store)
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }

        // Lights out
        racePhase = "Race"
        store.sessionStatus = .started
        appendRaceControl(store, category: .flag, message: "LIGHTS OUT AND AWAY WE GO!",
                          flag: .green, scope: .track)

        for lap in 1...totalLaps {
            guard !Task.isCancelled else { return }
            currentLap = lap
            logger.info("Lap \(lap)/\(self.totalLaps)")

            simulateLap(lap, store: store)

            if lap == totalLaps {
                racePhase = "Finished"
                store.sessionStatus = .finished
            }

            try? await Task.sleep(for: .seconds(secondsPerLap))
        }

        isRunning = false
        logger.info("Race simulation complete")
    }

    // MARK: - Per-Lap Simulation

    private func simulateLap(_ lap: Int, store: LiveTimingStore) {
        // 1. Process scripted events, collect pit-stop drivers
        var pitDrivers: Set<String> = []
        if let events = scriptedEvents[lap] {
            for event in events {
                processEvent(event, lap: lap, store: store, pitDrivers: &pitDrivers)
            }
        }

        // 2. Generate lap times and accumulate
        var lapTimes: [String: Double] = [:]
        for num in racePositions where !retiredDrivers.contains(num) {
            let lapTime = generateLapTime(
                driverNum: num, lap: lap,
                isPitting: pitDrivers.contains(num),
                trackStatus: store.trackStatus.status
            )
            lapTimes[num] = lapTime
            accumulatedTime[num, default: 0] += lapTime

            // Track best laps
            if !pitDrivers.contains(num)
                && store.trackStatus.status == .allClear {
                if lapTime < (bestLapTimes[num] ?? .infinity) {
                    bestLapTimes[num] = lapTime
                }
                if lapTime < overallBestLap {
                    overallBestLap = lapTime
                    overallBestLapDriver = num
                }
            }
        }

        // 3. Sort positions by accumulated time
        let active = racePositions.filter { !retiredDrivers.contains($0) }
        let sorted = active.sorted { (accumulatedTime[$0] ?? 0) < (accumulatedTime[$1] ?? 0) }
        let retired = racePositions.filter { retiredDrivers.contains($0) }
        racePositions = sorted + retired

        // 4. Update lap count & clock
        store.lapCount = LapCount(currentLap: lap, totalLaps: totalLaps)

        let avgLapSec = 93.0
        let remainingSec = max(0, Double(totalLaps - lap) * avgLapSec)
        let h = Int(remainingSec) / 3600
        let m = (Int(remainingSec) % 3600) / 60
        let s = Int(remainingSec) % 60
        store.extrapolatedClock = ExtrapolatedClock(
            utc: Date(),
            remaining: String(format: "%02d:%02d:%02d", h, m, s),
            extrapolating: true
        )

        // 5. Update timing data per driver
        let leaderTime = accumulatedTime[racePositions.first ?? ""] ?? 0
        for (posIdx, num) in racePositions.enumerated() {
            guard !retiredDrivers.contains(num) else {
                // Keep retired state
                if var td = store.timingData[num] {
                    td.retired = true
                    td.stopped = true
                    store.timingData[num] = td
                }
                continue
            }

            let lapTime = lapTimes[num] ?? 93.0
            let myTime = accumulatedTime[num] ?? 0

            // Gap to leader
            let gapStr: String
            if posIdx == 0 {
                gapStr = ""
            } else {
                let gap = myTime - leaderTime
                gapStr = "+\(String(format: "%.3f", gap))"
            }

            // Interval to car ahead
            let intervalStr: String
            if posIdx == 0 {
                intervalStr = ""
            } else {
                let aheadNum = racePositions[posIdx - 1]
                let aheadTime = accumulatedTime[aheadNum] ?? 0
                let diff = myTime - aheadTime
                intervalStr = "+\(String(format: "%.3f", diff))"
            }

            let sectors = generateSectors(lapTime: lapTime, driverNum: num)

            let isPitting = pitDrivers.contains(num)
            let isPitOut = lastLapPitDrivers.contains(num)

            store.timingData[num] = TimingDataDriver(
                position: "\(posIdx + 1)",
                gapToLeader: gapStr,
                intervalToPositionAhead: intervalStr,
                bestLapTime: formatLapTime(bestLapTimes[num] ?? lapTime),
                lastLapTime: formatLapTime(lapTime),
                numberOfLaps: lap,
                sectors: sectors,
                segments: sectors.map(\.segments),
                inPit: isPitting,
                pitOut: isPitOut && !isPitting,
                stopped: false,
                retired: false
            )

            // Update leaderboard line
            if var driver = store.drivers[num] {
                driver.line = posIdx + 1
                store.drivers[num] = driver
            }
        }

        // 6. Remember pit drivers for pit-out next lap
        lastLapPitDrivers = pitDrivers

        // 7. Track positions
        updateTrackPositions(store: store, lap: lap)

        // 8. Telemetry
        updateTelemetry(store: store, pitDrivers: pitDrivers)

        // 9. Stints
        updateStints(store: store, lap: lap)

        // 10. Track violations
        store.computeTrackViolations()
    }

    // MARK: - Event Processing

    private func processEvent(
        _ event: RaceEvent, lap: Int, store: LiveTimingStore, pitDrivers: inout Set<String>
    ) {
        switch event {
        case .pitStop(let driver, let newCompound):
            pitDrivers.insert(driver)
            currentCompound[driver] = newCompound
            stintStartLap[driver] = lap
            stintNumber[driver, default: 1] += 1
            let pit = PitStopData(
                driverNumber: Int(driver) ?? 0, lapNumber: lap,
                pitDuration: Double.random(in: 22.0...26.0), date: nil
            )
            store.pitStops[driver, default: []].append(pit)

        case .overtake(let driver, let passedDriver):
            // Adjust accumulated times so the overtaking driver is ahead
            let timeBump = 0.5
            accumulatedTime[driver, default: 0] -= timeBump
            accumulatedTime[passedDriver, default: 0] += timeBump

        case .raceControl(let cat, let msg, let flag, let scope, let sector, let rNum):
            appendRaceControl(store, category: cat, message: msg, flag: flag,
                              scope: scope, sector: sector, lap: lap, racingNumber: rNum)

        case .trackStatus(let status, let message):
            store.trackStatus = TrackStatus(status: status, message: message)

        case .teamRadio(let driver):
            store.teamRadioCaptures.append(RadioCapture(
                utc: Date(), racingNumber: driver,
                path: "TeamRadio/driver\(driver)_lap\(lap).m4a"
            ))

        case .retirement(let driver):
            retiredDrivers.insert(driver)
            if var pos = store.driverPositions[driver] {
                pos.status = "OffTrack"
                store.driverPositions[driver] = pos
            }

        case .drsChange(let enabled):
            drsEnabled = enabled
        }
    }

    // MARK: - Lap Time Generation

    private func generateLapTime(
        driverNum: String, lap: Int, isPitting: Bool,
        trackStatus: TrackStatus.TrackStatusCode
    ) -> Double {
        var time = baseLapTimes[driverNum] ?? 93.0

        // Fuel burn: lighter car each lap
        time -= Double(lap) * 0.04

        // Compound effect
        switch currentCompound[driverNum] ?? .medium {
        case .soft: time -= 0.4
        case .hard: time += 0.3
        default: break
        }

        // Tire degradation
        let stintAge = Double(lap - (stintStartLap[driverNum] ?? 1))
        time += stintAge * 0.03

        // Random variance
        time += Double.random(in: -0.4...0.4)

        // Pit penalty
        if isPitting {
            time += Double.random(in: 20.0...24.0)
        }

        // SC/VSC slowdown (all cars equally)
        switch trackStatus {
        case .vscDeployed, .vscEnding:
            time += 15.0
        case .safetyCar:
            time += 25.0
        default:
            break
        }

        return max(time, 85.0)
    }

    // MARK: - Sector Generation

    private func generateSectors(
        lapTime: Double, driverNum: String
    ) -> [TimingDataDriver.SectorTiming] {
        let fractions = [0.30, 0.35, 0.35]
        return fractions.enumerated().map { sIdx, frac in
            let sTime = lapTime * frac + Double.random(in: -0.15...0.15)

            let isPB = sTime < (overallBestSectors[sIdx] * 1.005)
            let isOB = sTime < overallBestSectors[sIdx]
            if isOB { overallBestSectors[sIdx] = sTime }

            let segments: [SegmentStatus] = (0..<8).map { _ in
                if isOB { return .purple }
                if isPB { return .green }
                return [SegmentStatus.amber, .green, .amberCompleted][Int.random(in: 0...2)]
            }

            return TimingDataDriver.SectorTiming(
                value: String(format: "%.3f", sTime),
                personalFastest: isPB,
                overallFastest: isOB,
                segments: segments
            )
        }
    }

    // MARK: - Track Positions

    private func updateTrackPositions(store: LiveTimingStore, lap: Int) {
        guard let trackMap = store.trackMap else { return }
        let pts = trackMap.points
        guard !pts.isEmpty else { return }
        let n = pts.count

        let leaderTime = accumulatedTime[racePositions.first ?? ""] ?? 1
        let avgLap = leaderTime / max(1, Double(lap))

        // Leader position cycles through the track each lap tick
        let leaderProg = Double(lap % 3) / 3.0

        for num in racePositions {
            guard !retiredDrivers.contains(num) else { continue }

            let myTime = accumulatedTime[num] ?? 0
            let gap = myTime - leaderTime
            let behindFrac = gap / max(avgLap, 80)

            var prog = leaderProg - behindFrac
            prog = prog.truncatingRemainder(dividingBy: 1.0)
            if prog < 0 { prog += 1.0 }

            let idx = Int(prog * Double(n)) % n
            let pt = pts[idx]

            store.driverPositions[num] = DriverPosition(
                x: Double(pt.x) + Double.random(in: -30...30),
                y: Double(pt.y) + Double.random(in: -30...30),
                z: 0, status: "OnTrack"
            )
        }
    }

    // MARK: - Telemetry

    private func updateTelemetry(store: LiveTimingStore, pitDrivers: Set<String>) {
        for (posIdx, num) in racePositions.enumerated() {
            guard !retiredDrivers.contains(num) else { continue }

            let pitting = pitDrivers.contains(num)
            let speed = pitting ? (80 + Int.random(in: 0...10)) : (310 - posIdx * 2 + Int.random(in: -5...5))
            let gear = pitting ? 2 : (posIdx < 5 ? 8 : 7)
            let rpm = pitting ? 6000 : (10500 + Int.random(in: -500...500))
            let throttle = pitting ? 30 : (posIdx < 5 ? 100 : 95)

            let drs: CarTelemetry.DRSStatus
            if pitting || !drsEnabled {
                drs = .off
            } else if posIdx < 3 {
                drs = .active
            } else if posIdx < 8 {
                drs = .eligible
            } else {
                drs = .off
            }

            store.carTelemetry[num] = CarTelemetry(
                rpm: rpm, speed: speed, gear: gear,
                throttle: throttle, drs: drs
            )
        }
    }

    // MARK: - Stints

    private func updateStints(store: LiveTimingStore, lap: Int) {
        for num in racePositions where !retiredDrivers.contains(num) {
            store.currentStints[num] = StintData(
                driverNumber: Int(num) ?? 0,
                stintNumber: stintNumber[num] ?? 1,
                compound: currentCompound[num] ?? .medium,
                tyreAgeAtStart: 0,
                lapStart: stintStartLap[num],
                lapEnd: nil
            )
        }
    }

    // MARK: - Helpers

    private func formatLapTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = seconds - Double(mins * 60)
        return String(format: "%d:%06.3f", mins, secs)
    }

    private func appendRaceControl(
        _ store: LiveTimingStore,
        category: RaceControlMessage.Category, message: String,
        flag: RaceControlMessage.Flag?, scope: RaceControlMessage.Scope,
        sector: Int? = nil, lap: Int? = nil, racingNumber: String? = nil
    ) {
        store.raceControlMessages.append(RaceControlMessage(
            utc: Date(), category: category, message: message,
            flag: flag, scope: scope, sector: sector,
            lap: lap ?? currentLap, racingNumber: racingNumber
        ))
    }

    // MARK: - Formation Lap Setup

    private func setupFormationLap(_ store: LiveTimingStore) {
        store.lapCount = LapCount(currentLap: 0, totalLaps: totalLaps)
        store.extrapolatedClock = ExtrapolatedClock(
            utc: Date(), remaining: "01:28:21", extrapolating: false
        )
        store.sessionStatus = .started
        store.trackStatus = TrackStatus(status: .allClear, message: "AllClear")
        store.raceControlMessages = []
        store.teamRadioCaptures = []
        store.pitStops = [:]

        for (posIdx, num) in racePositions.enumerated() {
            // Empty timing — race hasn't started
            store.timingData[num] = TimingDataDriver(
                position: "\(posIdx + 1)",
                gapToLeader: nil, intervalToPositionAhead: nil,
                bestLapTime: nil, lastLapTime: nil, numberOfLaps: 0,
                sectors: (0..<3).map { _ in
                    TimingDataDriver.SectorTiming(
                        value: nil, personalFastest: false,
                        overallFastest: false,
                        segments: Array(repeating: .none, count: 8)
                    )
                },
                segments: (0..<3).map { _ in Array(repeating: SegmentStatus.none, count: 8) },
                inPit: false, pitOut: false, stopped: false, retired: false
            )

            store.currentStints[num] = StintData(
                driverNumber: Int(num) ?? 0, stintNumber: 1,
                compound: startingCompounds[num] ?? .medium,
                tyreAgeAtStart: 0, lapStart: 1, lapEnd: nil
            )

            if var driver = store.drivers[num] {
                driver.line = posIdx + 1
                store.drivers[num] = driver
            }
        }

        // Place cars on the starting grid
        if let pts = store.trackMap?.points, !pts.isEmpty {
            for (posIdx, num) in racePositions.enumerated() {
                let frac = Double(posIdx) * 0.005
                let idx = Int(frac * Double(pts.count)) % pts.count
                let pt = pts[idx]
                store.driverPositions[num] = DriverPosition(
                    x: Double(pt.x), y: Double(pt.y), z: 0, status: "OnTrack"
                )
            }
        }

        appendRaceControl(store, category: .flag, message: "GREEN LIGHT - PIT EXIT OPEN",
                          flag: .green, scope: .track, lap: 0)
    }
}
