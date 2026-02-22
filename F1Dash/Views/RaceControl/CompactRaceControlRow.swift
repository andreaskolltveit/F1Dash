import SwiftUI

/// Compact single-line race control message for the dashboard panel.
struct CompactRaceControlRow: View {
    let message: RaceControlMessage

    var body: some View {
        HStack(spacing: 6) {
            // Flag indicator
            if let flag = message.flag {
                Circle()
                    .fill(flag.color)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(F1Theme.textTertiary)
                    .frame(width: 8, height: 8)
            }

            // Message text
            Text(message.message)
                .font(.system(size: 11))
                .foregroundStyle(F1Theme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Lap
            if let lap = message.lap {
                Text("L\(lap)")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(F1Theme.textTertiary)
            }

            // Time
            Text(DateFormatting.localTimeString(message.utc))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(F1Theme.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}
