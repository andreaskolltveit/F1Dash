import SwiftUI

/// Detailed view for a single driver, shown as a sheet from the leaderboard.
struct DriverDetailView: View {
    let driverNumber: String
    @Environment(LiveTimingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with driver info
            if let driver = store.drivers[driverNumber] {
                driverHeader(driver)
            }

            Divider().overlay(F1Theme.border)

            ScrollView {
                VStack(spacing: 12) {
                    // Telemetry panel
                    telemetryPanel

                    // Stint overview
                    stintPanel

                    // Lap times
                    lapTimesPanel
                }
                .padding(12)
            }
        }
        .frame(width: 480, height: 500)
        .background(F1Theme.background)
        .onExitCommand { dismiss() }
    }

    // MARK: - Header

    @ViewBuilder
    private func driverHeader(_ driver: Driver) -> some View {
        HStack(spacing: 12) {
            // Team color bar
            RoundedRectangle(cornerRadius: 3)
                .fill(driver.color)
                .frame(width: 6)

            // Driver info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(driver.tla)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(driver.color)

                    Text("#\(driver.racingNumber)")
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                        .foregroundStyle(F1Theme.textTertiary)
                }

                Text(driver.fullName)
                    .font(.system(size: 14))
                    .foregroundStyle(F1Theme.textPrimary)

                Text(driver.teamName)
                    .font(.system(size: 12))
                    .foregroundStyle(F1Theme.textSecondary)
            }

            Spacer()

            // Current position & timing
            if let timing = store.timingData[driverNumber] {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("P")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(F1Theme.textTertiary)
                        Text(timing.position ?? "-")
                            .font(.system(size: 28, weight: .bold).monospacedDigit())
                            .foregroundStyle(F1Theme.textPrimary)
                    }

                    if let gap = timing.gapToLeader, !gap.isEmpty {
                        Text(gap)
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(F1Theme.textSecondary)
                    }
                }
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(F1Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(16)
        .frame(height: 80)
        .background(.ultraThinMaterial)
    }

    // MARK: - Telemetry

    @ViewBuilder
    private var telemetryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let telem = store.carTelemetry[driverNumber] {
                HStack(spacing: 16) {
                    telemetryGauge(label: "SPEED", value: "\(telem.speed)", unit: "km/h", color: F1Theme.blue)
                    telemetryGauge(label: "RPM", value: "\(telem.rpm)", unit: "", color: F1Theme.red)
                    telemetryGauge(label: "GEAR", value: "\(telem.gear)", unit: "", color: F1Theme.green)
                    telemetryGauge(label: "THROTTLE", value: "\(telem.throttle)%", unit: "", color: F1Theme.yellow)

                    // DRS status
                    VStack(spacing: 2) {
                        Text("DRS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(F1Theme.textTertiary)
                        Text(telem.drs.displayText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(drsColor(telem.drs))
                    }
                }
            } else {
                Text("No telemetry data")
                    .font(.caption)
                    .foregroundStyle(F1Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .f1Panel(title: "Telemetry")
    }

    @ViewBuilder
    private func telemetryGauge(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(F1Theme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 8))
                    .foregroundStyle(F1Theme.textTertiary)
            }
        }
    }

    // MARK: - Stint Overview

    @ViewBuilder
    private var stintPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let currentStint = store.currentStints[driverNumber] {
                HStack(spacing: 12) {
                    // Current tire
                    HStack(spacing: 6) {
                        Circle()
                            .fill(currentStint.compound.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(currentStint.compound.abbreviation)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.black)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Stint \(currentStint.stintNumber)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(F1Theme.textPrimary)
                            Text("Age: \(currentStint.currentAge(currentLap: store.lapCount?.currentLap ?? 0)) laps")
                                .font(.system(size: 10))
                                .foregroundStyle(F1Theme.textSecondary)
                        }
                    }

                    Spacer()

                    // Pit stops
                    let pits = store.pitStops[driverNumber] ?? []
                    if !pits.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(pits) { pit in
                                VStack(spacing: 1) {
                                    Text("L\(pit.lapNumber)")
                                        .font(.system(size: 8).monospacedDigit())
                                        .foregroundStyle(F1Theme.textTertiary)
                                    if let duration = pit.pitDuration {
                                        Text(String(format: "%.1fs", duration))
                                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                                            .foregroundStyle(.cyan)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(F1Theme.elevated)
                                )
                            }
                        }
                    }
                }
            } else {
                Text("No stint data")
                    .font(.caption)
                    .foregroundStyle(F1Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .f1Panel(title: "Stint")
    }

    // MARK: - Lap Times

    @ViewBuilder
    private var lapTimesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let timing = store.timingData[driverNumber] {
                HStack(spacing: 24) {
                    lapTimeStat(label: "LAST LAP", value: timing.lastLapTime)
                    lapTimeStat(label: "BEST LAP", value: timing.bestLapTime)
                    lapTimeStat(label: "LAPS", value: timing.numberOfLaps.map { "\($0)" })
                }

                // Sector breakdown
                if !timing.sectors.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(timing.sectors.enumerated()), id: \.offset) { idx, sector in
                            VStack(spacing: 2) {
                                Text("S\(idx + 1)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(F1Theme.textTertiary)
                                Text(sector.value ?? "-")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(sectorColor(sector))

                                // Mini segment bar
                                HStack(spacing: 1) {
                                    ForEach(Array(sector.segments.enumerated()), id: \.offset) { _, seg in
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(seg.color)
                                            .frame(width: 8, height: 4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("No timing data")
                    .font(.caption)
                    .foregroundStyle(F1Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .f1Panel(title: "Lap Times")
    }

    @ViewBuilder
    private func lapTimeStat(label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(F1Theme.textTertiary)
            Text(value ?? "-")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(F1Theme.textPrimary)
        }
    }

    // MARK: - Helpers

    private func sectorColor(_ sector: TimingDataDriver.SectorTiming) -> Color {
        if sector.overallFastest { return F1Theme.purple }
        if sector.personalFastest { return F1Theme.green }
        return F1Theme.yellow
    }

    private func drsColor(_ drs: CarTelemetry.DRSStatus) -> Color {
        switch drs {
        case .active: F1Theme.green
        case .eligible, .possible: F1Theme.yellow
        default: F1Theme.textTertiary
        }
    }
}
