import SwiftUI

/// Leaderboard panel for the dashboard. Shows all drivers with animated position changes.
struct DashboardLeaderboardView: View {
    @Environment(LiveTimingStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    /// Track previous positions to compute delta.
    @State private var previousPositions: [String: Int] = [:]
    /// Selected driver for detail sheet.
    @State private var selectedDriverNumber: String?

    var body: some View {
        VStack(spacing: 0) {
            LeaderboardHeaderRow(showMetrics: settings.showCarMetrics)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(store.driversSorted) { driver in
                        let driverNum = driver.id
                        let timing = store.timingData[driverNum]
                        let currentPos = Int(timing?.position ?? "0") ?? 0

                        LeaderboardRowView(
                            driver: driver,
                            timing: timing,
                            telemetry: store.carTelemetry[driverNum],
                            stint: store.currentStints[driverNum],
                            pitCount: store.pitStops[driverNum]?.count ?? 0,
                            currentLap: store.lapCount?.currentLap ?? 0,
                            showMetrics: settings.showCarMetrics,
                            hasFastestLap: isFastestLap(driverNum),
                            isFavorite: settings.favoriteDrivers.contains(driverNum),
                            positionDelta: computeDelta(driverNum: driverNum, currentPos: currentPos),
                            isCatching: isCatching(driverNum: driverNum, timing: timing)
                        )
                        .onTapGesture {
                            selectedDriverNumber = driverNum
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                        Divider().overlay(F1Theme.border.opacity(0.5))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.driversSorted.map(\.id))
            }
            .contentMargins(0)
            .scrollContentBackground(.hidden)
        }
        .f1Panel(title: "Leaderboard")
        .sheet(isPresented: Binding(
            get: { selectedDriverNumber != nil },
            set: { if !$0 { selectedDriverNumber = nil } }
        )) {
            if let driverNum = selectedDriverNumber {
                DriverDetailView(driverNumber: driverNum)
                    .environment(store)
            }
        }
        .onChange(of: store.lapCount?.currentLap) { _, _ in
            // Snapshot positions at each lap change
            var positions: [String: Int] = [:]
            for (key, td) in store.timingData {
                if let pos = Int(td.position ?? "") {
                    positions[key] = pos
                }
            }
            previousPositions = positions
        }
    }

    private func isFastestLap(_ driverNumber: String) -> Bool {
        guard let timing = store.timingData[driverNumber] else { return false }
        guard let bestLap = timing.bestLapTime else { return false }
        let allBestLaps = store.timingData.values.compactMap(\.bestLapTime)
        return bestLap == allBestLaps.min()
    }

    /// Compute position delta: positive means gained positions (moved up).
    private func computeDelta(driverNum: String, currentPos: Int) -> Int {
        guard currentPos > 0 else { return 0 }
        guard let prevPos = previousPositions[driverNum] else { return 0 }
        return prevPos - currentPos  // prev=5, current=3 → +2 (gained 2)
    }

    /// Check if driver is catching the car ahead (interval decreasing).
    private func isCatching(driverNum: String, timing: TimingDataDriver?) -> Bool {
        guard let interval = timing?.intervalToPositionAhead,
              interval.hasPrefix("+"),
              let value = Double(interval.dropFirst()) else { return false }
        return value < 1.0  // Within 1 second = catching
    }
}
