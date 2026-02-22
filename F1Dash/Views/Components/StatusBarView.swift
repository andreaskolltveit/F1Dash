import SwiftUI

/// Top status bar showing session info, track status, laps, clock, weather, and connection.
struct StatusBarView: View {
    @Environment(LiveTimingStore.self) private var store
    @Environment(F1LiveTimingService.self) private var service
    var replayEngine: ReplayEngine?

    var body: some View {
        HStack(spacing: 16) {
            // Replay badge
            if let engine = replayEngine, engine.state.isActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.state == .playing ? F1Theme.red : F1Theme.textTertiary)
                        .frame(width: 6, height: 6)
                    Text("REPLAY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(F1Theme.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(F1Theme.red.opacity(0.15)))
                .transition(.scale.combined(with: .opacity))
            }

            // Session name with fade transition
            if let info = store.sessionInfo {
                Text("\(info.meetingCircuitShortName) — \(info.sessionName)")
                    .font(.caption.bold())
                    .foregroundStyle(F1Theme.textPrimary)
                    .transition(.scale.combined(with: .opacity))
            }

            // Track status pill with animated appearance
            trackStatusPill

            // Lap count with number transitions
            if let laps = store.lapCount, laps.totalLaps > 0 {
                HStack(spacing: 4) {
                    Text("LAP")
                        .font(.caption2.bold())
                        .foregroundStyle(F1Theme.textTertiary)
                    Text("\(laps.currentLap)/\(laps.totalLaps)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(F1Theme.textPrimary)
                        .contentTransition(.numericText())
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Clock with smooth number updates
            if let clock = store.extrapolatedClock {
                Text(clock.remaining)
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(F1Theme.textPrimary)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Weather with fade transitions
            weatherInfo

            // Connection with pulse effect
            connectionDot
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(
                    color: store.trackStatus.status == .allClear ? .clear : store.trackStatus.status.color.opacity(0.2),
                    radius: 12
                )
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.sessionInfo?.sessionName)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.lapCount?.currentLap)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.trackStatus.status)
    }

    @ViewBuilder
    private var trackStatusPill: some View {
        let status = store.trackStatus.status
        Text(status.displayName)
            .font(.caption2.bold())
            .foregroundStyle(status == .allClear ? F1Theme.textPrimary : .black)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(status.color.opacity(status == .allClear ? 0.3 : 0.9))
            }
            .overlay {
                if status != .allClear {
                    Capsule()
                        .strokeBorder(status.color, lineWidth: 1)
                        .opacity(0.5)
                }
            }
            .shadow(color: status.color.opacity(0.4), radius: status == .allClear ? 0 : 8, x: 0, y: 2)
            .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private var weatherInfo: some View {
        if let weather = store.weatherData {
            HStack(spacing: 10) {
                if let airTemp = weather.airTemp {
                    Label("\(airTemp, specifier: "%.0f")°", systemImage: "thermometer.medium")
                        .transition(.scale.combined(with: .opacity))
                }
                if let humidity = weather.humidity {
                    Label("\(humidity, specifier: "%.0f")%", systemImage: "humidity")
                        .transition(.scale.combined(with: .opacity))
                }
                if let wind = weather.windSpeed {
                    Label("\(wind, specifier: "%.1f")m/s", systemImage: "wind")
                        .transition(.scale.combined(with: .opacity))
                }
                if weather.rainfall {
                    Image(systemName: "cloud.rain.fill")
                        .foregroundStyle(F1Theme.blue)
                        .symbolEffect(.bounce, options: .repeating)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .font(.caption2)
            .foregroundStyle(F1Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var connectionDot: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 10, height: 10)
            .shadow(color: connectionColor.opacity(0.5), radius: 4, x: 0, y: 0)
            .symbolEffect(.pulse, options: .repeating, isActive: service.connectionState == .connecting || service.connectionState == .reconnecting)
    }

    private var connectionColor: Color {
        switch service.connectionState {
        case .connected: F1Theme.green
        case .connecting, .reconnecting: F1Theme.yellow
        case .disconnected: .gray
        case .error: F1Theme.red
        }
    }
}
