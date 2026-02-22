import SwiftUI

/// Compact track map panel for the dashboard.
struct DashboardTrackMapView: View {
    @Environment(LiveTimingStore.self) private var store

    // Interpolation state
    @State private var fromPositions: [String: DriverPosition] = [:]
    @State private var toPositions: [String: DriverPosition] = [:]
    @State private var interpolationStart: Date = .distantPast
    @State private var interpolationDuration: TimeInterval = 0.3

    var body: some View {
        Group {
            if let trackMap = store.trackMap {
                TimelineView(.animation(minimumInterval: 1.0/60.0, paused: store.driverPositions.isEmpty)) { timeline in
                    Canvas { context, size in
                        let displayPositions: [String: DriverPosition]
                        if toPositions.isEmpty {
                            displayPositions = store.driverPositions
                        } else {
                            let progress = interpolationDuration > 0
                                ? min(1.0, timeline.date.timeIntervalSince(interpolationStart) / interpolationDuration)
                                : 1.0
                            displayPositions = TrackMapRenderer.interpolatePositions(
                                from: fromPositions, to: toPositions, progress: progress
                            )
                        }

                        TrackMapRenderer.drawTrack(
                            context: context, size: size,
                            map: trackMap, trackStatus: store.trackStatus
                        )
                        TrackMapRenderer.drawDriverPositions(
                            context: context, map: trackMap, size: size,
                            driverPositions: displayPositions,
                            drivers: store.drivers,
                            dotSize: 10,
                            showLabels: true
                        )
                    }
                }
                .padding(20)
            } else {
                ContentUnavailableView(
                    "No Track Map",
                    systemImage: "map",
                    description: Text("Waiting for session data...")
                )
            }
        }
        .f1Panel(title: "Track Map")
        .onChange(of: store.driverPositions, initial: true) { oldVal, newVal in
            let now = Date()
            let timeSinceLast = now.timeIntervalSince(interpolationStart)
            interpolationDuration = min(max(timeSinceLast, 0.1), 1.0)
            fromPositions = toPositions.isEmpty ? newVal : toPositions
            toPositions = newVal
            interpolationStart = now
        }
    }
}
