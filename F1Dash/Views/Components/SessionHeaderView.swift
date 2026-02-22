import SwiftUI

struct SessionHeaderView: View {
    @Environment(LiveTimingStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let info = store.sessionInfo {
                Text(info.meetingName)
                    .font(.headline)
                Text(info.sessionName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No Session")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                // Track status indicator
                Circle()
                    .fill(store.trackStatus.status.color)
                    .frame(width: 8, height: 8)
                Text(store.trackStatus.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Clock / Lap count
                if let clock = store.extrapolatedClock {
                    Text(clock.remaining)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let laps = store.lapCount, laps.totalLaps > 0 {
                    Text("Lap \(laps.currentLap)/\(laps.totalLaps)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
