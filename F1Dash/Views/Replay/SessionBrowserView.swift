import SwiftUI

/// Browse and select historical F1 sessions for replay.
struct SessionBrowserView: View {
    @Environment(LiveTimingStore.self) private var store
    @Bindable var replayEngine: ReplayEngine
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date()) - 1
    @State private var selectedMeeting: String?
    @State private var hoveredSession: OpenF1Session?

    private let availableYears = Array((2023...Calendar.current.component(.year, from: Date())).reversed())

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().overlay(F1Theme.border)

            // Content
            switch replayEngine.state {
            case .loading:
                loadingView
            case .error(let message):
                errorView(message)
            case .ready, .playing, .paused, .finished:
                // Show replay controls when session is loaded
                ReplayControlsView(replayEngine: replayEngine)
            default:
                sessionList
            }
        }
        .background(F1Theme.background)
        .task {
            if replayEngine.availableSessions.isEmpty {
                await replayEngine.loadSessions(year: selectedYear)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(F1Theme.red)

            Text("Race Replay")
                .font(.title3.bold())
                .foregroundStyle(F1Theme.textPrimary)

            Spacer()

            // Year picker
            Picker("Year", selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .onChange(of: selectedYear) { _, newYear in
                Task { await replayEngine.loadSessions(year: newYear) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Session List

    @ViewBuilder
    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(groupedSessions, id: \.key) { meeting, sessions in
                    meetingSection(meeting: meeting, sessions: sessions)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func meetingSection(meeting: String, sessions: [OpenF1Session]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Meeting header
            HStack(spacing: 8) {
                if let first = sessions.first, let code = first.countryCode {
                    Text(flagEmoji(for: code))
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting)
                        .font(.headline)
                        .foregroundStyle(F1Theme.textPrimary)
                    if let first = sessions.first, let circuit = first.circuitShortName {
                        Text(circuit)
                            .font(.caption)
                            .foregroundStyle(F1Theme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Session buttons
            HStack(spacing: 6) {
                ForEach(sessions) { session in
                    sessionButton(session)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(F1Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func sessionButton(_ session: OpenF1Session) -> some View {
        Button {
            Task {
                await replayEngine.loadSession(session, store: store)
            }
        } label: {
            VStack(spacing: 4) {
                Text(sessionAbbreviation(session.sessionName))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(sessionColor(session.sessionType ?? ""))

                if let date = session.startDate {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9))
                        .foregroundStyle(F1Theme.textTertiary)
                }
            }
            .frame(width: 60, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hoveredSession == session ? F1Theme.elevated : F1Theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        hoveredSession == session ? sessionColor(session.sessionType ?? "") : F1Theme.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredSession = isHovered ? session : nil
        }
    }

    // MARK: - Loading / Error

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(replayEngine.loadingProgress ?? "Loading session data...")
                .font(.headline)
                .foregroundStyle(F1Theme.textSecondary)
            Spacer()
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(F1Theme.red)
            Text(message)
                .font(.body)
                .foregroundStyle(F1Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await replayEngine.loadSessions(year: selectedYear) }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    /// Group sessions by meeting name, preserving chronological order.
    private var groupedSessions: [(key: String, value: [OpenF1Session])] {
        var seen: [String: [OpenF1Session]] = [:]
        var order: [String] = []
        for session in replayEngine.availableSessions {
            let name = session.displayName
            if seen[name] == nil {
                order.append(name)
            }
            seen[name, default: []].append(session)
        }
        return order.map { (key: $0, value: seen[$0]!) }
    }

    private func sessionAbbreviation(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("practice 1"): return "FP1"
        case let n where n.contains("practice 2"): return "FP2"
        case let n where n.contains("practice 3"): return "FP3"
        case let n where n.contains("sprint shoot"): return "SSQ"
        case let n where n.contains("sprint qual"): return "SQ"
        case let n where n.contains("sprint"): return "SPR"
        case let n where n.contains("qualifying"): return "Q"
        case let n where n.contains("race"): return "RACE"
        default: return String(name.prefix(4)).uppercased()
        }
    }

    private func sessionColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "race": F1Theme.red
        case "qualifying": F1Theme.yellow
        case "practice": F1Theme.green
        case "sprint", "sprint_qualifying", "sprint_shootout": F1Theme.blue
        default: F1Theme.textSecondary
        }
    }

    private func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 0x1F1E6 - 65  // 🇦 offset
        let scalars = countryCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value)
        }
        return String(scalars.map { Character($0) })
    }
}
