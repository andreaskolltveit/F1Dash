import SwiftUI

/// Dashboard panel showing aggregated track violations per driver.
struct DashboardTrackViolationsView: View {
    @Environment(LiveTimingStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            if sortedViolations.isEmpty {
                Spacer()
                Text("No violations")
                    .font(.caption)
                    .foregroundStyle(F1Theme.textTertiary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedViolations) { violation in
                            TrackViolationRow(
                                violation: violation,
                                driver: store.drivers[violation.driverNumber]
                            )
                            Divider().overlay(F1Theme.border.opacity(0.3))
                        }
                    }
                }
            }
        }
        .f1Panel(title: "Track Violations")
    }

    private var sortedViolations: [TrackViolation] {
        store.trackViolations.values.sorted { $0.count > $1.count }
    }
}
