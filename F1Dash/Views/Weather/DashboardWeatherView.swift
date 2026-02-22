import SwiftUI

/// Weather panel for the dashboard showing current conditions.
struct DashboardWeatherView: View {
    @Environment(LiveTimingStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let weather = store.weatherData {
                // Temperature row
                HStack(spacing: 16) {
                    weatherItem(
                        icon: "thermometer.medium",
                        label: "AIR",
                        value: weather.airTemp.map { String(format: "%.1f°C", $0) } ?? "-"
                    )
                    weatherItem(
                        icon: "road.lanes",
                        label: "TRACK",
                        value: weather.trackTemp.map { String(format: "%.1f°C", $0) } ?? "-"
                    )
                }

                // Conditions row
                HStack(spacing: 16) {
                    weatherItem(
                        icon: "humidity",
                        label: "HUMIDITY",
                        value: weather.humidity.map { String(format: "%.0f%%", $0) } ?? "-"
                    )
                    weatherItem(
                        icon: "wind",
                        label: "WIND",
                        value: weather.windSpeed.map { String(format: "%.1f m/s", $0) } ?? "-"
                    )
                }

                // Pressure and rain
                HStack(spacing: 16) {
                    weatherItem(
                        icon: "barometer",
                        label: "PRESSURE",
                        value: weather.pressure.map { String(format: "%.0f hPa", $0) } ?? "-"
                    )

                    if weather.rainfall {
                        HStack(spacing: 4) {
                            Image(systemName: "cloud.rain.fill")
                                .foregroundStyle(F1Theme.blue)
                                .symbolEffect(.bounce, options: .repeating)
                            Text("RAIN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(F1Theme.blue)
                        }
                    } else {
                        weatherItem(
                            icon: "sun.max",
                            label: "CONDITIONS",
                            value: "DRY"
                        )
                    }
                }
            } else {
                Text("No weather data")
                    .font(.caption)
                    .foregroundStyle(F1Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(8)
        .f1Panel(title: "Weather")
    }

    @ViewBuilder
    private func weatherItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(F1Theme.textTertiary)
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(F1Theme.textTertiary)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(F1Theme.textPrimary)
        }
    }
}
