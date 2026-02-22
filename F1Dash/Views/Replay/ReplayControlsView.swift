import SwiftUI

/// Transport controls for replay: play/pause, speed, lap slider, elapsed time.
struct ReplayControlsView: View {
    @Bindable var replayEngine: ReplayEngine

    var body: some View {
        VStack(spacing: 0) {
            // Session info bar
            sessionInfoBar

            Divider().overlay(F1Theme.border)

            // Transport controls
            transportBar
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Session Info

    @ViewBuilder
    private var sessionInfoBar: some View {
        HStack(spacing: 12) {
            // Replay badge
            HStack(spacing: 6) {
                Circle()
                    .fill(replayEngine.state == .playing ? F1Theme.red : F1Theme.textTertiary)
                    .frame(width: 8, height: 8)
                    .overlay {
                        if replayEngine.state == .playing {
                            Circle()
                                .fill(F1Theme.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(2)
                                .opacity(0)
                                .animation(
                                    .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                    value: replayEngine.state
                                )
                        }
                    }
                Text("REPLAY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(F1Theme.red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(F1Theme.red.opacity(0.15))
            )

            // Session name
            if let session = replayEngine.selectedSession {
                Text("\(session.circuitShortName ?? "") — \(session.sessionName)")
                    .font(.caption.bold())
                    .foregroundStyle(F1Theme.textPrimary)

                Text("\(session.year)")
                    .font(.caption)
                    .foregroundStyle(F1Theme.textSecondary)
            }

            Spacer()

            // Elapsed time
            Text(replayEngine.elapsedText)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(F1Theme.textSecondary)

            // Stop button
            Button {
                replayEngine.stop()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(F1Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Stop Replay")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Transport Bar

    @ViewBuilder
    private var transportBar: some View {
        HStack(spacing: 16) {
            // Play / Pause
            Button {
                if replayEngine.state == .playing {
                    replayEngine.pause()
                } else {
                    replayEngine.play()
                }
            } label: {
                Image(systemName: replayEngine.state == .playing ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(F1Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            // Lap slider
            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { Double(replayEngine.currentLap) },
                        set: { replayEngine.seekToLap(Int($0)) }
                    ),
                    in: 1...max(Double(replayEngine.totalLaps), 2),
                    step: 1
                )
                .tint(F1Theme.red)

                HStack {
                    Text("LAP \(replayEngine.currentLap)/\(replayEngine.totalLaps)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(F1Theme.textSecondary)
                    Spacer()
                }
            }

            // Speed selector
            HStack(spacing: 4) {
                ForEach(ReplaySpeed.allCases) { speed in
                    Button {
                        replayEngine.speed = speed
                    } label: {
                        Text(speed.label)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(replayEngine.speed == speed ? .white : F1Theme.textTertiary)
                            .frame(width: 32, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(replayEngine.speed == speed ? F1Theme.red : F1Theme.elevated)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
