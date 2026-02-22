import SwiftUI

struct LeaderboardView: View {
    @Environment(LiveTimingStore.self) private var store

    var body: some View {
        Table(sortedDrivers) {
            TableColumn("Pos") { driver in
                Text(store.timingData[driver.id]?.position ?? "-")
                    .monospacedDigit()
                    .frame(width: 30, alignment: .center)
            }
            .width(40)

            TableColumn("Driver") { driver in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(driver.color)
                        .frame(width: 4, height: 20)

                    Text(driver.tla)
                        .font(.body.bold())

                    Text(driver.lastName.uppercased())
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 150, ideal: 200)

            TableColumn("Gap") { driver in
                Text(store.timingData[driver.id]?.gapToLeader ?? "-")
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 90)

            TableColumn("Interval") { driver in
                Text(store.timingData[driver.id]?.intervalToPositionAhead ?? "-")
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 90)

            TableColumn("Last Lap") { driver in
                let timing = store.timingData[driver.id]
                Text(timing?.lastLapTime ?? "-")
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 100)

            TableColumn("Best Lap") { driver in
                Text(store.timingData[driver.id]?.bestLapTime ?? "-")
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 100)

            TableColumn("Laps") { driver in
                if let laps = store.timingData[driver.id]?.numberOfLaps {
                    Text("\(laps)")
                        .monospacedDigit()
                } else {
                    Text("-")
                }
            }
            .width(50)

            TableColumn("Speed") { driver in
                if let speed = store.carTelemetry[driver.id]?.speed {
                    Text("\(speed)")
                        .monospacedDigit()
                } else {
                    Text("-")
                }
            }
            .width(60)

            TableColumn("Sectors") { driver in
                sectorView(for: driver.id)
            }
            .width(min: 120, ideal: 180)
        }
        .overlay {
            if sortedDrivers.isEmpty {
                ContentUnavailableView(
                    "No Timing Data",
                    systemImage: "list.number",
                    description: Text("Driver timing data will appear here during a session.")
                )
            }
        }
    }

    private var sortedDrivers: [Driver] {
        store.driversSorted
    }

    @ViewBuilder
    private func sectorView(for driverNumber: String) -> some View {
        if let timing = store.timingData[driverNumber] {
            HStack(spacing: 2) {
                ForEach(Array(timing.segments.enumerated()), id: \.offset) { _, segments in
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(segment.color)
                            .frame(width: 6, height: 14)
                    }
                }
            }
        }
    }
}
