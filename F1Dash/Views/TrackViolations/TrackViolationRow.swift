import SwiftUI

/// Single row showing a driver's track violation count.
struct TrackViolationRow: View {
    let violation: TrackViolation
    let driver: Driver?

    var body: some View {
        HStack(spacing: 6) {
            // Team color stripe
            RoundedRectangle(cornerRadius: 1)
                .fill(driver?.color ?? .gray)
                .frame(width: 3, height: 18)

            // TLA
            Text(driver?.tla ?? violation.driverNumber)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(F1Theme.textPrimary)

            Spacer()

            // Count badge
            Text("\(violation.count)")
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(badgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Last lap
            if let lap = violation.lastLap {
                Text("L\(lap)")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(F1Theme.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    private var badgeColor: Color {
        switch violation.count {
        case 1: F1Theme.yellow
        case 2: F1Theme.yellow.opacity(0.8)
        default: F1Theme.red
        }
    }
}
