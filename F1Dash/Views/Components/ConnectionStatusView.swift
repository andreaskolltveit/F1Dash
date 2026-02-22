import SwiftUI

struct ConnectionStatusView: View {
    @Environment(F1LiveTimingService.self) private var service

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(service.connectionState.displayText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if case .error = service.connectionState {
                Button("Retry") {
                    service.connect()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }

    private var statusColor: Color {
        switch service.connectionState {
        case .connected: .green
        case .connecting, .reconnecting: .yellow
        case .disconnected: .gray
        case .error: .red
        }
    }
}
