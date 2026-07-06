import SwiftUI

struct AppThemePalette: Equatable, Sendable {
    var title: String
    var subtitle: String
    var accentHex: String
    var accentHighlightHex: String
    var accentMutedHex: String
    var warmHex: String
    var backgroundHex: String
    var surfaceHex: String
    var elevatedSurfaceHex: String
    var cardBackgroundHex: String
    var textHex: String
    var secondaryTextHex: String
    var tertiaryTextHex: String
    var borderHex: String
    var dividerHex: String
    var successHex: String
    var warningHex: String
    var dangerHex: String
    var preferredColorScheme: ColorScheme

    var accentReadableTextHex: String {
        Self.readableTextHex(on: accentHex)
    }

    var cardEyebrowHex: String {
        preferredColorScheme == .dark ? warmHex : secondaryTextHex
    }

    private static func readableTextHex(on hex: String) -> String {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return "#FFFFFF"
        }

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.58 ? "#111111" : "#FFFFFF"
    }
}

enum AppThemePreset: String, CaseIterable, Identifiable, Sendable {
    case classic
    case goldObsidian
    case warmLight
    case sagePaper
    case navyEmerald
    case darkBlueMintGold
    case charcoalTeal
    case slateCoral
    case midnightEmerald

    var id: String { rawValue }

    var title: String { palette.title }

    var subtitle: String { palette.subtitle }

