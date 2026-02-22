import SwiftUI

/// WDC and WCC standings with segmented control.
struct StandingsView: View {
    @State private var selectedTab: StandingsTab = .drivers
    @State private var driverStandings: [DriverStanding] = []
    @State private var constructorStandings: [ConstructorStanding] = []
    @State private var isLoading = true
    @State private var selectedSeason: Int = min(Calendar.current.component(.year, from: Date()) - 1, 2025)

    private let client = ErgastClient()
    private let availableSeasons = Array((2020...Calendar.current.component(.year, from: Date())).reversed())

    enum StandingsTab: String, CaseIterable {
        case drivers = "Drivers"
        case constructors = "Constructors"
    }

    var body: some View {
        VStack(spacing: 0) {
            standingsHeader

            Divider().overlay(F1Theme.border)

            if isLoading {
                loadingView
            } else {
                standingsList
            }
        }
        .background(F1Theme.background)
        .task {
            await loadStandings()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var standingsHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.title2)
                .foregroundStyle(F1Theme.yellow)

            Text("Standings")
                .font(.title3.bold())
                .foregroundStyle(F1Theme.textPrimary)

            Spacer()

            Picker("", selection: $selectedTab) {
                ForEach(StandingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Picker("Season", selection: $selectedSeason) {
                ForEach(availableSeasons, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .onChange(of: selectedSeason) { _, _ in
                Task { await loadStandings() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Standings List

    @ViewBuilder
    private var standingsList: some View {
        let isEmpty = selectedTab == .drivers ? driverStandings.isEmpty : constructorStandings.isEmpty

        if isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "trophy")
                    .font(.largeTitle)
                    .foregroundStyle(F1Theme.textTertiary)
                Text("No standings data for \(String(selectedSeason))")
                    .foregroundStyle(F1Theme.textSecondary)
                Text("Try selecting an earlier season")
                    .font(.caption)
                    .foregroundStyle(F1Theme.textTertiary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    switch selectedTab {
                    case .drivers:
                        ForEach(driverStandings) { standing in
                            driverRow(standing)
                        }
                    case .constructors:
                        ForEach(constructorStandings) { standing in
                            constructorRow(standing)
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Driver Row

    @ViewBuilder
    private func driverRow(_ standing: DriverStanding) -> some View {
        let maxPoints = driverStandings.first?.pointsDouble ?? 1

        HStack(spacing: 0) {
            // Position
            Text(standing.position)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(positionColor(standing.positionInt))
                .frame(width: 32)

            // Driver info
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(standing.code ?? standing.familyName.prefix(3).uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(F1Theme.textPrimary)
                    Text("\(standing.givenName) \(standing.familyName)")
                        .font(.system(size: 11))
                        .foregroundStyle(F1Theme.textSecondary)
                }
                Text(standing.constructorName)
                    .font(.system(size: 10))
                    .foregroundStyle(F1Theme.textTertiary)
            }
            .frame(width: 200, alignment: .leading)

            // Wins
            if let wins = Int(standing.wins), wins > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(F1Theme.yellow)
                    Text("\(wins)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(F1Theme.yellow)
                }
                .frame(width: 40)
            } else {
                Spacer().frame(width: 40)
            }

            // Points bar
            GeometryReader { geo in
                let barWidth = maxPoints > 0
                    ? geo.size.width * CGFloat(standing.pointsDouble / maxPoints)
                    : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(F1Theme.elevated)
                        .frame(height: 18)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barGradient(for: standing.positionInt))
                        .frame(width: max(barWidth, 2), height: 18)
                }
            }
            .frame(height: 18)

            // Points
            Text(standing.points)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(F1Theme.textPrimary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(F1Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Constructor Row

    @ViewBuilder
    private func constructorRow(_ standing: ConstructorStanding) -> some View {
        let maxPoints = constructorStandings.first?.pointsDouble ?? 1

        HStack(spacing: 0) {
            // Position
            Text(standing.position)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(positionColor(standing.positionInt))
                .frame(width: 32)

            // Constructor name
            Text(standing.constructorName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(F1Theme.textPrimary)
                .frame(width: 200, alignment: .leading)

            // Wins
            if let wins = Int(standing.wins), wins > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(F1Theme.yellow)
                    Text("\(wins)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(F1Theme.yellow)
                }
                .frame(width: 40)
            } else {
                Spacer().frame(width: 40)
            }

            // Points bar
            GeometryReader { geo in
                let barWidth = maxPoints > 0
                    ? geo.size.width * CGFloat(standing.pointsDouble / maxPoints)
                    : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(F1Theme.elevated)
                        .frame(height: 18)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barGradient(for: standing.positionInt))
                        .frame(width: max(barWidth, 2), height: 18)
                }
            }
            .frame(height: 18)

            // Points
            Text(standing.points)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(F1Theme.textPrimary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(F1Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Loading standings...")
                .foregroundStyle(F1Theme.textSecondary)
            Spacer()
        }
    }

    // MARK: - Data

    private func loadStandings() async {
        isLoading = true
        do {
            async let drivers = client.fetchDriverStandings(season: selectedSeason)
            async let constructors = client.fetchConstructorStandings(season: selectedSeason)
            driverStandings = try await drivers
            constructorStandings = try await constructors
        } catch {
            driverStandings = []
            constructorStandings = []
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func positionColor(_ pos: Int) -> Color {
        switch pos {
        case 1: F1Theme.yellow
        case 2: Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: Color(red: 0.80, green: 0.50, blue: 0.20)
        default: F1Theme.textSecondary
        }
    }

    private func barGradient(for position: Int) -> LinearGradient {
        let color: Color
        switch position {
        case 1: color = F1Theme.yellow
        case 2: color = Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: color = Color(red: 0.80, green: 0.50, blue: 0.20)
        default: color = F1Theme.blue
        }
        return LinearGradient(
            colors: [color.opacity(0.8), color.opacity(0.4)],
            startPoint: .leading, endPoint: .trailing
        )
    }
}
