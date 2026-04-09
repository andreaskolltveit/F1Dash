import Foundation
import os

/// Loads historical session data from OpenF1 and builds a sorted timeline of ReplayEvents.
actor ReplayDataLoader {
    private let logger = Logger(subsystem: "com.f1dash", category: "ReplayLoader")
    private let client = OpenF1Client()

    /// Load essential data for a session (fast — no per-driver bulk endpoints).
    /// Returns a timeline ready for playback within ~6 seconds.
    func loadEssentialData(sessionKey: Int) async throws -> ReplaySessionData {
        logger.info("Loading essential replay data for session \(sessionKey)")

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

        logger.info("Loaded essential: \(drivers.count) drivers, \(positions.count) positions, \(laps.count) laps, \(intervals.count) intervals, \(raceControl.count) RC msgs, \(stints.count) stints, \(pitStops.count) pit stops, \(teamRadio.count) radio, \(weather.count) weather")

        // Build timeline from essential data
        var events = buildEssentialEvents(
            positions: positions, laps: laps, intervals: intervals,
            raceControl: raceControl, teamRadio: teamRadio, weather: weather,
            stints: stints, pitStops: pitStops
        )

        events.sort { $0.timestamp < $1.timestamp }

        let lapBoundaries = buildLapBoundaries(from: laps)
        let totalLaps = laps.map(\.lapNumber).max() ?? 0

        logger.info("Built essential timeline with \(events.count) events, \(totalLaps) laps")

        return ReplaySessionData(
            drivers: drivers,
            events: events,
            lapBoundaries: lapBoundaries,
            totalLaps: totalLaps,
            stints: stints
        )
    }

    /// Load enrichment data (location + car telemetry) — called in background after replay is ready.
    func loadEnrichmentData(sessionKey: Int, driverNumbers: [Int]) async throws -> [ReplayEvent] {
        logger.info("Loading enrichment data for \(driverNumbers.count) drivers")

        var events: [ReplayEvent] = []

        for num in driverNumbers {
            // Location data
            do {
                let locs = try await client.fetchLocations(sessionKey: sessionKey, driverNumber: num)
                let sampled = samplePerDriver(locs, interval: 4)
                for loc in sampled {
                    if let date = parseOpenF1Date(loc.date) {
                        events.append(ReplayEvent(
                            timestamp: date,
                            kind: .location(driverNumber: loc.driverNumber, x: loc.x, y: loc.y, z: loc.z)
                        ))
                    }
                }
                logger.debug("Location loaded for driver \(num): \(locs.count) → \(sampled.count) sampled")
            } catch {
                logger.warning("Location fetch failed for driver \(num) (non-fatal): \(error.localizedDescription)")
            }

            // Car telemetry data
            do {
                let carData = try await client.fetchCarData(sessionKey: sessionKey, driverNumber: num)
                let sampled = sampleCarDataPerDriver(carData, interval: 10)
                for cd in sampled {
                    if let date = parseOpenF1Date(cd.date) {
                        events.append(ReplayEvent(
                            timestamp: date,
                            kind: .carData(driverNumber: cd.driverNumber, speed: cd.speed, rpm: cd.rpm,
                                           gear: cd.gear, throttle: cd.throttle, brake: cd.brake, drs: cd.drs)
                        ))
                    }
                }
                logger.debug("Car data loaded for driver \(num): \(carData.count) → \(sampled.count) sampled")
            } catch {
                logger.warning("Car data fetch failed for driver \(num) (non-fatal): \(error.localizedDescription)")
            }
        }

        logger.info("Enrichment complete: \(events.count) events")
        return events
    }

    /// Load all data for a session and build a sorted timeline (legacy — full blocking load).
    func loadSession(sessionKey: Int) async throws -> ReplaySessionData {
        let data = try await loadEssentialData(sessionKey: sessionKey)

        // Also load enrichment inline
        let driverNumbers = data.drivers.map(\.driverNumber)
        let enrichment = try await loadEnrichmentData(sessionKey: sessionKey, driverNumbers: driverNumbers)

        var allEvents = data.events
        allEvents.append(contentsOf: enrichment)
        allEvents.sort { $0.timestamp < $1.timestamp }

        return ReplaySessionData(
            drivers: data.drivers,
            events: allEvents,
            lapBoundaries: data.lapBoundaries,
            totalLaps: data.totalLaps,
            stints: data.stints
        )
    }

    // MARK: - Event Building

    private func buildEssentialEvents(
        positions: [HistoricalPosition], laps: [HistoricalLap],
        intervals: [HistoricalInterval], raceControl: [HistoricalRaceControl],
        teamRadio: [HistoricalTeamRadio], weather: [HistoricalWeather],
        stints: [StintData], pitStops: [PitStopData]
    ) -> [ReplayEvent] {
        var events: [ReplayEvent] = []

        for p in positions {
            if let date = parseOpenF1Date(p.date) {
                events.append(ReplayEvent(
                    timestamp: date,
                    kind: .position(driverNumber: p.driverNumber, position: p.position)
                ))
            }
        }

        for l in laps {
            if let dateStr = l.dateStart, let date = parseOpenF1Date(dateStr) {
                events.append(ReplayEvent(timestamp: date, kind: .lap(l)))
            }
        }

        for i in intervals {
            if let date = parseOpenF1Date(i.date) {
                events.append(ReplayEvent(
                    timestamp: date,
                    kind: .interval(driverNumber: i.driverNumber, gapToLeader: i.gapToLeader, gapToLeaderText: i.gapToLeaderText, interval: i.interval, intervalText: i.intervalText)
                ))
            }
        }

        for rc in raceControl {
            if let date = parseOpenF1Date(rc.date) {
                events.append(ReplayEvent(timestamp: date, kind: .raceControl(rc)))
            }
        }

        for tr in teamRadio {
            if let date = parseOpenF1Date(tr.date) {
                events.append(ReplayEvent(
                    timestamp: date,
                    kind: .teamRadio(driverNumber: tr.driverNumber, recordingUrl: tr.recordingUrl)
                ))
            }
        }

        for w in weather {
            if let date = parseOpenF1Date(w.date) {
                events.append(ReplayEvent(timestamp: date, kind: .weather(w)))
            }
        }

        // Stint + pit events use lap start times
        let lapStartTimes = buildLapStartTimes(from: laps)
        for s in stints {
            let lap = s.lapStart ?? 1
            if let date = lapStartTimes[lap] {
                events.append(ReplayEvent(timestamp: date, kind: .stint(s)))
            }
        }
        for p in pitStops {
            if let date = lapStartTimes[p.lapNumber] {
                events.append(ReplayEvent(timestamp: date, kind: .pitStop(p)))
            }
        }

        return events
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
