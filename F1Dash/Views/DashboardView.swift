import SwiftUI

/// All-in-one dashboard showing leaderboard, track map, race control, team radio, and track violations.
struct DashboardView: View {
    @Environment(LiveTimingStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    var replayEngine: ReplayEngine?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                // Status Bar (fixed height)
                StatusBarView(replayEngine: replayEngine)
                    .frame(height: 36)
                    .transition(.move(edge: .top).combined(with: .opacity))

                // Top row: Leaderboard + Track Map
                HStack(spacing: 4) {
                    DashboardLeaderboardView()
                        .frame(width: geo.size.width * 0.65)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    DashboardTrackMapView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .frame(height: (geo.size.height - 44) * 0.6)

                // Bottom row: Race Control + Team Radio + Track Violations + Weather
                HStack(spacing: 4) {
                    DashboardRaceControlView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    DashboardTeamRadioView()
                        .transition(.scale.combined(with: .opacity))
                    DashboardTrackViolationsView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    DashboardWeatherView()
                        .frame(width: geo.size.width * 0.18)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(F1Theme.background)
    }
}
