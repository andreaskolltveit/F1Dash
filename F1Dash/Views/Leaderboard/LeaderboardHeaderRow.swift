import SwiftUI

/// Header row for the dashboard leaderboard.
struct LeaderboardHeaderRow: View {
    let showMetrics: Bool

    var body: some View {
        HStack(spacing: 0) {
            headerCell("", width: 80)       // driver tag pill
            headerCell("+/-", width: 28)    // position delta
            headerCell("TIRE", width: 44)
            headerCell("DRS", width: 48)
            headerCell("GAP", width: 80, alignment: .trailing)
            headerCell("LAST", width: 86, alignment: .trailing)
            Color.clear.frame(width: 4)
            headerCell("S1", width: 28)
            headerCell("S2", width: 28)
            headerCell("S3", width: 28)
            headerCell("PIT", width: 20)
            if showMetrics {
                headerCell("SPD", width: 40, alignment: .trailing)
                headerCell("G", width: 22)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(F1Theme.elevated)
    }

    @ViewBuilder
    private func headerCell(_ text: String, width: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(F1Theme.textTertiary)
            .frame(width: width, alignment: alignment)
    }
}
