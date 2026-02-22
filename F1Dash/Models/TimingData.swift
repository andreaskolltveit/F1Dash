import Foundation
import SwiftUI

/// Timing data for a driver from the TimingData topic.
struct TimingDataDriver {
    var position: String?
    var gapToLeader: String?
    var intervalToPositionAhead: String?
    var intervalCatching: Bool = false
    var bestLapTime: String?
    var lastLapTime: String?
    var numberOfLaps: Int?
    var sectors: [SectorTiming]
    var segments: [[SegmentStatus]]
    var inPit: Bool
    var pitOut: Bool
    var stopped: Bool
    var retired: Bool
    var speeds: SpeedsData? = nil
    var knockedOut: Bool = false
    var cutoff: Bool = false
    var showPosition: Bool = true
    var driverStatus: Int? = nil
    var line: Int? = nil

    struct SectorTiming {
        var value: String?
        var personalFastest: Bool
        var overallFastest: Bool
        var segments: [SegmentStatus]
    }

    struct SpeedTrap {
        var value: String?
        var overallFastest: Bool = false
        var personalFastest: Bool = false
    }

    struct SpeedsData {
        var i1: SpeedTrap = SpeedTrap()
        var i2: SpeedTrap = SpeedTrap()
        var fl: SpeedTrap = SpeedTrap()
        var st: SpeedTrap = SpeedTrap()
    }
}

/// Mini-sector segment status codes from F1 API.
enum SegmentStatus: Int {
    case none = 0
    case amber = 2048
    case amberCompleted = 2052
    case green = 2049       // Personal best
    case purple = 2051      // Overall fastest
    case blue = 2064

    init(from value: Int) {
        self = SegmentStatus(rawValue: value) ?? .none
    }

    var color: Color {
        switch self {
        case .none: .gray.opacity(0.3)
        case .amber, .amberCompleted: .yellow
        case .green: .green
        case .purple: .purple
        case .blue: .blue
        }
    }

    var isActive: Bool {
        self != .none
    }
}

// MARK: - TimingStats (best lap/sector/speed per driver)

/// Statistics for a single driver from the TimingStats topic.
struct TimingStatsDriver {
    var personalBestLapTime: String?
    var personalBestLapPosition: Int?
    var bestSectors: [BestValue]
    var bestSpeeds: BestSpeeds

    struct BestValue {
        var value: String?
        var position: Int?
    }

    struct BestSpeeds {
        var i1: BestValue
        var i2: BestValue
        var fl: BestValue
        var st: BestValue
    }

    /// Whether this driver has the overall fastest lap.
    var hasFastestLap: Bool { personalBestLapPosition == 1 }
}

/// Parsed TimingStats state.
struct TimingStatsData {
    var drivers: [String: TimingStatsDriver] = [:]
    var sessionType: String?
}

// MARK: - ChampionshipPrediction

/// Live championship prediction during a race session.
struct ChampionshipPredictionData {
    var drivers: [ChampionshipEntry] = []
    var teams: [ChampionshipTeamEntry] = []

    struct ChampionshipEntry: Identifiable {
        var id: String { racingNumber }
        let racingNumber: String
        let currentPosition: Int
        let predictedPosition: Int
        let currentPoints: Double
        let predictedPoints: Double

        var positionDelta: Int { currentPosition - predictedPosition }
        var pointsDelta: Double { predictedPoints - currentPoints }
    }

    struct ChampionshipTeamEntry: Identifiable {
        var id: String { teamName }
        let teamName: String
        let currentPosition: Int
        let predictedPosition: Int
        let currentPoints: Double
        let predictedPoints: Double

        var positionDelta: Int { currentPosition - predictedPosition }
        var pointsDelta: Double { predictedPoints - currentPoints }
    }
}

// MARK: - SessionData (lap timestamps + status history)

/// Historical session data (lap series and status changes).
struct SessionDataInfo {
    var lapSeries: [LapEntry] = []
    var statusSeries: [StatusEntry] = []

    struct LapEntry {
        let utc: String
        let lap: Int
    }

    struct StatusEntry {
        let utc: String
        let trackStatus: String?
        let sessionStatus: String?
    }
}

/// Parse timing data from raw JSON.
enum TimingDataParser {

