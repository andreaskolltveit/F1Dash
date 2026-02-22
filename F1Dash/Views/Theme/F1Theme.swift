import SwiftUI

/// F1-inspired dark theme with zinc-based color palette.
enum F1Theme {
    // MARK: - Background Colors

    /// Standard backgrounds (zinc-based).
    static let background = Color(red: 0.035, green: 0.035, blue: 0.043)  // zinc-950 (#09090b)
    static let surface = Color(red: 0.10, green: 0.10, blue: 0.11)       // zinc-900
    static let elevated = Color(red: 0.15, green: 0.15, blue: 0.16)      // zinc-800
    static let border = Color(red: 0.21, green: 0.21, blue: 0.23)        // zinc-700

    /// OLED-optimized pure black.
    static let oledBackground = Color.black
    static let oledSurface = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let oledElevated = Color(red: 0.08, green: 0.08, blue: 0.08)

    // MARK: - Text Colors
    static let textPrimary = Color(red: 0.98, green: 0.98, blue: 0.98)   // zinc-50
    static let textSecondary = Color(red: 0.63, green: 0.63, blue: 0.66) // zinc-400
    static let textTertiary = Color(red: 0.49, green: 0.49, blue: 0.53)  // zinc-500

    // MARK: - Semantic Colors
    static let green = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let purple = Color(red: 0.58, green: 0.29, blue: 0.95)
    static let yellow = Color(red: 0.95, green: 0.80, blue: 0.04)
    static let red = Color(red: 0.94, green: 0.19, blue: 0.19)
    static let blue = Color(red: 0.23, green: 0.51, blue: 0.96)

    // MARK: - Tire Compound Colors
    enum Tire {
        static let soft = Color(red: 0.94, green: 0.27, blue: 0.27)
        static let medium = Color(red: 0.95, green: 0.80, blue: 0.04)
        static let hard = Color(red: 0.90, green: 0.90, blue: 0.90)
        static let intermediate = Color(red: 0.13, green: 0.77, blue: 0.37)
        static let wet = Color(red: 0.23, green: 0.51, blue: 0.96)
    }
}

/// Panel style modifier for consistent dashboard panels.
struct F1PanelStyle: ViewModifier {
    var title: String?

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(F1Theme.textSecondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
                .frame(minHeight: 0, maxHeight: .infinity)
        }
        .background(F1Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(F1Theme.border, lineWidth: 1)
        )
    }
}

extension View {
    func f1Panel(title: String? = nil) -> some View {
        modifier(F1PanelStyle(title: title))
    }

    /// Apply OLED mode background override when enabled.
    func oledBackground(enabled: Bool) -> some View {
        self.background(enabled ? F1Theme.oledBackground : F1Theme.background)
    }
}
