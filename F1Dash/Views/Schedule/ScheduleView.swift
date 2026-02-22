import SwiftUI

/// Race calendar showing all rounds with countdown to next session.
struct ScheduleView: View {
    @State private var schedule: [RaceEvent] = []
    @State private var isLoading = true
    @State private var selectedSeason: Int = Calendar.current.component(.year, from: Date())
    @State private var countdown: String = ""
    @State private var countdownTimer: Timer?

    private let client = ErgastClient()
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let availableSeasons = Array((2020...Calendar.current.component(.year, from: Date())).reversed())

    var body: some View {
        VStack(spacing: 0) {
            // Header with season picker and countdown
            scheduleHeader

            Divider().overlay(F1Theme.border)

            // Race list
            if isLoading {
                loadingView
            } else {
                raceList
            }
        }
        .background(F1Theme.background)
        .task {
            await loadSchedule()
        }
        .onAppear { startCountdown() }
        .onDisappear { countdownTimer?.invalidate() }
    }

    // MARK: - Header

    @ViewBuilder
    private var scheduleHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(F1Theme.red)

            Text("Schedule")
                .font(.title3.bold())
                .foregroundStyle(F1Theme.textPrimary)

            Spacer()

            // Countdown to next race (only for current year)
            if selectedSeason == currentYear, let next = nextRace {
                HStack(spacing: 8) {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(F1Theme.textTertiary)
                    Text(next.raceName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(F1Theme.textSecondary)
                        .lineLimit(1)
                    Text(countdown)
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(F1Theme.green)
                        .contentTransition(.numericText())
                }
            }

            // Season picker
            Picker("Season", selection: $selectedSeason) {
                ForEach(availableSeasons, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .onChange(of: selectedSeason) { _, _ in
                Task { await loadSchedule() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Race List

    @ViewBuilder
    private var raceList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(schedule) { race in
                    raceRow(race)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func raceRow(_ race: RaceEvent) -> some View {
        let isPast = !race.isFuture
        let isNext = race.id == nextRace?.id

        HStack(spacing: 12) {
            // Round number
            Text("R\(race.round)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isNext ? F1Theme.green : F1Theme.textTertiary)
                .frame(width: 32)

            // Country flag
            Text(flagEmoji(for: race.country))
                .font(.title3)

            // Race info
            VStack(alignment: .leading, spacing: 2) {
                Text(race.raceName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isPast ? F1Theme.textTertiary : F1Theme.textPrimary)

                Text("\(race.circuitName) — \(race.locality)")
                    .font(.system(size: 11))
                    .foregroundStyle(F1Theme.textTertiary)
            }

            Spacer()

            // Sprint indicator
            if race.sprintDate != nil {
                Text("SPRINT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(F1Theme.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(F1Theme.blue.opacity(0.15))
                    )
            }

            // Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDate(race.date))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(isPast ? F1Theme.textTertiary : F1Theme.textPrimary)

                if let time = race.time {
                    Text(formatTime(time))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(F1Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isNext ? F1Theme.green.opacity(0.08) : F1Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isNext ? F1Theme.green.opacity(0.3) : F1Theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Loading schedule...")
                .foregroundStyle(F1Theme.textSecondary)
            Spacer()
        }
    }

    // MARK: - Data

    private func loadSchedule() async {
        isLoading = true
        do {
            schedule = try await client.fetchSchedule(season: selectedSeason)
        } catch {
            schedule = []
        }
        isLoading = false
    }

    private var nextRace: RaceEvent? {
        schedule.first(where: \.isFuture)
    }

    private func startCountdown() {
        updateCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateCountdown()
        }
    }

    private func updateCountdown() {
        guard let next = nextRace, let date = next.raceDate else {
            countdown = ""
            return
        }
        let diff = date.timeIntervalSince(Date())
        guard diff > 0 else { countdown = "NOW"; return }

        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let mins = (Int(diff) % 3600) / 60
        let secs = Int(diff) % 60

        if days > 0 {
            countdown = "\(days)d \(hours)h \(mins)m"
        } else {
            countdown = String(format: "%02d:%02d:%02d", hours, mins, secs)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let out = DateFormatter()
        out.dateFormat = "d MMM"
        return out.string(from: date)
    }

    private func formatTime(_ timeStr: String) -> String {
        // Convert "15:00:00Z" to local time
        let cleaned = timeStr.replacingOccurrences(of: "Z", with: "")
        let parts = cleaned.split(separator: ":")
        guard parts.count >= 2 else { return timeStr }
        return "\(parts[0]):\(parts[1]) UTC"
    }

    private func flagEmoji(for country: String) -> String {
        // Map common F1 countries to codes
        let countryMap: [String: String] = [
            "Bahrain": "BH", "Saudi Arabia": "SA", "Australia": "AU",
            "Japan": "JP", "China": "CN", "USA": "US", "Italy": "IT",
            "Monaco": "MC", "Spain": "ES", "Canada": "CA", "Austria": "AT",
            "UK": "GB", "Hungary": "HU", "Belgium": "BE", "Netherlands": "NL",
            "Singapore": "SG", "Azerbaijan": "AZ", "Mexico": "MX", "Brazil": "BR",
            "Qatar": "QA", "UAE": "AE", "Las Vegas": "US", "Miami": "US",
        ]
        let code = countryMap[country] ?? "UN"
        let base: UInt32 = 0x1F1E6 - 65
        let scalars = code.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value)
        }
        return String(scalars.map { Character($0) })
    }
}