    static func parseDriver(dict: [String: Any]) -> TimingDataDriver {
        let sectorsDict = dict["Sectors"] as? [String: Any] ?? [:]
        var sectors: [TimingDataDriver.SectorTiming] = []

        // Sectors are keyed "0", "1", "2"
        for i in 0..<3 {
            if let sectorDict = sectorsDict["\(i)"] as? [String: Any] {
                let segmentsDict = sectorDict["Segments"] as? [String: Any] ?? [:]
                var segments: [SegmentStatus] = []
                let sortedKeys = segmentsDict.keys.compactMap { Int($0) }.sorted()
                for key in sortedKeys {
                    if let segDict = segmentsDict["\(key)"] as? [String: Any],
                       let status = segDict["Status"] as? Int {
                        segments.append(SegmentStatus(from: status))
                    }
                }

                sectors.append(TimingDataDriver.SectorTiming(
                    value: sectorDict["Value"] as? String,
                    personalFastest: sectorDict["PersonalFastest"] as? Bool ?? false,
                    overallFastest: sectorDict["OverallFastest"] as? Bool ?? false,
                    segments: segments
                ))
            }
        }

        let intervalObj = dict["IntervalToPositionAhead"] as? [String: Any]

        // Parse speed traps
        func parseSpeedTrap(_ raw: Any?) -> TimingDataDriver.SpeedTrap {
            guard let d = raw as? [String: Any] else { return TimingDataDriver.SpeedTrap() }
            return TimingDataDriver.SpeedTrap(
                value: d["Value"] as? String,
                overallFastest: d["OverallFastest"] as? Bool ?? false,
                personalFastest: d["PersonalFastest"] as? Bool ?? false
            )
        }

        var speeds: TimingDataDriver.SpeedsData? = nil
        if let speedsDict = dict["Speeds"] as? [String: Any] {
            speeds = TimingDataDriver.SpeedsData(
                i1: parseSpeedTrap(speedsDict["I1"]),
                i2: parseSpeedTrap(speedsDict["I2"]),
                fl: parseSpeedTrap(speedsDict["Fl"]),
                st: parseSpeedTrap(speedsDict["St"])
            )
        }

        return TimingDataDriver(
            position: dict["Position"] as? String,
            gapToLeader: dict["GapToLeader"] as? String,
            intervalToPositionAhead: dict["IntervalToPositionAhead"] as? String
                ?? intervalObj?["Value"] as? String,
            intervalCatching: intervalObj?["Catching"] as? Bool ?? false,
            bestLapTime: (dict["BestLapTime"] as? [String: Any])?["Value"] as? String,
            lastLapTime: (dict["LastLapTime"] as? [String: Any])?["Value"] as? String,
            numberOfLaps: dict["NumberOfLaps"] as? Int,
            sectors: sectors,
            segments: sectors.map(\.segments),
            inPit: dict["InPit"] as? Bool ?? false,
            pitOut: dict["PitOut"] as? Bool ?? false,
            stopped: dict["Stopped"] as? String == "true" || dict["Stopped"] as? Bool == true,
            retired: dict["Retired"] as? Bool ?? false,
            speeds: speeds,
            knockedOut: dict["KnockedOut"] as? Bool ?? false,
            cutoff: dict["Cutoff"] as? Bool ?? false,
            showPosition: dict["ShowPosition"] as? Bool ?? true,
            driverStatus: dict["Status"] as? Int,
            line: dict["Line"] as? Int
        )
    }

    // MARK: - TimingStats Parser

    static func parseTimingStats(dict: [String: Any]) -> TimingStatsData {
        let lines = dict["Lines"] as? [String: Any] ?? [:]
        var drivers: [String: TimingStatsDriver] = [:]

        for (key, value) in lines {
            guard let driverDict = value as? [String: Any] else { continue }
            drivers[key] = parseTimingStatsDriver(dict: driverDict)
        }

        return TimingStatsData(
            drivers: drivers,
            sessionType: dict["SessionType"] as? String
        )
    }

    private static func parseTimingStatsDriver(dict: [String: Any]) -> TimingStatsDriver {
        let bestLap = dict["PersonalBestLapTime"] as? [String: Any]
        let bestSectorsDict = dict["BestSectors"] as? [String: Any] ?? [:]
        let bestSpeedsDict = dict["BestSpeeds"] as? [String: Any] ?? [:]

        var sectors: [TimingStatsDriver.BestValue] = []
        for i in 0..<3 {
            if let s = bestSectorsDict["\(i)"] as? [String: Any] {
                sectors.append(TimingStatsDriver.BestValue(
                    value: s["Value"] as? String,
                    position: s["Position"] as? Int
                ))
            }
        }

        func parseBestValue(_ d: [String: Any]?, key: String) -> TimingStatsDriver.BestValue {
            guard let s = (d?[key] as? [String: Any]) else {
                return TimingStatsDriver.BestValue(value: nil, position: nil)
            }
            return TimingStatsDriver.BestValue(value: s["Value"] as? String, position: s["Position"] as? Int)
        }

        return TimingStatsDriver(
            personalBestLapTime: bestLap?["Value"] as? String,
            personalBestLapPosition: bestLap?["Position"] as? Int,
            bestSectors: sectors,
            bestSpeeds: TimingStatsDriver.BestSpeeds(
                i1: parseBestValue(bestSpeedsDict, key: "I1"),
                i2: parseBestValue(bestSpeedsDict, key: "I2"),
                fl: parseBestValue(bestSpeedsDict, key: "Fl"),
                st: parseBestValue(bestSpeedsDict, key: "St")
            )
        )
    }

