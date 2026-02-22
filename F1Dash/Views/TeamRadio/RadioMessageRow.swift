import SwiftUI

struct RadioMessageRow: View {
    let capture: RadioCapture
    @Environment(LiveTimingStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            // Play/pause button
            Button {
                guard let sessionPath = store.sessionInfo?.sessionPath else { return }
                store.audioPlayer.toggle(capture: capture, sessionPath: sessionPath)
            } label: {
                Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isCurrentlyPlaying ? .red : .accentColor)
            }
            .buttonStyle(.plain)

            // Driver tag
            driverTag

            VStack(alignment: .leading, spacing: 2) {
                if let driver = store.drivers[capture.racingNumber] {
                    Text(driver.fullName)
                        .font(.body)
                } else {
                    Text("Driver #\(capture.racingNumber)")
                        .font(.body)
                }

                Text(DateFormatting.localTimeString(capture.utc))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Progress indicator when playing
            if isCurrentlyPlaying {
                ProgressView(value: store.audioPlayer.playbackProgress)
                    .frame(width: 80)
            }
        }
        .padding(.vertical, 4)
    }

    private var isCurrentlyPlaying: Bool {
        store.audioPlayer.currentRadioId == capture.id && store.audioPlayer.isPlaying
    }

    @ViewBuilder
    private var driverTag: some View {
        let driver = store.drivers[capture.racingNumber]
        let tla = driver?.tla ?? capture.racingNumber
        let color = driver?.color ?? .gray

        Text(tla)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
