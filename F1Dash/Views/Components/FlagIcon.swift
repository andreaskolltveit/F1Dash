import SwiftUI

struct FlagIcon: View {
    let flag: RaceControlMessage.Flag?

    var body: some View {
        if let flag = flag {
            Image(systemName: flag.systemImage)
                .foregroundStyle(flag.color)
                .font(.title3)
                .frame(width: 24)
        } else {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.title3)
                .frame(width: 24)
        }
    }
}
