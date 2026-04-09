import SwiftUI

@main
struct F1DashApp: App {
    @State private var timingService = F1LiveTimingService()
    @State private var store = LiveTimingStore()
    @State private var settings = SettingsStore()
    @State private var openF1Service = OpenF1Service()
    @State private var testRunner = AutoTestRunner()
    @State private var simulator = RaceSimulator()
    @State private var replayEngine = ReplayEngine()
    @State private var isDemoMode = false
    @State private var selectedPage: AppPage = .dashboard

    private var launchInDemo: Bool {
        CommandLine.arguments.contains("--demo")
    }

    private var launchAutoTest: Bool {
        CommandLine.arguments.contains("--autotest")
    }

    private var launchSimulate: Bool {
        CommandLine.arguments.contains("--simulate")
    }

    private var launchReplay: Bool {
        CommandLine.arguments.contains("--replay")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(selectedPage: $selectedPage, replayEngine: replayEngine)
                    .environment(store)
                    .environment(settings)
                    .environment(timingService)
                    .environment(openF1Service)

                // Test results overlay with glass effect
                if testRunner.isRunning || !testRunner.results.isEmpty {
                    testOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                if launchReplay {
                    startReplayTest()
                } else if launchSimulate {
                    startSimulation()
                } else if launchInDemo || launchAutoTest {
                    loadDemoData()
                    if launchAutoTest {
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            await testRunner.runAll(
                                store: store,
                                settings: settings,
                                pageSetter: { page in selectedPage = page }
                            )
                        }
                    }
                } else {
                    timingService.start(store: store, settings: settings)
                    openF1Service.startLive(store: store)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: testRunner.isRunning)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: testRunner.results.isEmpty)
        }
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandMenu("Debug") {
                Button(isDemoMode ? "Unload Demo Data" : "Load Demo Data") {
                    if isDemoMode {
                        unloadDemoData()
                    } else {
                        loadDemoData()
                    }
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])

                Button(simulator.isRunning ? "Stop Simulation" : "Simulate Race") {
                    if simulator.isRunning {
                        simulator.stop()
                    } else {
                        startSimulation()
                    }
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])

                Button("Run Auto Test") {
                    loadDemoData()
                    Task {
                        await testRunner.runAll(
                            store: store,
                            settings: settings,
                            pageSetter: { page in selectedPage = page }
                        )
                    }
                }
                .keyboardShortcut("T", modifiers: [.command, .shift])

                Divider()

                Button("Reconnect Live") {
                    unloadDemoData()
                    timingService.connect()
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(settings)
                .environment(timingService)
        }
    }

    // MARK: - Test Overlay

    @ViewBuilder
    private var testOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                testOverlayHeader
                
                if !testRunner.results.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    
                    testResultsList
                }
            }
            .padding(16)
            .background(overlayBackground)
            .padding(16)
        }
    }
    
    private var overlayBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var testOverlayHeader: some View {
        HStack(spacing: 12) {
            if testRunner.isRunning {
                ProgressView()
                    .controlSize(.small)
                Text(testRunner.currentPhase)
                    .font(.headline)
                    .foregroundStyle(.primary)
            } else {
                testResultsIcon
                testResultsText
            }
            
            Spacer()
            
            if !testRunner.isRunning {
                Button("Dismiss") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        testRunner.results = []
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.bottom, 4)
    }
    
    @ViewBuilder
    private var testResultsIcon: some View {
        let failed = testRunner.results.filter { !$0.passed }.count
        let iconName = failed > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        let iconColor: Color = failed > 0 ? .red : .green
        
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
            .font(.title3)
    }
    
    @ViewBuilder
    private var testResultsText: some View {
        let passed = testRunner.results.filter(\.passed).count
        let failed = testRunner.results.filter { !$0.passed }.count
        let textColor: Color = failed > 0 ? .red : .green
        
        Text("Test Complete: \(passed) passed, \(failed) failed")
            .font(.headline)
            .foregroundStyle(textColor)
    }
    
    @ViewBuilder
    private var testResultsList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(testRunner.results) { result in
                    testResultRow(result)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 200)
    }
    
    @ViewBuilder
    private func testResultRow(_ result: AutoTestRunner.TestResult) -> some View {
        HStack(spacing: 8) {
            Text(result.passed ? "✅" : "❌")
                .font(.caption)
            Text(result.name)
                .font(.caption.bold())
            Text(result.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Demo Data

    private func loadDemoData() {
        timingService.disconnect()
        MockDataProvider.loadIntoStore(store)
        timingService.connectionState = .connected
        isDemoMode = true
    }

    private func unloadDemoData() {
        isDemoMode = false
    }

    private func startReplayTest() {
        timingService.disconnect()
        timingService.connectionState = .connected
        selectedPage = .replay
        let logFile = "/tmp/f1dash-replay-test.log"
        try? "".write(toFile: logFile, atomically: true, encoding: .utf8)

        func log(_ msg: String) {
            let line = "[\(Date())] \(msg)\n"
            if let data = line.data(using: .utf8),
               let fh = FileHandle(forWritingAtPath: logFile) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
            NSLog("[REPLAY-TEST] %@", msg)
        }

        // Auto-load Las Vegas 2024 Race (session_key 9644)
        Task {
            log("Loading sessions for 2024...")
            await replayEngine.loadSessions(year: 2024)
            log("Sessions loaded: \(replayEngine.availableSessions.count)")

            // Find Las Vegas Race
            if let vegasRace = replayEngine.availableSessions.first(where: {
                $0.location == "Las Vegas" && $0.sessionName == "Race"
            }) {
                log("Found Las Vegas Race: key=\(vegasRace.sessionKey), displayName=\(vegasRace.displayName)")
                log("Loading session data (this takes ~15-30s)...")
                await replayEngine.loadSession(vegasRace, store: store)
                log("State after load: \(replayEngine.state)")
                log("Drivers in store: \(store.drivers.count)")
                log("Session info: \(store.sessionInfo?.meetingName ?? "nil")")

                if replayEngine.state == .ready {
                    log("Starting playback...")
                    replayEngine.play()
                    log("State after play: \(replayEngine.state)")

                    // Wait 5 seconds and check store state
                    try? await Task.sleep(for: .seconds(5))
                    log("After 5s playback:")
                    log("  currentLap: \(replayEngine.currentLap)")
                    log("  timingData entries: \(store.timingData.count)")
                    log("  raceControlMessages: \(store.raceControlMessages.count)")
                    log("  positions: \(store.timingData.values.compactMap(\.position).count)")
                    if let first = store.timingData.first {
                        log("  sample driver \(first.key): pos=\(first.value.position ?? "nil"), gap=\(first.value.gapToLeader ?? "nil")")
                    }
                } else {
                    log("ERROR: State is not .ready after load: \(replayEngine.state)")
                }
            } else {
                log("ERROR: Could not find Las Vegas Race in 2024 sessions")
                let vegasSessions = replayEngine.availableSessions.filter { $0.location == "Las Vegas" }
                log("Las Vegas sessions found: \(vegasSessions.count)")
                for s in vegasSessions {
                    log("  \(s.sessionName) key=\(s.sessionKey) location=\(s.location ?? "nil")")
                }
                let allLocations = Set(replayEngine.availableSessions.compactMap(\.location))
                log("All locations: \(allLocations.sorted())")
            }
            log("=== REPLAY TEST COMPLETE ===")
        }
    }

    private func startSimulation() {
        timingService.disconnect()
        MockDataProvider.loadRaceStart(store)
        timingService.connectionState = .connected
        isDemoMode = true
        simulator.start(store: store)
    }
}
