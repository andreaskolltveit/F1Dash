import SwiftUI

/// Compact race control panel for the dashboard with auto-scroll.
struct DashboardRaceControlView: View {
    @Environment(LiveTimingStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredMessages) { message in
                            CompactRaceControlRow(message: message)
                                .id(message.id)
                            Divider().overlay(F1Theme.border.opacity(0.3))
                        }
                    }
                }
                .onChange(of: store.raceControlMessages.count) { _, _ in
                    if let last = filteredMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .f1Panel(title: "Race Control")
    }

    private var filteredMessages: [RaceControlMessage] {
        if settings.filterBlueFlags {
            store.raceControlMessages.filter { !$0.isBlueFlag }
        } else {
            store.raceControlMessages
        }
    }
}
