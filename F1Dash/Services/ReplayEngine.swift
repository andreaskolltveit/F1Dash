import Foundation
import os

/// Plays back historical F1 session data through the LiveTimingStore.
/// Follows the same pattern as RaceSimulator — writes directly to the store.
@Observable
@MainActor
final class ReplayEngine {
    private let logger = Logger(subsystem: "com.f1dash", category: "ReplayEngine")

    // MARK: - Public State

    var state: ReplayState = .idle
    var speed: ReplaySpeed = .x1
    var currentLap: Int = 0
    var totalLaps: Int = 0
    var currentTime: Date?
    var sessionStartTime: Date?
    var sessionEndTime: Date?
    var elapsedText: String = "00:00"
    var selectedSession: OpenF1Session?
    var availableSessions: [OpenF1Session] = []

    // MARK: - Internal State

    // Internal for @testable access
    var store: LiveTimingStore?
    private var sessionData: ReplaySessionData?
    private var playbackTask: Task<Void, Never>?
    private var currentEventIndex: Int = 0
    private let loader = ReplayDataLoader()

    /// Per-driver best lap time (for sector coloring).
    private var driverBestLap: [Int: Double] = [:]
    private var overallBestLap: Double = .infinity

    /// Per-driver latest lap number.
    private var driverLapNumbers: [Int: Int] = [:]

    // MARK: - Session Discovery

