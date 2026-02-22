import Foundation
import os

/// Service that polls the OpenF1 API for stint and pit stop data.
/// Graceful: the app works without OpenF1 data — stints/pitstops are optional enrichment.
@Observable
final class OpenF1Service {
    private let logger = Logger(subsystem: "com.f1dash", category: "OpenF1Service")
    private let client = OpenF1Client()
    private var pollTask: Task<Void, Never>?
    private weak var store: LiveTimingStore?
    private(set) var isPolling = false

    /// Start polling for a session key.
    func start(store: LiveTimingStore, sessionKey: Int) {
        self.store = store
        stopPolling()
        isPolling = true
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.poll(sessionKey: sessionKey)
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    /// Stop polling.
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    @MainActor
    private func poll(sessionKey: Int) async {
        guard let store else { return }

        // Fetch stints
        do {
            let stints = try await client.fetchStints(sessionKey: sessionKey)
            var current: [String: StintData] = [:]
            for stint in stints {
                let key = "\(stint.driverNumber)"
                // Keep the latest stint (highest stint number) per driver
                if let existing = current[key], existing.stintNumber >= stint.stintNumber {
                    continue
                }
                current[key] = stint
            }
            store.currentStints = current
        } catch {
            logger.debug("Stint fetch failed (non-fatal): \(error.localizedDescription)")
        }

        // Fetch pit stops
        do {
            let pitStops = try await client.fetchPitStops(sessionKey: sessionKey)
            var grouped: [String: [PitStopData]] = [:]
            for stop in pitStops {
                let key = "\(stop.driverNumber)"
                grouped[key, default: []].append(stop)
            }
            store.pitStops = grouped
        } catch {
            logger.debug("Pit stop fetch failed (non-fatal): \(error.localizedDescription)")
        }
    }
}
