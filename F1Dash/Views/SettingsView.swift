import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(F1LiveTimingService.self) private var timingService

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Notifications") {
                Toggle("Race Control Chime", isOn: $settings.chimeEnabled)
                Slider(value: $settings.chimeVolume, in: 0...1) {
                    Text("Chime Volume")
                }
                .disabled(!settings.chimeEnabled)
            }

            Section("Race Control") {
                Toggle("Filter Blue Flags", isOn: $settings.filterBlueFlags)
            }

            Section("Display") {
                Toggle("Show Car Metrics", isOn: $settings.showCarMetrics)
                Toggle("Show Corner Numbers", isOn: $settings.showCornerNumbers)

                Picker("Speed Unit", selection: $settings.speedUnit) {
                    ForEach(SpeedUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }

                Toggle("OLED Mode (Pure Black)", isOn: $settings.oledMode)
            }

            Section("Timing") {
                HStack {
                    Text("Delay Buffer")
                    Spacer()
                    Text("\(settings.delaySeconds)s")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: Binding(
                    get: { Double(settings.delaySeconds) },
                    set: {
                        settings.delaySeconds = Int($0)
                        timingService.updateDelay(Int($0))
                    }
                ), in: 0...120, step: 5) {
                    Text("Delay")
                }
                Text("Delays all data for spoiler-free viewing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Connection") {
                Toggle("Auto-Reconnect", isOn: $settings.autoReconnect)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
    }
}
