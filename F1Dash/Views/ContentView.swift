import SwiftUI

struct ContentView: View {
    @Environment(LiveTimingStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Binding var selectedPage: AppPage
    @Bindable var replayEngine: ReplayEngine
    @Namespace private var navigationNamespace

    var body: some View {
        HStack(spacing: 0) {
            // Collapsible sidebar with smooth transition
            if !settings.sidebarCollapsed {
                AppSidebarView(selectedPage: $selectedPage)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(1)
            }

            // Main content
            VStack(spacing: 0) {
                // Toolbar with glass effect
                toolbar
                    .background {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }

                Divider().overlay(F1Theme.border)

                // Page content with matched geometry effect
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedPage) // Force view recreation for smooth transitions
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: replayEngine.state) { _, newState in
            // Auto-navigate to dashboard when replay session is loaded
            if newState == .ready {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedPage = .dashboard
                }
            }
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    settings.sidebarCollapsed.toggle()
                }
            } label: {
                Image(systemName: settings.sidebarCollapsed ? "sidebar.left" : "sidebar.left.fill")
                    .foregroundStyle(F1Theme.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(settings.sidebarCollapsed ? "Show Sidebar" : "Hide Sidebar")

            if selectedPage == .dashboard {
                // Blue flag filter in dashboard toolbar
                Spacer()
                RaceControlToolbar()
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(selectedPage.rawValue)
                    .font(.headline)
                    .foregroundStyle(F1Theme.textPrimary)
                    .transition(.scale.combined(with: .opacity))
                Spacer()
                ConnectionStatusView()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedPage)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .dashboard:
            DashboardView(replayEngine: replayEngine)
                .overlay(alignment: .bottom) {
                    if replayEngine.state == .ready || replayEngine.state.isActive || replayEngine.state == .finished {
                        ReplayControlsView(replayEngine: replayEngine)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: replayEngine.state)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .trackMapFull:
            TrackMapView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .replay:
            SessionBrowserView(replayEngine: replayEngine)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .schedule:
            ScheduleView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .standings:
            StandingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .settings:
            SettingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }
}

// MARK: - Race Control Toolbar

struct RaceControlToolbar: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Toggle(isOn: $settings.filterBlueFlags) {
            Label("Filter Blue Flags", systemImage: "flag.fill")
        }
        .toggleStyle(.checkbox)
        .font(.caption)
    }
}
