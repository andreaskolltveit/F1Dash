import Foundation
import os

/// Main observable store for all F1 Live Timing data.
/// Holds both raw JSON state (for merging) and decoded typed models.
@Observable
final class LiveTimingStore {
    private let logger = Logger(subsystem: "com.f1dash", category: "Store")

    // MARK: - Raw State (for deep-merge)

    private var rawState: [String: Any] = [:]

    // MARK: - Decoded Models

    var drivers: [String: Driver] = [:]
    var driversSorted: [Driver] {
        drivers.values.sorted { ($0.line) < ($1.line) }
    }

    var raceControlMessages: [RaceControlMessage] = []
    var teamRadioCaptures: [RadioCapture] = []
    var sessionInfo: SessionInfo?
    var sessionStatus: SessionStatusValue = .inactive
    var trackStatus: TrackStatus = .init(status: .allClear, message: "")
    var weatherData: WeatherData?
    var extrapolatedClock: ExtrapolatedClock?
    var lapCount: LapCount?
    var timingData: [String: TimingDataDriver] = [:]
    var carTelemetry: [String: CarTelemetry] = [:]
    var driverPositions: [String: DriverPosition] = [:]
    var trackMap: TrackMap?
    var timingStats: TimingStatsData?
    var championshipPrediction: ChampionshipPredictionData?
    var sessionData: SessionDataInfo?
    var timingAppData: [String: TimingAppDriverData] = [:]

    // MARK: - OpenF1 Data
    var currentStints: [String: StintData] = [:]
    var pitStops: [String: [PitStopData]] = [:]
    var trackViolations: [String: TrackViolation] = [:]

    let audioPlayer = AudioPlayerService()

    // MARK: - Update Raw State

    /// Set raw state for a topic (used for initial state).
    func updateRawState(topic: String, data: Any) {
        rawState[topic] = data
    }

    /// Merge incoming data into raw state, then decode.
    func mergeAndDecode(topic: String, data: Any) {
        rawState[topic] = StateMerger.merge(base: rawState[topic], update: data)
        decodeTopic(topic)
    }

    /// Decode all topics from raw state (used after initial state load).
    func decodeAllFromRawState() {
        for topic in rawState.keys {
            decodeTopic(topic)
        }
    }

    // MARK: - Decode Individual Topics

    /// Decode a single topic from raw state.
    func decodeTopic(_ topic: String) {
        switch topic {
        case "DriverList":
            decodeDriverList()
        case "RaceControlMessages":
            decodeRaceControlMessages()
        case "TeamRadio":
            decodeTeamRadio()
        case "SessionInfo":
            decodeSessionInfo()
        case "SessionStatus":
            decodeSessionStatus()
        case "TrackStatus":
            decodeTrackStatus()
        case "WeatherData":
            decodeWeatherData()
        case "ExtrapolatedClock":
            decodeExtrapolatedClock()
        case "LapCount":
            decodeLapCount()
        case "TimingData":
            decodeTimingData()
        case "CarData":
            decodeCarData()
        case "Position":
            decodePositionData()
        case "TimingStats":
            decodeTimingStats()
        case "ChampionshipPrediction":
            decodeChampionshipPrediction()
        case "SessionData":
            decodeSessionData()
        case "TimingAppData":
            decodeTimingAppData()
        default:
            break
        }
    }

    private func decodeDriverList() {
        guard let dict = rawState["DriverList"] as? [String: Any] else { return }
        var newDrivers: [String: Driver] = [:]
        for (key, value) in dict {
            guard let driverDict = value as? [String: Any] else { continue }
            newDrivers[key] = Driver.from(key: key, dict: driverDict)
        }
        if !newDrivers.isEmpty {
            drivers = newDrivers
        }
    }

    private func decodeRaceControlMessages() {
        guard let dict = rawState["RaceControlMessages"] as? [String: Any],
              let messages = dict["Messages"] as? [String: Any] else { return }

        var decoded: [RaceControlMessage] = []
        let sortedKeys = messages.keys.compactMap { Int($0) }.sorted()
        for key in sortedKeys {
            if let msgDict = messages["\(key)"] as? [String: Any],
               let msg = RaceControlMessage.from(dict: msgDict) {
                decoded.append(msg)
            }
        }
        raceControlMessages = decoded
        computeTrackViolations()
    }

