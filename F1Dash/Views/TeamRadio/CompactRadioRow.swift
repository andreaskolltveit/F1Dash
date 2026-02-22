import SwiftUI

/// Compact radio message row for the dashboard panel.
struct CompactRadioRow: View {
    let capture: RadioCapture
    @Environment(LiveTimingStore.self) private var store

    var body: some View {
        HStack(spacing: 6) {
            // Play button
            Button {
                guard let sessionPath = store.sessionInfo?.sessionPath else { return }
                store.audioPlayer.toggle(capture: capture, sessionPath: sessionPath)
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isPlaying ? F1Theme.red : F1Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 16)

            // Driver TLA in team color
            let driver = store.drivers[capture.racingNumber]
            Text(driver?.tla ?? capture.racingNumber)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(driver?.color ?? .gray)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Driver name
            Text(driver?.lastName ?? "")
                .font(.system(size: 11))
                .foregroundStyle(F1Theme.textSecondary)
                .lineLimit(1)

            Spacer()

            // Time
            Text(DateFormatting.localTimeString(capture.utc))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(F1Theme.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    private var isPlaying: Bool {
        store.audioPlayer.currentRadioId == capture.id && store.audioPlayer.isPlaying
    }
}
