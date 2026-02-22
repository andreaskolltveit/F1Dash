import Foundation
import os

/// Timestamp-based delay buffer for F1 Live Timing data.
///
/// When delay is 0, messages pass through immediately.
/// When delay > 0, messages are buffered and released after the delay period.
/// Uses binary search for efficient historical lookup.
@MainActor
final class DelayBuffer {
    private let logger = Logger(subsystem: "com.f1dash", category: "DelayBuffer")

    /// A timestamped frame of merged raw state for a topic.
    private struct Frame {
        let timestamp: TimeInterval  // seconds since 1970
        let topic: String
        let data: Any
    }

    /// Per-topic merged state buffer (like useStatefulBuffer in f1-dash).
    /// Each frame is a full merged snapshot, not a delta.
    private var topicBuffers: [String: [Frame]] = [:]

    /// Per-topic running merged state (for stateful buffering).
    private var topicState: [String: Any] = [:]

    /// Timer that drains buffered data to the store.
    private var drainTimer: Timer?

    /// The store to write delayed data to.
    private weak var store: LiveTimingStore?

    /// Current delay in seconds. Updated from SettingsStore.
    var delaySeconds: Int = 0

    /// Maximum available delay based on buffer depth (seconds).
    var maxAvailableDelay: Int {
        var oldest: TimeInterval = Date().timeIntervalSince1970
        for (_, frames) in topicBuffers {
            if let first = frames.first {
                oldest = min(oldest, first.timestamp)
            }
        }
        return max(0, Int(Date().timeIntervalSince1970 - oldest))
    }

    /// How many seconds to keep beyond the delay point (cleanup margin).
    private let keepBufferSeconds: TimeInterval = 5.0

    /// Drain interval (200ms, same as f1-dash).
    private let drainInterval: TimeInterval = 0.2

    // MARK: - Lifecycle

    func start(store: LiveTimingStore) {
        self.store = store
        startDrainTimer()
    }

    func stop() {
        drainTimer?.invalidate()
        drainTimer = nil
        topicBuffers.removeAll()
        topicState.removeAll()
    }

    // MARK: - Push Data

    /// Push a topic update into the buffer.
    /// If delay is 0, passes directly to the store (no buffering overhead).
    func push(topic: String, data: Any) {
        guard delaySeconds > 0 else {
            // No delay — pass through immediately
            store?.mergeAndDecode(topic: topic, data: data)
            return
        }

        // Merge into running state for this topic (stateful buffer)
        topicState[topic] = StateMerger.merge(base: topicState[topic], update: data)

        // Store a full snapshot as a frame
        guard let merged = topicState[topic] else { return }
        let frame = Frame(
            timestamp: Date().timeIntervalSince1970,
            topic: topic,
            data: merged
        )

        if topicBuffers[topic] == nil {
            topicBuffers[topic] = []
        }
        topicBuffers[topic]!.append(frame)
    }

    /// Push initial state (full state, not delta).
    func pushInitialState(_ state: [String: Any]) {
        guard delaySeconds > 0 else {
            // No delay — load directly
            for (topic, data) in state {
                store?.updateRawState(topic: topic, data: data)
            }
            store?.decodeAllFromRawState()
            return
        }

        let now = Date().timeIntervalSince1970
        for (topic, data) in state {
            topicState[topic] = data
            let frame = Frame(timestamp: now, topic: topic, data: data)
            topicBuffers[topic] = [frame]
        }
    }

    // MARK: - Drain (Timer Callback)

    private func startDrainTimer() {
        drainTimer?.invalidate()
        drainTimer = Timer.scheduledTimer(withTimeInterval: drainInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.drain()
            }
        }
    }

    /// Apply delayed data to the store and clean up old frames.
    private func drain() {
        guard delaySeconds > 0, let store else { return }

        let delayedTimestamp = Date().timeIntervalSince1970 - Double(delaySeconds)

        for (topic, frames) in topicBuffers {
            guard !frames.isEmpty else { continue }

            // Binary search for the latest frame at or before delayedTimestamp
            if let frame = binarySearch(frames: frames, target: delayedTimestamp) {
                store.updateRawState(topic: topic, data: frame.data)
                store.decodeTopic(topic)
            }
        }

        // Cleanup old frames (keep 5s margin before delay point)
        cleanup(delayedTimestamp: delayedTimestamp)
    }

    // MARK: - Binary Search

    /// Find the latest frame with timestamp <= target.
    private func binarySearch(frames: [Frame], target: TimeInterval) -> Frame? {
        guard !frames.isEmpty else { return nil }

        // All frames are newer than target
        if frames[0].timestamp > target { return nil }

        // All frames are older than target — return last
        if frames[frames.count - 1].timestamp <= target {
            return frames[frames.count - 1]
        }

        var left = 0
        var right = frames.count - 1

        while left <= right {
            let mid = (left + right) / 2

            if frames[mid].timestamp <= target &&
                (mid == frames.count - 1 || frames[mid + 1].timestamp > target) {
                return frames[mid]
            }

            if frames[mid].timestamp <= target {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        return nil
    }

    // MARK: - Cleanup

    /// Remove frames older than delayedTimestamp - keepBufferSeconds.
    private func cleanup(delayedTimestamp: TimeInterval) {
        let threshold = delayedTimestamp - keepBufferSeconds

        for topic in topicBuffers.keys {
            guard var frames = topicBuffers[topic], frames.count > 1 else { continue }

            // Find first frame after threshold
            var cutIndex = 0
            while cutIndex < frames.count && frames[cutIndex].timestamp <= threshold {
                cutIndex += 1
            }

            // Keep at least one frame before the cut point
            if cutIndex > 0 && cutIndex < frames.count {
                frames = Array(frames[(cutIndex - 1)...])
            } else if cutIndex >= frames.count {
                frames = [frames[frames.count - 1]]
            }

            topicBuffers[topic] = frames
        }
    }

    // MARK: - State Management

    /// Clear all buffers (e.g. on session change or disconnect).
    func clear() {
        topicBuffers.removeAll()
        topicState.removeAll()
    }
}

