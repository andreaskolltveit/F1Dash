import Foundation
import os

/// Loads historical session data from OpenF1 and builds a sorted timeline of ReplayEvents.
actor ReplayDataLoader {
    private let logger = Logger(subsystem: "com.f1dash", category: "ReplayLoader")
    private let client = OpenF1Client()

    /// Load all data for a session and build a sorted timeline.
    /// Requests are sequential to respect OpenF1 rate limits.
    func loadSession(sessionKey: Int) async throws -> ReplaySessionData {
        logger.info("Loading replay data for session \(sessionKey)")

        // Sequential fetches to respect rate limits (OpenF1 returns 429 on burst)
        let drivers = try await client.fetchDrivers(sessionKey: sessionKey)
        let positions = try await client.fetchPositions(sessionKey: sessionKey)
        let laps = try await client.fetchLaps(sessionKey: sessionKey)
        let intervals = try await client.fetchIntervals(sessionKey: sessionKey)
        let raceControl = try await client.fetchRaceControl(sessionKey: sessionKey)
        let stints = try await client.fetchStints(sessionKey: sessionKey)
        let pitStops = try await client.fetchPitStops(sessionKey: sessionKey)
        let teamRadio = try await client.fetchTeamRadio(sessionKey: sessionKey)
        let weather = try await client.fetchWeather(sessionKey: sessionKey)

        // Location + car data require per-driver fetches (OpenF1 returns 422 without driver_number filter)
        let driverNumbers = drivers.map(\.driverNumber)
        var locations: [HistoricalLocation] = []
        var carData: [HistoricalCarData] = []
        for num in driverNumbers {
            let driverLocs = try await client.fetchLocations(sessionKey: sessionKey, driverNumber: num)
            locations.append(contentsOf: driverLocs)
            let driverCar = try await client.fetchCarData(sessionKey: sessionKey, driverNumber: num)
            carData.append(contentsOf: driverCar)
        }

        logger.info("Loaded: \(drivers.count) drivers, \(positions.count) positions, \(laps.count) laps, \(intervals.count) intervals, \(raceControl.count) RC msgs, \(stints.count) stints, \(pitStops.count) pit stops, \(teamRadio.count) radio, \(weather.count) weather, \(locations.count) locations, \(carData.count) car data")

        // Build timeline
        var events: [ReplayEvent] = []

        // Position events
        for p in positions {
            if let date = parseOpenF1Date(p.date) {
                events.append(ReplayEvent(
                    timestamp: date,
                    kind: .position(driverNumber: p.driverNumber, position: p.position)
                ))
            }
        }

        // Lap events
        for l in laps {
            if let dateStr = l.dateStart, let date = parseOpenF1Date(dateStr) {
                events.append(ReplayEvent(timestamp: date, kind: .lap(l)))
            }
        }

        // Interval events
        for i in intervals {
            if let date = parseOpenF1Date(i.date) {
                events.append(ReplayEvent(
                    timestamp: date,
                    kind: .interval(driverNumber: i.driverNumber, gapToLeader: i.gapToLeader, gapToLeaderText: i.gapToLeaderText, interval: i.interval, intervalText: i.intervalText)
                ))
            }
        }

        // Race control events
        for rc in raceControl {
            if let date = parseOpenF1Date(rc.date) {
                events.append(ReplayEvent(timestamp: date, kind: .raceControl(rc)))
            }
        }

        // Team radio events
        for tr in teamRadio {
            if let date = parseOpenF1Date(tr.date) {
                events.append(ReplayEvent(
                    timestamp: date,
                    kind: .teamRadio(driverNumber: tr.driverNumber, recordingUrl: tr.recordingUrl)
                ))
            }
        }

        // Weather events
        for w in weather {
            if let date = parseOpenF1Date(w.date) {
                events.append(ReplayEvent(timestamp: date, kind: .weather(w)))
            }
        }

        // Location events (sampled: keep every Nth point per driver to reduce volume)
        let sampledLocations = samplePerDriver(locations, interval: 4)  // ~1 update/sec instead of 4/sec
        for loc in sampledLocations {
            if let date = parseOpenF1Date(loc.date) {
                events.append(ReplayEvent(
                    timestamp: date,
                    kind: .location(driverNumber: loc.driverNumber, x: loc.x, y: loc.y, z: loc.z)
                ))
            }
        }

        // Car data events (sampled: keep every Nth point per driver)
        let sampledCarData = sampleCarDataPerDriver(carData, interval: 10)  // ~1 update per ~2.5s
        for cd in sampledCarData {
            if let date = parseOpenF1Date(cd.date) {
                events.append(ReplayEvent(
                    timestamp: date,
                    kind: .carData(driverNumber: cd.driverNumber, speed: cd.speed, rpm: cd.rpm,
                                   gear: cd.gear, throttle: cd.throttle, brake: cd.brake, drs: cd.drs)
                ))
            }
        }

        // Stint events (use lap start to approximate timestamp from laps)
        let lapStartTimes = buildLapStartTimes(from: laps)
        for s in stints {
            let lap = s.lapStart ?? 1
            if let date = lapStartTimes[lap] {
                events.append(ReplayEvent(timestamp: date, kind: .stint(s)))
            }
        }

        // Pit stop events
        for p in pitStops {
            if let date = lapStartTimes[p.lapNumber] {
                events.append(ReplayEvent(timestamp: date, kind: .pitStop(p)))
            }
        }

        // Sort by timestamp
        events.sort { $0.timestamp < $1.timestamp }

        // Determine lap boundaries
        let lapBoundaries = buildLapBoundaries(from: laps)
        let totalLaps = laps.map(\.lapNumber).max() ?? 0

        logger.info("Built timeline with \(events.count) events, \(totalLaps) laps")

        return ReplaySessionData(
            drivers: drivers,
            events: events,
            lapBoundaries: lapBoundaries,
            totalLaps: totalLaps,
            stints: stints
        )
    }

    /// Build a map of lap number → earliest timestamp for that lap.
    private func buildLapStartTimes(from laps: [HistoricalLap]) -> [Int: Date] {
        var times: [Int: Date] = [:]
        for l in laps {
            guard let dateStr = l.dateStart, let date = parseOpenF1Date(dateStr) else { continue }
            if let existing = times[l.lapNumber] {
                if date < existing { times[l.lapNumber] = date }
            } else {
                times[l.lapNumber] = date
            }
        }
        return times
    }

    /// Sample location data: keep every Nth point per driver to reduce event volume.
    private func samplePerDriver(_ locations: [HistoricalLocation], interval: Int) -> [HistoricalLocation] {
        var counters: [Int: Int] = [:]  // driverNumber → count
        return locations.filter { loc in
            let count = counters[loc.driverNumber, default: 0]
            counters[loc.driverNumber] = count + 1
            return count % interval == 0
        }
    }

    /// Sample car data: keep every Nth point per driver.
    private func sampleCarDataPerDriver(_ data: [HistoricalCarData], interval: Int) -> [HistoricalCarData] {
        var counters: [Int: Int] = [:]
        return data.filter { cd in
            let count = counters[cd.driverNumber, default: 0]
            counters[cd.driverNumber] = count + 1
            return count % interval == 0
        }
    }

    /// Build a map of lap number → (start timestamp, end timestamp).
    private func buildLapBoundaries(from laps: [HistoricalLap]) -> [Int: Date] {
        var earliest: [Int: Date] = [:]
        for l in laps {
            guard let dateStr = l.dateStart, let date = parseOpenF1Date(dateStr) else { continue }
            if let existing = earliest[l.lapNumber] {
                if date < existing { earliest[l.lapNumber] = date }
            } else {
                earliest[l.lapNumber] = date
            }
        }
        return earliest
    }
}

/// All data needed for a replay session.
struct ReplaySessionData {
    let drivers: [OpenF1Driver]
    let events: [ReplayEvent]
    let lapBoundaries: [Int: Date]  // lap number → earliest start time
    let totalLaps: Int
    let stints: [StintData]
}
