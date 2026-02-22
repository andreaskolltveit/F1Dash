import SwiftUI

struct RaceControlMessageRow: View {
    let message: RaceControlMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FlagIcon(flag: message.flag)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.message)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(DateFormatting.localTimeString(message.utc))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if let lap = message.lap {
                        Text("Lap \(lap)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let scope = message.scope {
                        Text(scope.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }

                    if let number = message.racingNumber {
                        driverTag(number: number)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func driverTag(number: String) -> some View {
        Text("#\(number)")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.blue.opacity(0.2))
            .clipShape(Capsule())
    }
}