    var palette: AppThemePalette {
        switch self {
        case .classic:
            AppThemePalette(
                title: "Classic",
                subtitle: "Black, orange, and warm sand.",
                accentHex: "#E85002",
                accentHighlightHex: "#F16001",
                accentMutedHex: "#C10801",
                warmHex: "#D9C3AB",
                backgroundHex: "#000000",
                surfaceHex: "#101010",
                elevatedSurfaceHex: "#171717",
                cardBackgroundHex: "#0B0B0B",
                textHex: "#F9F9F9",
                secondaryTextHex: "#A7A7A7",
                tertiaryTextHex: "#646464",
                borderHex: "#333333",
                dividerHex: "#242424",
                successHex: "#30D158",
                warningHex: "#FFD60A",
                dangerHex: "#FF453A",
                preferredColorScheme: .dark
            )
        case .goldObsidian:
            AppThemePalette(
                title: "Gold Obsidian",
                subtitle: "Deep blue-black with soft gold.",
                accentHex: "#E6B450",
                accentHighlightHex: "#F3D08A",
                accentMutedHex: "#9C6D22",
                warmHex: "#BFBDB6",
                backgroundHex: "#0B0E14",
                surfaceHex: "#141820",
                elevatedSurfaceHex: "#1C212B",
                cardBackgroundHex: "#11151D",
                textHex: "#BFBDB6",
                secondaryTextHex: "#8F8D87",
                tertiaryTextHex: "#696B70",
                borderHex: "#2A2F3A",
                dividerHex: "#222733",
                successHex: "#62D69A",
                warningHex: "#E6B450",
                dangerHex: "#FF6B6B",
                preferredColorScheme: .dark
            )
        case .warmLight:
            AppThemePalette(
                title: "Warm Light",
                subtitle: "Soft off-white with clay accent.",
                accentHex: "#CC7D5E",
                accentHighlightHex: "#E6A283",
                accentMutedHex: "#A65F48",
                warmHex: "#EFE7DD",
                backgroundHex: "#F9F9F7",
                surfaceHex: "#FFFFFF",
                elevatedSurfaceHex: "#F1EFEA",
                cardBackgroundHex: "#FFFFFF",
                textHex: "#2D2D2B",
                secondaryTextHex: "#69665F",
                tertiaryTextHex: "#928D84",
                borderHex: "#DEDAD2",
                dividerHex: "#E7E3DB",
                successHex: "#2E7D32",
                warningHex: "#B7791F",
                dangerHex: "#C2413A",
                preferredColorScheme: .light
            )
        case .sagePaper:
            AppThemePalette(
                title: "Sage Paper",
                subtitle: "Natural green on paper neutrals.",
                accentHex: "#3D755D",
                accentHighlightHex: "#5C9479",
                accentMutedHex: "#2D5E49",
                warmHex: "#E7E0D2",
                backgroundHex: "#F5F3ED",
                surfaceHex: "#FFFFFF",
                elevatedSurfaceHex: "#EDE9DE",
                cardBackgroundHex: "#FFFFFF",
                textHex: "#2F312D",
                secondaryTextHex: "#66695F",
                tertiaryTextHex: "#8B8E82",
                borderHex: "#DAD5C8",
                dividerHex: "#E5E0D4",
                successHex: "#3D755D",
                warningHex: "#A36A00",
                dangerHex: "#B84A43",
                preferredColorScheme: .light
            )
        case .navyEmerald:
            AppThemePalette(
                title: "Navy Emerald",
                subtitle: "Clean white with navy and green.",
                accentHex: "#1A237E",
                accentHighlightHex: "#00C853",
                accentMutedHex: "#0E164F",
                warmHex: "#E8F5E9",
                backgroundHex: "#FFFFFF",
                surfaceHex: "#F7F9FC",
                elevatedSurfaceHex: "#EEF2F7",
                cardBackgroundHex: "#FFFFFF",
                textHex: "#263238",
                secondaryTextHex: "#60717A",
                tertiaryTextHex: "#8A99A1",
                borderHex: "#DCE3EA",
                dividerHex: "#E8EDF2",
                successHex: "#00C853",
                warningHex: "#F5A400",
                dangerHex: "#D94343",
                preferredColorScheme: .light
            )
        case .darkBlueMintGold:
            AppThemePalette(
                title: "Blue Mint Gold",
                subtitle: "Dark blue, mint, and gold.",
                accentHex: "#0D47A1",
                accentHighlightHex: "#FFD700",
                accentMutedHex: "#00BFA5",
                warmHex: "#FFF3B0",
                backgroundHex: "#F5F5F5",
                surfaceHex: "#FFFFFF",
                elevatedSurfaceHex: "#ECEFF3",
                cardBackgroundHex: "#FFFFFF",
                textHex: "#263238",
                secondaryTextHex: "#61727B",
                tertiaryTextHex: "#8B989E",
                borderHex: "#D9DEE4",
                dividerHex: "#E7EAEE",
                successHex: "#00BFA5",
                warningHex: "#D19A00",
                dangerHex: "#D44848",
                preferredColorScheme: .light
            )
        case .charcoalTeal:
            AppThemePalette(
                title: "Charcoal Teal",
                subtitle: "Off-white with charcoal and teal.",
                accentHex: "#212121",
                accentHighlightHex: "#00BCD4",
                accentMutedHex: "#008BA3",
                warmHex: "#E0F7FA",
                backgroundHex: "#FAFAFA",
                surfaceHex: "#FFFFFF",
                elevatedSurfaceHex: "#F0F2F2",
                cardBackgroundHex: "#FFFFFF",
                textHex: "#424242",
                secondaryTextHex: "#707070",
                tertiaryTextHex: "#9A9A9A",
                borderHex: "#E0E0E0",
                dividerHex: "#ECECEC",
                successHex: "#00897B",
                warningHex: "#C68400",
                dangerHex: "#C94848",
                preferredColorScheme: .light
            )
        case .slateCoral:
            AppThemePalette(
                title: "Slate Coral",
                subtitle: "White, slate blue, and coral.",
                accentHex: "#607D8B",
                accentHighlightHex: "#FF6B6B",
                accentMutedHex: "#455A64",
                warmHex: "#FFE7E7",
                backgroundHex: "#FFFFFF",
                surfaceHex: "#F7F9FA",
                elevatedSurfaceHex: "#EEF3F5",
                cardBackgroundHex: "#FFFFFF",
                textHex: "#333333",
                secondaryTextHex: "#68777D",
                tertiaryTextHex: "#91A0A6",
                borderHex: "#DDE5E8",
                dividerHex: "#E8EEF0",
                successHex: "#2E7D61",
                warningHex: "#B88400",
                dangerHex: "#E05252",
                preferredColorScheme: .light
            )
        case .midnightEmerald:
            AppThemePalette(
                title: "Midnight Emerald",
                subtitle: "Light gray with blue, green, and amber.",
                accentHex: "#003366",
                accentHighlightHex: "#FFC107",
                accentMutedHex: "#2E7D32",
                warmHex: "#FFF2C2",
                backgroundHex: "#E8E8E8",
                surfaceHex: "#F8F8F8",
                elevatedSurfaceHex: "#DDDFE2",
                cardBackgroundHex: "#FFFFFF",
                textHex: "#263238",
                secondaryTextHex: "#5F6F77",
                tertiaryTextHex: "#87949B",
                borderHex: "#D0D5DA",
                dividerHex: "#DDE1E5",
                successHex: "#2E7D32",
                warningHex: "#B88700",
                dangerHex: "#C94343",
                preferredColorScheme: .light
            )
        }
    }

    static func resolved(from rawValue: String?) -> AppThemePreset {
        guard let rawValue, let preset = AppThemePreset(rawValue: rawValue) else {
            return .classic
        }

        return preset
    }
}

enum AppThemeRefreshPolicy {
    static let rebuildsTabContentOnThemeChange = true
    static let sharedSurfacesObserveThemeStorage = true
    static let screenBackgroundAvoidsGlobalAccentOverlay = true
}

enum AppTheme {
    static let selectedPresetStorageKey = "newMoney.themePresetId"

    static var selectedPreset: AppThemePreset {
        AppThemePreset.resolved(from: UserDefaults.standard.string(forKey: selectedPresetStorageKey))
    }

    static var selectedPalette: AppThemePalette {
        selectedPreset.palette
    }

    static var selectedColorScheme: ColorScheme {
        selectedPalette.preferredColorScheme
    }

