import SwiftUI

struct TrackMapView: View {
    @Environment(LiveTimingStore.self) private var store
    @State private var isLoading = false
    @State private var zoom: CGFloat = 1.0
    @State private var trackWidth: CGFloat = 14

    // Interpolation state
    @State private var fromPositions: [String: DriverPosition] = [:]
    @State private var toPositions: [String: DriverPosition] = [:]
    @State private var interpolationStart: Date = .distantPast
    @State private var interpolationDuration: TimeInterval = 0.3

    private let zoomRange: ClosedRange<CGFloat> = 0.5...2.5
    private let widthRange: ClosedRange<CGFloat> = 4...30
    private let zoomStep: CGFloat = 0.15

    var body: some View {
        HStack(spacing: 0) {
            // Mini leaderboard
            miniLeaderboard
                .frame(width: 140)

            Divider().overlay(F1Theme.border)

            // Track map
            ZStack {
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
                                map: trackMap, trackStatus: store.trackStatus,
                                zoom: zoom, trackWidth: trackWidth
                            )
                            TrackMapRenderer.drawDriverPositions(
                                context: context, map: trackMap, size: size,
                                driverPositions: displayPositions,
                                drivers: store.drivers,
                                zoom: zoom
                            )
                        }
                    }
                    .padding(30)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))

                    // Zoom controls overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            zoomControls
                        }
                    }
                    .padding(16)
                } else {
                    ContentUnavailableView {
                        Label("No Track Map", systemImage: "map")
                    } description: {
                        Text("Track map will load when a session is active.")
                            .foregroundStyle(.secondary)
                    } actions: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.top, 8)
                        }
                    }
                    .symbolEffect(.pulse, options: .repeating, isActive: isLoading)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .background(F1Theme.background)
        .onChange(of: store.driverPositions, initial: true) { oldVal, newVal in
            let now = Date()
            let timeSinceLast = now.timeIntervalSince(interpolationStart)
            interpolationDuration = min(max(timeSinceLast, 0.1), 1.0)
            fromPositions = toPositions.isEmpty ? newVal : toPositions
            toPositions = newVal
            interpolationStart = now
        }
        .onChange(of: store.sessionInfo?.meetingCircuitKey) { _, newValue in
            isLoading = newValue != nil && store.trackMap == nil
        }
        .onChange(of: store.trackMap != nil) { _, hasMap in
            if hasMap {
                isLoading = false
            }
        }
    }

    // MARK: - Mini Leaderboard

    @ViewBuilder
    private var miniLeaderboard: some View {
        VStack(spacing: 0) {
            Text("STANDINGS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(F1Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            Divider().overlay(F1Theme.border.opacity(0.5))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(store.driversSorted) { driver in
                        let timing = store.timingData[driver.id]
                        let pos = timing?.position ?? "\(driver.line)"

                        HStack(spacing: 6) {
                            Text(pos)
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundStyle(F1Theme.textTertiary)
                                .frame(width: 18, alignment: .trailing)

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(driver.color)
                                .frame(width: 3, height: 14)

                            Text(driver.tla)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(F1Theme.textPrimary)

                            Spacer()

                            if let gap = timing?.intervalToPositionAhead, !gap.isEmpty {
                                Text(gap)
                                    .font(.system(size: 9).monospacedDigit())
                                    .foregroundStyle(F1Theme.textTertiary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .background(F1Theme.surface)
    }

    // MARK: - Zoom Controls

    @ViewBuilder
    private var zoomControls: some View {
        VStack(spacing: 0) {
            // Zoom in
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    zoom = min(zoom + zoomStep, zoomRange.upperBound)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(zoom >= zoomRange.upperBound)

            Divider()
                .frame(width: 20)
                .overlay(F1Theme.border)

            // Zoom out
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    zoom = max(zoom - zoomStep, zoomRange.lowerBound)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(zoom <= zoomRange.lowerBound)

            Divider()
                .frame(width: 20)
                .overlay(F1Theme.border)

            // Track width toggle
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    // Cycle: thin → medium → thick → thin
                    if trackWidth < 10 {
                        trackWidth = 14
                    } else if trackWidth < 22 {
                        trackWidth = 24
                    } else {
                        trackWidth = 6
                    }
                }
            } label: {
                Image(systemName: "road.lanes")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(width: 20)
                .overlay(F1Theme.border)

            // Reset
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    zoom = 1.0
                    trackWidth = 14
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(zoom == 1.0 && trackWidth == 14)
        }
        .foregroundStyle(F1Theme.textSecondary)
        .background(F1Theme.surface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(F1Theme.border, lineWidth: 1)
        )
    }
}
