import Foundation
import os

/// Orchestrates the F1 Live Timing connection:
/// connect → subscribe → listen → route topics → detect session changes → reconnect
@MainActor
@Observable
final class F1LiveTimingService {
    private let logger = Logger(subsystem: "com.f1dash", category: "LiveTiming")
    private let client = SignalRClient()

    var connectionState: ConnectionState = .disconnected
    private var listenTask: Task<Void, Never>?
    private weak var store: LiveTimingStore?
    private var reconnectCount = 0
    private let maxReconnects = 10

    /// Delay buffer — sits between SignalR messages and the store.
    let delayBuffer = DelayBuffer()

    /// Start the service and connect to F1 Live Timing.
    func start(store: LiveTimingStore, settings: SettingsStore) {
        self.store = store
        delayBuffer.start(store: store)
        delayBuffer.delaySeconds = settings.delaySeconds
        connect()
    }

    /// Update the delay from settings (call when user changes setting).
    func updateDelay(_ seconds: Int) {
        delayBuffer.delaySeconds = seconds
        if seconds == 0 {
            delayBuffer.clear()
        }
    }

    /// Connect (or reconnect) to the F1 Live Timing feed.
    func connect() {
        listenTask?.cancel()
        listenTask = Task {
            await self.performConnect()
        }
    }

    /// Disconnect from the feed.
    func disconnect() {
        listenTask?.cancel()
        listenTask = nil
        Task { await client.disconnect() }
        delayBuffer.stop()
        connectionState = .disconnected
    }

    // MARK: - Private

    private func performConnect() async {
        connectionState = .connecting
        logger.info("Connecting to F1 Live Timing...")

        do {
            let (initialState, stream) = try await client.connect()

            // Clear buffers on new connection
            delayBuffer.clear()

            // Process initial state
            processInitialState(initialState)
            connectionState = .connected
            reconnectCount = 0
            logger.info("Connected successfully.")

            // Listen for updates
            for await message in stream {
                guard !Task.isCancelled else { break }
                routeMessage(topic: message.topic, data: message.data, timestamp: message.timestamp)
            }

            // Stream ended
            if !Task.isCancelled {
                logger.warning("Stream ended unexpectedly.")
                scheduleReconnect()
            }

        } catch {
            logger.error("Connection error: \(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
            scheduleReconnect()
        }
    }

    private func processInitialState(_ state: [String: Any]) {
        guard store != nil else { return }
        var processed: [String: Any] = [:]
        for (topic, data) in state {
            if (topic == "CarDataZ" || topic == "PositionZ"),
               let base64 = data as? String {
                let baseName = String(topic.dropLast(1)) // "CarData" / "Position"
                do {
                    processed[baseName] = try Decompressor.decompress(base64)
                } catch {
                    logger.error("Failed to decompress initial \(topic)")
                }
            } else {
                processed[topic] = data
            }
        }
        delayBuffer.pushInitialState(processed)
        logger.info("Processed initial state: \(processed.keys.joined(separator: ", "))")
    }

    private func routeMessage(topic: String, data: Any, timestamp: String?) {
        guard store != nil else { return }

        // Handle .z compressed topics
        let actualTopic: String
        let actualData: Any

        if topic.hasSuffix(".z"), let stringData = data as? String {
            actualTopic = String(topic.dropLast(2))  // Remove ".z"
            do {
                actualData = try Decompressor.decompress(stringData)
            } catch {
                logger.error("Decompression failed for \(topic): \(error.localizedDescription)")
                return
            }
        } else {
            actualTopic = topic
            actualData = data
        }

        // Push through delay buffer (passes directly if delay == 0)
        delayBuffer.push(topic: actualTopic, data: actualData)

        // Detect session change (always immediate, not delayed)
        if actualTopic == "SessionInfo",
           let dict = actualData as? [String: Any],
           dict.keys.contains("Name") || dict.keys.contains("Path") {
            logger.info("Session change detected — reconnecting in 2s...")
            Task {
                try? await Task.sleep(for: .seconds(2))
                connect()
            }
        }
    }

    private func scheduleReconnect() {
        guard reconnectCount < maxReconnects else {
            logger.error("Max reconnect attempts reached.")
            connectionState = .error("Max reconnect attempts reached")
            return
        }

        reconnectCount += 1
        let delay = min(Double(reconnectCount) * 2.0, 30.0)
        connectionState = .reconnecting

        logger.info("Reconnecting in \(delay)s (attempt \(self.reconnectCount))...")

        listenTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await performConnect()
        }
    }
}