    static func selectableColorHexes(includeWhite: Bool = false) -> [String] {
        let palette = selectedPalette
        let candidates = [
            palette.accentHex,
            palette.accentHighlightHex,
            palette.accentMutedHex,
            palette.successHex,
            palette.warningHex,
            palette.dangerHex,
            palette.warmHex,
            palette.textHex
        ] + (includeWhite ? ["#FFFFFF"] : [])

        return candidates.reduce(into: [String]()) { result, hex in
            let normalized = hex.uppercased()
            if !result.contains(normalized) {
                result.append(normalized)
            }
        }
    }

    enum Colors {
        static var appBackground: Color { Color(hex: AppTheme.selectedPalette.backgroundHex) }
        static var surface: Color { Color(hex: AppTheme.selectedPalette.surfaceHex) }
        static var elevatedSurface: Color { Color(hex: AppTheme.selectedPalette.elevatedSurfaceHex) }
        static var cardBackground: Color { Color(hex: AppTheme.selectedPalette.cardBackgroundHex) }
        static var accent: Color { Color(hex: AppTheme.selectedPalette.accentHex) }
        static var accentHighlight: Color { Color(hex: AppTheme.selectedPalette.accentHighlightHex) }
        static var accentMuted: Color { Color(hex: AppTheme.selectedPalette.accentMutedHex) }
        static var accentSoft: Color { accent.opacity(AppTheme.selectedColorScheme == .dark ? 0.16 : 0.11) }
        static var warmAccent: Color { Color(hex: AppTheme.selectedPalette.warmHex) }
        static var primaryText: Color { Color(hex: AppTheme.selectedPalette.textHex) }
        static var secondaryText: Color { Color(hex: AppTheme.selectedPalette.secondaryTextHex) }
        static var tertiaryText: Color { Color(hex: AppTheme.selectedPalette.tertiaryTextHex) }
        static var border: Color { Color(hex: AppTheme.selectedPalette.borderHex) }
        static var divider: Color { Color(hex: AppTheme.selectedPalette.dividerHex) }
        static var success: Color { Color(hex: AppTheme.selectedPalette.successHex) }
        static var warning: Color { Color(hex: AppTheme.selectedPalette.warningHex) }
        static var danger: Color { Color(hex: AppTheme.selectedPalette.dangerHex) }
        static var neonMoneyUp: Color { Color(hex: "#39FF14") }
        static var neonMoneyDown: Color { Color(hex: "#FF1744") }
        static var controlText: Color { Color(hex: AppTheme.selectedPalette.accentReadableTextHex) }
        static var inverseText: Color { AppTheme.selectedColorScheme == .dark ? Color(hex: "#111111") : Color(hex: "#FFFFFF") }
        static var shadow: Color { AppTheme.selectedColorScheme == .dark ? Color(hex: "#000000").opacity(0.24) : primaryText.opacity(0.09) }
        static var strongShadow: Color { AppTheme.selectedColorScheme == .dark ? Color(hex: "#000000").opacity(0.34) : primaryText.opacity(0.14) }
        static var accentGlow: Color { accentHighlight.opacity(AppTheme.selectedColorScheme == .dark ? 0.45 : 0.26) }
        static var selectedFill: Color { accent.opacity(AppTheme.selectedColorScheme == .dark ? 0.18 : 0.12) }
        static var selectedStroke: Color { accent.opacity(AppTheme.selectedColorScheme == .dark ? 0.52 : 0.36) }
        static var cardEyebrow: Color { Color(hex: AppTheme.selectedPalette.cardEyebrowHex) }

        // Legacy names kept as aliases so older screens still resolve through the selected preset.
        static var primaryOrange: Color { accent }
        static var orangeHighlight: Color { accentHighlight }
        static var orangeMuted: Color { accentMuted }
        static var warmSand: Color { cardEyebrow }
        static var glowOrange: Color { accentGlow }
    }

    enum Gradients {
        static var screenBackground: LinearGradient {
            LinearGradient(
                colors: [
                    Colors.appBackground,
                    Colors.surface.opacity(AppTheme.selectedColorScheme == .dark ? 0.72 : 0.70),
                    Colors.elevatedSurface.opacity(AppTheme.selectedColorScheme == .dark ? 0.46 : 0.56),
                    Colors.appBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var primary: LinearGradient {
            LinearGradient(
                colors: [Colors.accentMuted, Colors.accent, Colors.accentHighlight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var card: LinearGradient {
            LinearGradient(
                colors: AppTheme.selectedColorScheme == .dark
                    ? [Colors.elevatedSurface, Colors.cardBackground]
                    : [Colors.cardBackground, Colors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var hero: LinearGradient {
            LinearGradient(
                colors: [
                    Colors.accent.opacity(AppTheme.selectedColorScheme == .dark ? 0.46 : 0.13),
                    Colors.accentMuted.opacity(AppTheme.selectedColorScheme == .dark ? 0.24 : 0.08),
                    Colors.appBackground.opacity(0.0)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }

        static var softAccentSurface: LinearGradient {
            LinearGradient(
                colors: [
                    Colors.elevatedSurface,
                    Colors.accent.opacity(AppTheme.selectedColorScheme == .dark ? 0.18 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
