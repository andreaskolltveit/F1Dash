import SwiftUI

/// Compact team radio panel for the dashboard.
struct DashboardTeamRadioView: View {
    @Environment(LiveTimingStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(recentCaptures) { capture in
                        CompactRadioRow(capture: capture)
                            .id(capture.id)
                        Divider().overlay(F1Theme.border.opacity(0.3))
                    }
                }
            }
        }
        .f1Panel(title: "Team Radio")
    }

    private var recentCaptures: [RadioCapture] {
        Array(store.teamRadioCaptures.suffix(20).reversed())
    }
}