    /// Fetch available sessions for a year.
    func loadSessions(year: Int) async {
        state = .loading
        do {
            let client = OpenF1Client()
            let sessions = try await client.fetchSessions(year: year)
            // Sort by date descending (most recent first)
            availableSessions = sessions.sorted {
                ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast)
            }
            state = .idle
        } catch {
            logger.error("Failed to load sessions: \(error.localizedDescription)")
            state = .error("Failed to load sessions: \(error.localizedDescription)")
        }
    }

    // MARK: - Load Session Data

    /// Load all data for the selected session.
    func loadSession(_ session: OpenF1Session, store: LiveTimingStore) async {
        self.store = store
        self.selectedSession = session
        state = .loading

        do {
            let data = try await loader.loadSession(sessionKey: session.sessionKey)
            self.sessionData = data
            self.totalLaps = data.totalLaps

            // Set up store with driver data
            setupDrivers(data.drivers, session: session)

            // Determine timeline bounds
            if let first = data.events.first?.timestamp {
                sessionStartTime = first
            }
            if let last = data.events.last?.timestamp {
                sessionEndTime = last
            }

            currentEventIndex = 0
            currentLap = 1
            state = .ready
            logger.info("Session loaded: \(data.events.count) events, \(data.totalLaps) laps")
        } catch {
            logger.error("Failed to load session data: \(error.localizedDescription)")
            state = .error("Failed to load data: \(error.localizedDescription)")
        }
    }

    // MARK: - Playback Controls

    func play() {
        guard state == .ready || state == .paused else { return }
        state = .playing
        playbackTask = Task { await runPlayback() }
    }

    func pause() {
        guard state == .playing else { return }
        playbackTask?.cancel()
        playbackTask = nil
        state = .paused
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        state = .idle
        currentEventIndex = 0
        currentLap = 0
        selectedSession = nil
        sessionData = nil
        driverBestLap = [:]
        driverLapNumbers = [:]
        overallBestLap = .infinity
    }

    /// Seek to a specific lap.
    func seekToLap(_ lap: Int) {
        guard let data = sessionData else { return }
        guard let targetDate = data.lapBoundaries[lap] else { return }

        let wasPlaying = state == .playing
        if wasPlaying {
            playbackTask?.cancel()
            playbackTask = nil
        }

        // Find the event index closest to this lap's start
        currentEventIndex = data.events.firstIndex { $0.timestamp >= targetDate } ?? 0
        currentLap = lap
        currentTime = targetDate

        // Replay all events up to this point to rebuild state
        replayUpToIndex(currentEventIndex)

        if wasPlaying {
            state = .playing
            playbackTask = Task { await runPlayback() }
        } else {
            state = .paused
        }
    }

    // MARK: - Playback Loop

    private func runPlayback() async {
        guard let data = sessionData, let store else { return }

        logger.info("Starting playback from event \(self.currentEventIndex)")

        var lastEventTime: Date?

        while currentEventIndex < data.events.count {
            guard !Task.isCancelled else { return }

            let event = data.events[currentEventIndex]

            // Calculate delay between events (scaled by speed)
            if let lastTime = lastEventTime {
                let realDelta = event.timestamp.timeIntervalSince(lastTime)
                let scaledDelta = realDelta / speed.rawValue

                // Clamp: skip gaps > 30s real time, minimum 1ms
                if scaledDelta > 0.001 && scaledDelta < 30.0 {
                    try? await Task.sleep(for: .seconds(scaledDelta))
                    guard !Task.isCancelled else { return }
                }
            }

            lastEventTime = event.timestamp
            currentTime = event.timestamp
            applyEvent(event, to: store)
            currentEventIndex += 1
        }

        state = .finished
        logger.info("Replay finished")
    }

    // MARK: - Apply Events to Store

    func applyEvent(_ event: ReplayEvent, to store: LiveTimingStore) {
        switch event.kind {
        case .position(let driverNumber, let position):
            let key = "\(driverNumber)"
            if var td = store.timingData[key] {
                td.position = "\(position)"
                store.timingData[key] = td
            } else {
                store.timingData[key] = TimingDataDriver(
                    position: "\(position)",
                    gapToLeader: nil, intervalToPositionAhead: nil,
                    bestLapTime: nil, lastLapTime: nil, numberOfLaps: 0,
                    sectors: emptySectors(), segments: emptySegments(),
                    inPit: false, pitOut: false, stopped: false, retired: false
                )
            }
            // Update driver line property
            if var driver = store.drivers[key] {
                driver.line = position
                store.drivers[key] = driver
            }

        case .lap(let lap):
            let key = "\(lap.driverNumber)"
            driverLapNumbers[lap.driverNumber] = lap.lapNumber
            currentLap = max(currentLap, lap.lapNumber)

            // Update lap count
            store.lapCount = LapCount(currentLap: currentLap, totalLaps: totalLaps)

            if var td = store.timingData[key] {
                td.numberOfLaps = lap.lapNumber

                // Format lap time
                if let duration = lap.lapDuration {
                    td.lastLapTime = formatLapTime(duration)

                    // Track best lap
                    if duration < (driverBestLap[lap.driverNumber] ?? .infinity) {
                        driverBestLap[lap.driverNumber] = duration
                        td.bestLapTime = formatLapTime(duration)
                    }
                    if duration < overallBestLap {
                        overallBestLap = duration
                    }
                }

                // Build sector timings
                td.sectors = buildSectors(from: lap)
                td.segments = td.sectors.map(\.segments)

                td.inPit = false
                td.pitOut = lap.isPitOutLap ?? false

                store.timingData[key] = td
            }

            // Estimate remaining time
            updateClock()

        case .interval(let driverNumber, let gapToLeader, let gapToLeaderText, let interval, let intervalText):
            let key = "\(driverNumber)"
            if var td = store.timingData[key] {
                if let gap = gapToLeader {
                    td.gapToLeader = gap == 0 ? "" : "+\(String(format: "%.3f", gap))"
                } else if let text = gapToLeaderText {
                    td.gapToLeader = text
                }
                if let interval {
                    td.intervalToPositionAhead = interval == 0 ? "" : "+\(String(format: "%.3f", interval))"
                } else if let text = intervalText {
                    td.intervalToPositionAhead = text
                }
                store.timingData[key] = td
            }

        case .raceControl(let rc):
            let msg = convertRaceControl(rc)
            store.raceControlMessages.append(msg)

            // Update track status from flags
            if let flag = rc.flag?.uppercased() {
                if flag.contains("RED") {
                    store.trackStatus = TrackStatus(status: .redFlag, message: rc.message)
                } else if rc.message.uppercased().contains("SAFETY CAR") && !rc.message.uppercased().contains("VIRTUAL") {
                    store.trackStatus = TrackStatus(status: .safetyCar, message: rc.message)
                } else if rc.message.uppercased().contains("VIRTUAL SAFETY CAR") {
                    store.trackStatus = TrackStatus(status: .vscDeployed, message: rc.message)
                } else if flag.contains("GREEN") && rc.scope?.uppercased() == "TRACK" {
                    store.trackStatus = TrackStatus(status: .allClear, message: rc.message)
                }
            }

            store.computeTrackViolations()

        case .carData(let driverNumber, let speed, let rpm, let gear, let throttle, let brake, let drs):
            let key = "\(driverNumber)"
            let drsStatus: CarTelemetry.DRSStatus
            switch drs {
            case 10, 12, 14: drsStatus = .active
            case 8: drsStatus = .eligible
            default: drsStatus = .off
            }
            store.carTelemetry[key] = CarTelemetry(
                rpm: rpm ?? 0, speed: speed ?? 0, gear: gear ?? 0,
                throttle: throttle ?? 0, brake: brake ?? 0, drs: drsStatus
            )

        case .teamRadio(let driverNumber, let recordingUrl):
            store.teamRadioCaptures.append(RadioCapture(
                utc: currentTime ?? Date(),
                racingNumber: "\(driverNumber)",
                path: recordingUrl ?? ""
            ))

        case .weather(let w):
            store.weatherData = WeatherData(
                airTemp: w.airTemperature,
                trackTemp: w.trackTemperature,
                humidity: w.humidity,
                pressure: w.pressure,
                windSpeed: w.windSpeed,
                windDirection: w.windDirection != nil ? Double(w.windDirection!) : nil,
                rainfall: (w.rainfall ?? 0) > 0
            )

        case .location(let driverNumber, let x, let y, let z):
            store.driverPositions["\(driverNumber)"] = DriverPosition(
                x: x, y: y, z: z, status: "OnTrack"
            )

        case .stint(let stint):
            store.currentStints["\(stint.driverNumber)"] = stint

        case .pitStop(let pit):
            let key = "\(pit.driverNumber)"
            store.pitStops[key, default: []].append(pit)
            if var td = store.timingData[key] {
                td.inPit = true
                store.timingData[key] = td
            }
        }
    }

    // MARK: - Rebuild State (for seek)

    /// Replay all events up to the given index to rebuild store state.
    private func replayUpToIndex(_ targetIndex: Int) {
        guard let data = sessionData, let store else { return }

        // Reset store state
        store.timingData = [:]
        store.raceControlMessages = []
        store.teamRadioCaptures = []
        store.carTelemetry = [:]
        store.driverPositions = [:]
        store.currentStints = [:]
        store.pitStops = [:]
        store.trackViolations = [:]
        driverBestLap = [:]
        driverLapNumbers = [:]
        overallBestLap = .infinity

        // Re-apply all events up to target
        for i in 0..<targetIndex {
            applyEvent(data.events[i], to: store)
        }
    }

    // MARK: - Driver Setup

    func setupDrivers(_ openF1Drivers: [OpenF1Driver], session: OpenF1Session) {
        guard let store else { return }

        // Set up session info
        store.sessionInfo = SessionInfo(
            meetingName: session.displayName,
            meetingOfficialName: session.displayName,
            meetingCountryName: session.countryName ?? "",
            meetingCircuitShortName: session.circuitShortName ?? "",
            meetingCircuitKey: session.circuitKey ?? 0,
            sessionName: session.sessionName,
            sessionType: session.sessionType ?? "Race",
            sessionPath: "",
            gmtOffset: nil,
            startDate: session.startDate,
            endDate: nil,
            year: session.year
        )
        store.sessionStatus = .started

        // Convert OpenF1 drivers to our Driver model
        for d in openF1Drivers {
            let key = "\(d.driverNumber)"
            let name = d.displayName
            let nameParts = name.split(separator: " ")
            store.drivers[key] = Driver(
                id: key,
                racingNumber: key,
                tla: d.tla,
                firstName: nameParts.first.map(String.init) ?? name,
                lastName: nameParts.dropFirst().joined(separator: " "),
                fullName: name,
                teamName: d.teamName ?? "Unknown",
                teamColour: d.teamColour ?? "888888",
                line: d.driverNumber,
                countryCode: d.countryCode ?? ""
            )
        }

        // Fetch track map
        let year = session.year
        if let circuitKey = session.circuitKey {
            Task {
                do {
                    let map = try await TrackMapAPI.fetchTrackMap(circuitKey: circuitKey, year: year)
                    await MainActor.run { store.trackMap = map }
                } catch {
                    logger.error("Failed to fetch track map: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatLapTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = seconds - Double(mins * 60)
        return String(format: "%d:%06.3f", mins, secs)
    }

    private func updateClock() {
        guard totalLaps > 0 else { return }
        let avgLapSec = 93.0
        let remainingSec = max(0, Double(totalLaps - currentLap) * avgLapSec)
        let h = Int(remainingSec) / 3600
        let m = (Int(remainingSec) % 3600) / 60
        let s = Int(remainingSec) % 60
        store?.extrapolatedClock = ExtrapolatedClock(
            utc: currentTime ?? Date(),
            remaining: String(format: "%02d:%02d:%02d", h, m, s),
            extrapolating: true
        )

        // Elapsed text
        if let start = sessionStartTime, let current = currentTime {
            let elapsed = current.timeIntervalSince(start)
            let em = Int(elapsed) / 60
            let es = Int(elapsed) % 60
            elapsedText = String(format: "%02d:%02d", em, es)
        }
    }

    private func convertRaceControl(_ rc: HistoricalRaceControl) -> RaceControlMessage {
        let category: RaceControlMessage.Category
        switch rc.category?.lowercased() {
        case "flag": category = .flag
        case "drs": category = .drs
        case "safetycar": category = .safetycar
        default: category = .other
        }

        let flag: RaceControlMessage.Flag?
        switch rc.flag?.lowercased() {
        case "green": flag = .green
        case "yellow": flag = .yellow
        case "red": flag = .red
        case "blue": flag = .blue
        case "black": flag = .black
        case "black and white": flag = .blackAndWhite
        case "chequered": flag = .chequered
        default: flag = nil
        }

        let scope: RaceControlMessage.Scope
        switch rc.scope?.lowercased() {
        case "track": scope = .track
        case "sector": scope = .sector
        case "driver": scope = .driver
        default: scope = .track
        }

        return RaceControlMessage(
            utc: currentTime ?? Date(),
            category: category,
            message: rc.message,
            flag: flag,
            scope: scope,
            sector: rc.sector,
            lap: rc.lapNumber ?? currentLap,
            racingNumber: rc.driverNumber.map { "\($0)" }
        )
    }

    private func buildSectors(from lap: HistoricalLap) -> [TimingDataDriver.SectorTiming] {
        let durations = [lap.durationSector1, lap.durationSector2, lap.durationSector3]
        return durations.map { duration in
            let value = duration.map { String(format: "%.3f", $0) }
            let isPB = false  // Would need full history to determine
            let isOB = false
            let segments: [SegmentStatus] = Array(repeating: duration != nil ? .green : .none, count: 8)
            return TimingDataDriver.SectorTiming(
                value: value,
                personalFastest: isPB,
                overallFastest: isOB,
                segments: segments
            )
        }
    }

    private func emptySectors() -> [TimingDataDriver.SectorTiming] {
        (0..<3).map { _ in
            TimingDataDriver.SectorTiming(
                value: nil, personalFastest: false, overallFastest: false,
                segments: Array(repeating: .none, count: 8)
            )
        }
    }

    private func emptySegments() -> [[SegmentStatus]] {
        (0..<3).map { _ in Array(repeating: SegmentStatus.none, count: 8) }
    }
}
