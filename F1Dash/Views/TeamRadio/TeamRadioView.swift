import SwiftUI

struct TeamRadioView: View {
    @Environment(LiveTimingStore.self) private var store

    var body: some View {
        List(recentCaptures) { capture in
            RadioMessageRow(capture: capture)
        }
        .listStyle(.plain)
        .overlay {
            if store.teamRadioCaptures.isEmpty {
                ContentUnavailableView(
                    "No Radio Messages",
                    systemImage: "headphones",
                    description: Text("Team radio messages will appear here during a session.")
                )
            }
        }
    }

    /// Last 20 captures, sorted by UTC descending (most recent first).
    private var recentCaptures: [RadioCapture] {
        Array(store.teamRadioCaptures.suffix(20).reversed())
    }
}
