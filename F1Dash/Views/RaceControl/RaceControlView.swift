import SwiftUI

struct RaceControlView: View {
    @Environment(LiveTimingStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        ScrollViewReader { proxy in
            List(filteredMessages) { message in
                RaceControlMessageRow(message: message)
                    .id(message.id)
            }
            .listStyle(.plain)
            .onChange(of: store.raceControlMessages.count) { _, _ in
                // Auto-scroll to latest
                if let last = filteredMessages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .overlay {
                if filteredMessages.isEmpty {
                    ContentUnavailableView(
                        "No Messages",
                        systemImage: "flag.2.crossed",
                        description: Text("Race control messages will appear here during a session.")
                    )
                }
            }
        }
    }

    private var filteredMessages: [RaceControlMessage] {
        if settings.filterBlueFlags {
            store.raceControlMessages.filter { !$0.isBlueFlag }
        } else {
            store.raceControlMessages
        }
    }
}
