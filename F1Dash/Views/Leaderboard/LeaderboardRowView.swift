import SwiftUI

/// A single row in the dashboard leaderboard.
struct LeaderboardRowView: View {
    let driver: Driver
    let timing: TimingDataDriver?
    let telemetry: CarTelemetry?
    let stint: StintData?
    let pitCount: Int
    let currentLap: Int
    let showMetrics: Bool
    let hasFastestLap: Bool
    let isFavorite: Bool
    let positionDelta: Int   // positive = gained, negative = lost, 0 = same
    let isCatching: Bool     // faster than car ahead

    var body: some View {
        HStack(spacing: 0) {
            // Driver tag pill (team-colored with position + TLA)
            driverTagPill
                .frame(width: 80)

            // Position delta indicator
            positionDeltaView
                .frame(width: 28)

            // Tire compound
            tireView
                .frame(width: 44)

            // DRS / PIT / OUT status (bordered box)
            drsStatusBox
                .frame(width: 48)

            // Gap: interval (large) over gap-to-leader (small)
            gapStack
                .frame(width: 80, alignment: .trailing)

            // Lap time: last lap (large) over best lap (small)
            lapTimeStack
                .frame(width: 90, alignment: .trailing)

            // Mini sectors (compact)
            miniSectors
                .frame(width: 84)

            // Pit count
            if pitCount > 0 {
                Text("\(pitCount)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(.cyan)
                    .frame(width: 20)
            } else {
                Color.clear.frame(width: 20)
            }

            // Car metrics (optional)
            if showMetrics {
                Text(telemetry.map { "\($0.speed)" } ?? "")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(F1Theme.textTertiary)
                    .frame(width: 40, alignment: .trailing)

                Text(telemetry.map { "\($0.gear)" } ?? "")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(F1Theme.textTertiary)
                    .frame(width: 22)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            // Favorite glow indicator
            if isFavorite {
                RoundedRectangle(cornerRadius: 2)
                    .fill(F1Theme.yellow)
                    .frame(width: 3)
                    .padding(.vertical, 2)
            }
        }
        .overlay(alignment: .trailing) {
            // Catching indicator
            if isCatching {
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(F1Theme.green)
                    .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Position Delta

    @ViewBuilder
    private var positionDeltaView: some View {
        if positionDelta > 0 {
            HStack(spacing: 1) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 6))
                Text("\(positionDelta)")
                    .font(.system(size: 8, weight: .bold).monospacedDigit())
            }
            .foregroundStyle(F1Theme.green)
        } else if positionDelta < 0 {
            HStack(spacing: 1) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 6))
                Text("\(abs(positionDelta))")
                    .font(.system(size: 8, weight: .bold).monospacedDigit())
            }
            .foregroundStyle(F1Theme.red)
        } else {
            Color.clear
        }
    }

    // MARK: - Driver Tag Pill

    @ViewBuilder
    private var driverTagPill: some View {
        HStack(spacing: 0) {
            // Position number (white, bold)
            Text(timing?.position ?? "-")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 24)

            // TLA in white rounded box with team-color text
            Text(driver.tla)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(driver.color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(driver.color)
        )
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var tireView: some View {
        if let stint {
            let compound = stint.compound
            HStack(spacing: 3) {
                Circle()
                    .fill(compound.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Text(compound.abbreviation)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.black)
                    )
                Text("\(stint.currentAge(currentLap: currentLap))")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(F1Theme.textTertiary)
            }
        }
    }

    // MARK: - DRS / Status Bordered Box

    @ViewBuilder
    private var drsStatusBox: some View {
        if let timing {
            if timing.retired {
                borderedBox("RET", borderColor: F1Theme.red, textColor: F1Theme.red)
            } else if timing.stopped {
                borderedBox("STOP", borderColor: F1Theme.red, textColor: F1Theme.red)
            } else if timing.inPit {
                borderedBox("PIT", borderColor: .cyan, textColor: .cyan)
            } else if timing.pitOut {
                borderedBox("OUT", borderColor: .cyan, textColor: .cyan)
            } else if let drs = telemetry?.drs {
                if drs.isOpen {
                    borderedBox("DRS", borderColor: F1Theme.green, textColor: F1Theme.green)
                } else if drs == .eligible || drs == .possible {
                    borderedBox("DRS", borderColor: .gray, textColor: .gray)
                } else {
                    borderedBox("DRS", borderColor: F1Theme.border, textColor: F1Theme.border)
                }
            }
        }
    }

    @ViewBuilder
    private func borderedBox(_ text: String, borderColor: Color, textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(textColor)
            .frame(width: 36, height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 2)
            )
    }

    // MARK: - Gap Stack (interval + gap-to-leader)

    @ViewBuilder
    private var gapStack: some View {
        if let timing {
            VStack(alignment: .trailing, spacing: 1) {
                // Interval to position ahead (primary, larger)
                Text(timing.intervalToPositionAhead ?? "")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(intervalColor(timing.intervalToPositionAhead))

                // Gap to leader (secondary, smaller)
                Text(timing.gapToLeader ?? "")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(F1Theme.textTertiary)
            }
        }
    }

    private func intervalColor(_ interval: String?) -> Color {
        guard let interval, interval.hasPrefix("-") else {
            return F1Theme.textSecondary
        }
        return F1Theme.green
    }

    // MARK: - Lap Time Stack (last lap + best lap)

    @ViewBuilder
    private var lapTimeStack: some View {
        if let timing {
            VStack(alignment: .trailing, spacing: 1) {
                // Last lap time (primary, colored)
                if let lastLap = timing.lastLapTime {
                    Text(lastLap)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(lastLapColor(timing))
                }

                // Best lap time (secondary, smaller)
                if let bestLap = timing.bestLapTime {
                    Text(bestLap)
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(hasFastestLap ? F1Theme.purple : F1Theme.textTertiary)
                }
            }
        }
    }

    private func lastLapColor(_ timing: TimingDataDriver) -> Color {
        if timing.sectors.contains(where: \.overallFastest) {
            return F1Theme.purple
        }
        if timing.sectors.contains(where: \.personalFastest) {
            return F1Theme.green
        }
        return F1Theme.yellow
    }

    // MARK: - Mini Sectors

    @ViewBuilder
    private var miniSectors: some View {
        if let timing {
            HStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { sectorIdx in
                    if sectorIdx < timing.segments.count {
                        compactSector(timing.segments[sectorIdx])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func compactSector(_ segments: [SegmentStatus]) -> some View {
        HStack(spacing: 1) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(seg.color)
                    .frame(width: 8, height: 6)
            }
        }
    }

    private var rowBackground: Color {
        if hasFastestLap {
            return F1Theme.purple.opacity(0.15)
        }
        if isFavorite {
            return F1Theme.yellow.opacity(0.05)
        }
        return .clear
    }
}