    private func decodeTeamRadio() {
        guard let dict = rawState["TeamRadio"] as? [String: Any],
              let captures = dict["Captures"] as? [String: Any] else { return }

        var decoded: [RadioCapture] = []
        let sortedKeys = captures.keys.compactMap { Int($0) }.sorted()
        for key in sortedKeys {
            if let captureDict = captures["\(key)"] as? [String: Any],
               let capture = RadioCapture.from(dict: captureDict) {
                decoded.append(capture)
            }
        }
        teamRadioCaptures = decoded
    }

    private func decodeSessionInfo() {
        guard let dict = rawState["SessionInfo"] as? [String: Any] else { return }
        sessionInfo = SessionInfo.from(dict: dict)

        // Fetch track map when session info changes
        if let circuitKey = sessionInfo?.meetingCircuitKey {
            let year = sessionInfo?.year ?? Calendar.current.component(.year, from: Date())
            Task {
                do {
                    let map = try await TrackMapAPI.fetchTrackMap(circuitKey: circuitKey, year: year)
                    await MainActor.run { self.trackMap = map }
                } catch {
                    logger.error("Failed to fetch track map: \(error.localizedDescription)")
                }
            }
        }
    }

    private func decodeSessionStatus() {
        guard let dict = rawState["SessionStatus"] as? [String: Any],
              let status = dict["Status"] as? String else { return }
        sessionStatus = SessionStatusValue(rawValue: status) ?? .inactive
    }

    private func decodeTrackStatus() {
        guard let dict = rawState["TrackStatus"] as? [String: Any] else { return }
        trackStatus = TrackStatus.from(dict: dict)
    }

    private func decodeWeatherData() {
        guard let dict = rawState["WeatherData"] as? [String: Any] else { return }
        weatherData = WeatherData.from(dict: dict)
    }

    private func decodeExtrapolatedClock() {
        guard let dict = rawState["ExtrapolatedClock"] as? [String: Any] else { return }
        extrapolatedClock = ExtrapolatedClock.from(dict: dict)
    }

    private func decodeLapCount() {
        guard let dict = rawState["LapCount"] as? [String: Any] else { return }
        lapCount = LapCount.from(dict: dict)
    }

    private func decodeTimingData() {
        guard let dict = rawState["TimingData"] as? [String: Any],
              let lines = dict["Lines"] as? [String: Any] else { return }

        var newTiming: [String: TimingDataDriver] = [:]
        for (driverNumber, data) in lines {
            guard let driverDict = data as? [String: Any] else { continue }
            newTiming[driverNumber] = TimingDataParser.parseDriver(dict: driverDict)
        }
        timingData = newTiming
    }

    private func decodeCarData() {
        guard let raw = rawState["CarData"] else { return }
        if let parsed = CarTelemetry.parseEntries(raw) {
            carTelemetry = parsed
        }
    }

    private func decodePositionData() {
        guard let raw = rawState["Position"] else { return }
        if let parsed = DriverPosition.parseEntries(raw) {
            driverPositions = parsed
        }
    }

    private func decodeTimingStats() {
        guard let dict = rawState["TimingStats"] as? [String: Any] else { return }
        timingStats = TimingDataParser.parseTimingStats(dict: dict)
    }

    private func decodeChampionshipPrediction() {
        guard let dict = rawState["ChampionshipPrediction"] as? [String: Any] else { return }
        championshipPrediction = TimingDataParser.parseChampionshipPrediction(dict: dict)
    }

    private func decodeSessionData() {
        guard let dict = rawState["SessionData"] as? [String: Any] else { return }
        sessionData = TimingDataParser.parseSessionData(dict: dict)
    }

    private func decodeTimingAppData() {
        guard let dict = rawState["TimingAppData"] as? [String: Any] else { return }
        timingAppData = TimingDataParser.parseTimingAppData(dict: dict)
    }

    // MARK: - Track Violations

    /// Aggregate track violation messages per driver from race control messages.
    func computeTrackViolations() {
        var violations: [String: TrackViolation] = [:]
        for msg in raceControlMessages {
            let isTrackLimits = msg.message.localizedCaseInsensitiveContains("TRACK LIMITS")
                || msg.flag == .blackAndWhite
            guard isTrackLimits, let driverNum = msg.racingNumber else { continue }

            if var existing = violations[driverNum] {
                existing.count += 1
                if let lap = msg.lap { existing.lastLap = lap }
                existing.messages.append(msg)
                violations[driverNum] = existing
            } else {
                violations[driverNum] = TrackViolation(
                    id: driverNum,
                    driverNumber: driverNum,
                    count: 1,
                    lastLap: msg.lap,
                    messages: [msg]
                )
            }
        }
        trackViolations = violations
    }
}