    // MARK: - ChampionshipPrediction Parser

    static func parseChampionshipPrediction(dict: [String: Any]) -> ChampionshipPredictionData {
        var result = ChampionshipPredictionData()

        if let driversDict = dict["Drivers"] as? [String: Any] {
            for (_, value) in driversDict {
                guard let d = value as? [String: Any] else { continue }
                result.drivers.append(ChampionshipPredictionData.ChampionshipEntry(
                    racingNumber: d["RacingNumber"] as? String ?? "",
                    currentPosition: d["CurrentPosition"] as? Int ?? 0,
                    predictedPosition: d["PredictedPosition"] as? Int ?? 0,
                    currentPoints: (d["CurrentPoints"] as? NSNumber)?.doubleValue ?? 0,
                    predictedPoints: (d["PredictedPoints"] as? NSNumber)?.doubleValue ?? 0
                ))
            }
            result.drivers.sort { $0.predictedPosition < $1.predictedPosition }
        }

        if let teamsDict = dict["Teams"] as? [String: Any] {
            for (_, value) in teamsDict {
                guard let t = value as? [String: Any] else { continue }
                result.teams.append(ChampionshipPredictionData.ChampionshipTeamEntry(
                    teamName: t["TeamName"] as? String ?? "",
                    currentPosition: t["CurrentPosition"] as? Int ?? 0,
                    predictedPosition: t["PredictedPosition"] as? Int ?? 0,
                    currentPoints: (t["CurrentPoints"] as? NSNumber)?.doubleValue ?? 0,
                    predictedPoints: (t["PredictedPoints"] as? NSNumber)?.doubleValue ?? 0
                ))
            }
            result.teams.sort { $0.predictedPosition < $1.predictedPosition }
        }

        return result
    }

    // MARK: - SessionData Parser

    static func parseSessionData(dict: [String: Any]) -> SessionDataInfo {
        var result = SessionDataInfo()

        if let series = dict["Series"] as? [[String: Any]] {
            for entry in series {
                if let utc = entry["Utc"] as? String, let lap = entry["Lap"] as? Int {
                    result.lapSeries.append(SessionDataInfo.LapEntry(utc: utc, lap: lap))
                }
            }
        }

        if let status = dict["StatusSeries"] as? [[String: Any]] {
            for entry in status {
                if let utc = entry["Utc"] as? String {
                    result.statusSeries.append(SessionDataInfo.StatusEntry(
                        utc: utc,
                        trackStatus: entry["TrackStatus"] as? String,
                        sessionStatus: entry["SesionStatus"] as? String ?? entry["SessionStatus"] as? String
                    ))
                }
            }
        }

        return result
    }

    // MARK: - TimingAppData Parser

    static func parseTimingAppData(dict: [String: Any]) -> [String: TimingAppDriverData] {
        let lines = dict["Lines"] as? [String: Any] ?? [:]
        var result: [String: TimingAppDriverData] = [:]
        for (key, value) in lines {
            guard let d = value as? [String: Any] else { continue }
            let stintsRaw = d["Stints"] as? [String: Any] ?? [:]
            var stints: [TimingAppDriverData.StintInfo] = []
            for i in 0..<stintsRaw.count {
                if let s = stintsRaw["\(i)"] as? [String: Any] {
                    stints.append(TimingAppDriverData.StintInfo(
                        totalLaps: s["TotalLaps"] as? Int,
                        compound: s["Compound"] as? String,
                        isNew: (s["New"] as? String) == "true"
                    ))
                }
            }
            result[key] = TimingAppDriverData(
                stints: stints,
                gridPos: d["GridPos"] as? String,
                line: d["Line"] as? Int
            )
        }
        return result
    }
}

// MARK: - TimingAppData Model

struct TimingAppDriverData {
    var stints: [StintInfo] = []
    var gridPos: String?
    var line: Int?

    struct StintInfo {
        var totalLaps: Int?
        var compound: String?
        var isNew: Bool?
    }
}
