import SwiftUI

/// Navigation pages for the app.
enum AppPage: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Dashboard"
    case trackMapFull = "Track Map"
    case replay = "Replay"
    case schedule = "Schedule"
    case standings = "Standings"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: "rectangle.split.3x3"
        case .trackMapFull: "map"
        case .replay: "play.circle"
        case .schedule: "calendar"
        case .standings: "trophy"
        case .settings: "gear"
        }
    }
}

/// Collapsible sidebar with navigation links.
struct AppSidebarView: View {
    @Binding var selectedPage: AppPage
    @Environment(F1LiveTimingService.self) private var service

    var body: some View {
        VStack(spacing: 0) {
            // Navigation links
            VStack(spacing: 4) {
                ForEach(AppPage.allCases) { page in
                    sidebarButton(page)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)

            Spacer()

            // Connection status at bottom with pulsing effect
            connectionStatus
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(width: 180)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func sidebarButton(_ page: AppPage) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPage = page
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: page.systemImage)
                    .frame(width: 20)
                    .foregroundStyle(selectedPage == page ? .white : F1Theme.textSecondary)
                    .symbolEffect(.bounce, value: selectedPage == page)
                Text(page.rawValue)
                    .foregroundStyle(selectedPage == page ? F1Theme.textPrimary : F1Theme.textSecondary)
                    .fontWeight(selectedPage == page ? .semibold : .regular)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedPage == page ? F1Theme.elevated : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarButtonStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedPage)
    }

    @ViewBuilder
    private var connectionStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .symbolEffect(.pulse, options: .repeating, isActive: service.connectionState == .connecting || service.connectionState == .reconnecting)
            Text(service.connectionState.displayText)
                .font(.caption)
                .foregroundStyle(F1Theme.textSecondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background {
            Capsule()
                .fill(statusColor.opacity(0.1))
        }
    }

    private var statusColor: Color {
        switch service.connectionState {
        case .connected: F1Theme.green
        case .connecting, .reconnecting: F1Theme.yellow
        case .disconnected: .gray
        case .error: F1Theme.red
        }
    }
}
// MARK: - Custom Button Style with Hover Effect

struct SidebarButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .brightness(isHovered ? 0.05 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

