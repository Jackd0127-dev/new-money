import SwiftUI

enum AppTheme {
    enum Colors {
        static let appBackground = Color(hex: "#000000")
        static let surface = Color(hex: "#101010")
        static let elevatedSurface = Color(hex: "#171717")
        static let cardBackground = Color(hex: "#0B0B0B")
        static let primaryOrange = Color(hex: "#E85002")
        static let orangeHighlight = Color(hex: "#F16001")
        static let orangeMuted = Color(hex: "#C10801")
        static let warmSand = Color(hex: "#D9C3AB")
        static let primaryText = Color(hex: "#F9F9F9")
        static let secondaryText = Color(hex: "#A7A7A7")
        static let tertiaryText = Color(hex: "#646464")
        static let border = Color(hex: "#333333")
        static let divider = Color(hex: "#242424")
        static let success = Color(hex: "#30D158")
        static let warning = Color(hex: "#FFD60A")
        static let danger = Color(hex: "#FF453A")
        static let glowOrange = Color(hex: "#F16001").opacity(0.45)
    }

    enum Gradients {
        static let primary = LinearGradient(
            colors: [Colors.orangeMuted, Colors.primaryOrange, Colors.orangeHighlight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let card = LinearGradient(
            colors: [Colors.elevatedSurface, Colors.cardBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let hero = LinearGradient(
            colors: [Colors.primaryOrange.opacity(0.55), Colors.orangeMuted.opacity(0.28), .clear],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 30
    }

    enum Animation {
        static let quick = SwiftUI.Animation.spring(response: 0.24, dampingFraction: 0.82)
        static let standard = SwiftUI.Animation.spring(response: 0.36, dampingFraction: 0.86)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch cleaned.count {
        case 8:
            red = Double((value & 0xFF000000) >> 24) / 255
            green = Double((value & 0x00FF0000) >> 16) / 255
            blue = Double((value & 0x0000FF00) >> 8) / 255
            alpha = Double(value & 0x000000FF) / 255
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1
        default:
            red = 1
            green = 1
            blue = 1
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
