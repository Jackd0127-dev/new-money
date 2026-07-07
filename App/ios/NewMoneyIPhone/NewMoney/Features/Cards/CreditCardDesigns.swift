import SwiftUI

enum CreditCardVisualLayoutPolicy {
    static let cardAspectRatio: CGFloat = 1.58
    static let cardCornerRadius: CGFloat = 12
    static var canonicalRenderer: String { "PremiumCardView" }
    static var usesSingleCardRenderer: Bool { true }
    static var miniPreviewWrapsCanonicalRenderer: Bool { true }
    static var designGridUsesCanonicalRenderer: Bool { true }
    static var creditTabUsesStaticFloatingCards: Bool { true }
    static var designSelectionShowsThumbnail: Bool { false }
    static var designBrowserLayout: String { "lazyVStackTwoColumnRows" }
    static var designBrowserShowsOuterTiles: Bool { false }
    static var designBrowserShowsNames: Bool { false }
    static var rowCardMaxWidth: CGFloat { 260 }
    static var rowPreviewWidth: CGFloat { rowCardMaxWidth }
    static var rowPreviewHeight: CGFloat { rowCardMaxWidth / cardAspectRatio }
    static var designSelectionPreviewWidth: CGFloat { 112 }
    static let previewArtworkDetail = CreditCardArtworkDetail.full
    static let fullArtworkDetail = CreditCardArtworkDetail.full

    static func previewCornerRadius(for height: CGFloat) -> CGFloat {
        cardCornerRadius
    }

    static func contentInset(for height: CGFloat) -> CGFloat {
        min(18, max(5, height * 0.075))
    }
}

enum CreditCardArtworkDetail: String {
    case compact
    case full
}

enum CreditCardDesignCategory: String, CaseIterable, Identifiable {
    case premium = "Premium"
    case neon = "Neon"
    case calm = "Calm"
    case artwork = "Artwork"
    case minimal = "Minimal"
    case metal = "Metal"
    case bold = "Bold"

    var id: String { rawValue }
}

enum CardSurfacePattern: String, Hashable {
    case softGlow
    case orbit
    case waves
    case grid
    case circuit
    case topographic
    case prism
    case carbon
    case liquid
    case diagonal
    case starfield
    case terrazzo
    case skyline
    case brush
    case rings
    case crosshatch
    case marble
    case dots
    case shards
}

struct CreditCardDesign: Identifiable, Hashable {
    var id: String
    var name: String
    var category: CreditCardDesignCategory
    var storageHex: String
    var providerFallback: String
    var gradientHexes: [String]
    var glowHex: String
    var textHex: String
    var mutedTextHex: String
    var chipGradientHexes: [String]
    var pattern: CardSurfacePattern
    var symbolName: String?
    var artworkOpacity: Double
    var borderOpacity: Double

    var gradientColors: [Color] {
        gradientHexes.map { Color(hex: $0) }
    }

    var glowColor: Color {
        Color(hex: glowHex)
    }

    var foregroundColor: Color {
        Color(hex: textHex)
    }

    var mutedForegroundColor: Color {
        Color(hex: mutedTextHex)
    }

    var chipGradientColors: [Color] {
        chipGradientHexes.map { Color(hex: $0) }
    }
}

enum CreditCardDesignCatalog {
    static let fallbackStorageHex = "#FF7A1A"
    static let displayCategories: [CreditCardDesignCategory] = [
        .minimal,
        .calm,
        .metal,
        .bold,
        .premium,
        .artwork,
        .neon
    ]
    static let legacyHiddenDesignIds: Set<String> = [
        "royal-plum",
        "neon-night",
        "forest-matte",
        "skyline-blue",
        "deep-space",
        "clean-navy",
        "petrol-shift",
        "emerald-circuit",
        "blueprint",
        "solar-flare"
    ]

    static var defaultDesign: CreditCardDesign {
        selectableDesigns.first ?? designs.first ?? customColorDesign(hex: fallbackStorageHex)
    }

    static var selectableDesigns: [CreditCardDesign] {
        designs.filter { !legacyHiddenDesignIds.contains($0.id) }
    }

    static func selectableDesigns(in category: CreditCardDesignCategory) -> [CreditCardDesign] {
        selectableDesigns.filter { $0.category == category }
    }

    static let designs: [CreditCardDesign] = [
        CreditCardDesign(
            id: "original-flame",
            name: "Original Flame",
            category: .premium,
            storageHex: "#FF7A1A",
            providerFallback: "VISA",
            gradientHexes: ["#4A1E0B", "#FF7A1A", "#111827"],
            glowHex: "#FFD08A",
            textHex: "#FFF7ED",
            mutedTextHex: "#FED7AA",
            chipGradientHexes: ["#FBBF24", "#B45309"],
            pattern: .softGlow,
            symbolName: "flame.fill",
            artworkOpacity: 0.22,
            borderOpacity: 0.42
        ),
        CreditCardDesign(
            id: "obsidian-reserve",
            name: "Obsidian Reserve",
            category: .premium,
            storageHex: "#0B1020",
            providerFallback: "VISA",
            gradientHexes: ["#020617", "#111827", "#334155"],
            glowHex: "#F97316",
            textHex: "#F8FAFC",
            mutedTextHex: "#CBD5E1",
            chipGradientHexes: ["#F59E0B", "#78350F"],
            pattern: .carbon,
            symbolName: "shield.lefthalf.filled",
            artworkOpacity: 0.18,
            borderOpacity: 0.34
        ),
        CreditCardDesign(
            id: "northern-aurora",
            name: "Northern Aurora",
            category: .premium,
            storageHex: "#14B8A6",
            providerFallback: "MCARD",
            gradientHexes: ["#062A3A", "#14B8A6", "#A855F7"],
            glowHex: "#5EEAD4",
            textHex: "#ECFEFF",
            mutedTextHex: "#BAE6FD",
            chipGradientHexes: ["#FDE68A", "#0F766E"],
            pattern: .waves,
            symbolName: "sparkles",
            artworkOpacity: 0.20,
            borderOpacity: 0.44
        ),
        CreditCardDesign(
            id: "gold-reserve",
            name: "Gold Reserve",
            category: .premium,
            storageHex: "#D4AF37",
            providerFallback: "VISA",
            gradientHexes: ["#7C4A03", "#D4AF37", "#FFF3B0"],
            glowHex: "#FDE68A",
            textHex: "#201000",
            mutedTextHex: "#5C3B06",
            chipGradientHexes: ["#FFFBEB", "#B45309"],
            pattern: .rings,
            symbolName: "crown.fill",
            artworkOpacity: 0.16,
            borderOpacity: 0.38
        ),
        CreditCardDesign(
            id: "royal-plum",
            name: "Royal Plum",
            category: .premium,
            storageHex: "#7C3AED",
            providerFallback: "VISA",
            gradientHexes: ["#2E1065", "#7C3AED", "#DB2777"],
            glowHex: "#C084FC",
            textHex: "#FAF5FF",
            mutedTextHex: "#E9D5FF",
            chipGradientHexes: ["#FDE68A", "#9333EA"],
            pattern: .prism,
            symbolName: "diamond.fill",
            artworkOpacity: 0.20,
            borderOpacity: 0.44
        ),
        CreditCardDesign(
            id: "sapphire-steel",
            name: "Sapphire Steel",
            category: .metal,
            storageHex: "#2563EB",
            providerFallback: "VISA",
            gradientHexes: ["#0F172A", "#1D4ED8", "#93C5FD"],
            glowHex: "#60A5FA",
            textHex: "#EFF6FF",
            mutedTextHex: "#BFDBFE",
            chipGradientHexes: ["#E0F2FE", "#2563EB"],
            pattern: .diagonal,
            symbolName: "bolt.shield.fill",
            artworkOpacity: 0.19,
            borderOpacity: 0.40
        ),
        CreditCardDesign(
            id: "titanium-frost",
            name: "Titanium Frost",
            category: .metal,
            storageHex: "#CBD5E1",
            providerFallback: "VISA",
            gradientHexes: ["#E2E8F0", "#94A3B8", "#F8FAFC"],
            glowHex: "#FFFFFF",
            textHex: "#0F172A",
            mutedTextHex: "#334155",
            chipGradientHexes: ["#FEF3C7", "#94A3B8"],
            pattern: .crosshatch,
            symbolName: "snowflake",
            artworkOpacity: 0.18,
            borderOpacity: 0.40
        ),
        CreditCardDesign(
            id: "copper-ridge",
            name: "Copper Ridge",
            category: .metal,
            storageHex: "#B45309",
            providerFallback: "AMEX",
            gradientHexes: ["#431407", "#B45309", "#FDBA74"],
            glowHex: "#FDBA74",
            textHex: "#FFF7ED",
            mutedTextHex: "#FED7AA",
            chipGradientHexes: ["#FFEDD5", "#92400E"],
            pattern: .topographic,
            symbolName: "mountain.2.fill",
            artworkOpacity: 0.20,
            borderOpacity: 0.46
        ),
        CreditCardDesign(
            id: "brushed-graphite",
            name: "Brushed Graphite",
            category: .metal,
            storageHex: "#374151",
            providerFallback: "VISA",
            gradientHexes: ["#030712", "#374151", "#9CA3AF"],
            glowHex: "#D1D5DB",
            textHex: "#F9FAFB",
            mutedTextHex: "#D1D5DB",
            chipGradientHexes: ["#F9FAFB", "#4B5563"],
            pattern: .brush,
            symbolName: "line.diagonal",
            artworkOpacity: 0.18,
            borderOpacity: 0.34
        ),
        CreditCardDesign(
            id: "carbon-amber",
            name: "Carbon Amber",
            category: .metal,
            storageHex: "#F59E0B",
            providerFallback: "VISA",
            gradientHexes: ["#111827", "#3F2B0C", "#F59E0B"],
            glowHex: "#FBBF24",
            textHex: "#FFFBEB",
            mutedTextHex: "#FDE68A",
            chipGradientHexes: ["#FEF3C7", "#A16207"],
            pattern: .carbon,
            symbolName: "hexagon.fill",
            artworkOpacity: 0.18,
            borderOpacity: 0.38
        ),
        CreditCardDesign(
            id: "neon-night",
            name: "Neon Night",
            category: .neon,
            storageHex: "#22D3EE",
            providerFallback: "VISA",
            gradientHexes: ["#020617", "#0E7490", "#22D3EE"],
            glowHex: "#67E8F9",
            textHex: "#ECFEFF",
            mutedTextHex: "#A5F3FC",
            chipGradientHexes: ["#FDE68A", "#0891B2"],
            pattern: .circuit,
            symbolName: "dot.radiowaves.left.and.right",
            artworkOpacity: 0.24,
            borderOpacity: 0.50
        ),
        CreditCardDesign(
            id: "electric-lime",
            name: "Electric Lime",
            category: .neon,
            storageHex: "#84CC16",
            providerFallback: "MCARD",
            gradientHexes: ["#052E16", "#16A34A", "#BEF264"],
            glowHex: "#D9F99D",
            textHex: "#F7FEE7",
            mutedTextHex: "#D9F99D",
            chipGradientHexes: ["#FEF08A", "#15803D"],
            pattern: .grid,
            symbolName: "bolt.fill",
            artworkOpacity: 0.20,
            borderOpacity: 0.44
        ),
        CreditCardDesign(
            id: "laser-pink",
            name: "Laser Pink",
            category: .neon,
            storageHex: "#EC4899",
            providerFallback: "VISA",
            gradientHexes: ["#500724", "#DB2777", "#F0ABFC"],
            glowHex: "#F9A8D4",
            textHex: "#FDF2F8",
            mutedTextHex: "#FBCFE8",
            chipGradientHexes: ["#FDE68A", "#BE185D"],
            pattern: .shards,
            symbolName: "wand.and.stars",
            artworkOpacity: 0.22,
            borderOpacity: 0.46
        ),
        CreditCardDesign(
            id: "cyber-violet",
            name: "Cyber Violet",
            category: .neon,
            storageHex: "#8B5CF6",
            providerFallback: "VISA",
            gradientHexes: ["#111827", "#5B21B6", "#38BDF8"],
            glowHex: "#A78BFA",
            textHex: "#F5F3FF",
            mutedTextHex: "#DDD6FE",
            chipGradientHexes: ["#FDE68A", "#6D28D9"],
            pattern: .circuit,
            symbolName: "cpu.fill",
            artworkOpacity: 0.22,
            borderOpacity: 0.45
        ),
        CreditCardDesign(
            id: "acid-orange",
            name: "Acid Orange",
            category: .neon,
            storageHex: "#FB923C",
            providerFallback: "MCARD",
            gradientHexes: ["#171717", "#EA580C", "#FDBA74"],
            glowHex: "#FED7AA",
            textHex: "#FFF7ED",
            mutedTextHex: "#FFEDD5",
            chipGradientHexes: ["#FEF3C7", "#EA580C"],
            pattern: .diagonal,
            symbolName: "sun.max.fill",
            artworkOpacity: 0.22,
            borderOpacity: 0.42
        ),
        CreditCardDesign(
            id: "ocean-depth",
            name: "Ocean Depth",
            category: .calm,
            storageHex: "#0284C7",
            providerFallback: "VISA",
            gradientHexes: ["#082F49", "#0284C7", "#67E8F9"],
            glowHex: "#7DD3FC",
            textHex: "#F0F9FF",
            mutedTextHex: "#BAE6FD",
            chipGradientHexes: ["#E0F2FE", "#0369A1"],
            pattern: .waves,
            symbolName: "water.waves",
            artworkOpacity: 0.19,
            borderOpacity: 0.40
        ),
        CreditCardDesign(
            id: "mint-calm",
            name: "Mint Calm",
            category: .calm,
            storageHex: "#34D399",
            providerFallback: "VISA",
            gradientHexes: ["#064E3B", "#34D399", "#D1FAE5"],
            glowHex: "#A7F3D0",
            textHex: "#ECFDF5",
            mutedTextHex: "#D1FAE5",
            chipGradientHexes: ["#FEF3C7", "#059669"],
            pattern: .liquid,
            symbolName: "leaf.fill",
            artworkOpacity: 0.18,
            borderOpacity: 0.36
        ),
        CreditCardDesign(
            id: "arctic-glass",
            name: "Arctic Glass",
            category: .calm,
            storageHex: "#A5F3FC",
            providerFallback: "VISA",
            gradientHexes: ["#ECFEFF", "#A5F3FC", "#60A5FA"],
            glowHex: "#FFFFFF",
            textHex: "#083344",
            mutedTextHex: "#155E75",
            chipGradientHexes: ["#FEF3C7", "#67E8F9"],
            pattern: .softGlow,
            symbolName: "snowflake",
            artworkOpacity: 0.14,
            borderOpacity: 0.42
        ),
        CreditCardDesign(
            id: "forest-matte",
            name: "Forest Matte",
            category: .calm,
            storageHex: "#166534",
            providerFallback: "VISA",
            gradientHexes: ["#052E16", "#166534", "#4ADE80"],
            glowHex: "#86EFAC",
            textHex: "#F0FDF4",
            mutedTextHex: "#BBF7D0",
            chipGradientHexes: ["#FEF3C7", "#15803D"],
            pattern: .topographic,
            symbolName: "tree.fill",
            artworkOpacity: 0.20,
            borderOpacity: 0.38
        ),
        CreditCardDesign(
            id: "sandstone",
            name: "Sandstone",
            category: .calm,
            storageHex: "#EAB308",
            providerFallback: "MCARD",
            gradientHexes: ["#FEF3C7", "#EAB308", "#92400E"],
            glowHex: "#FDE68A",
            textHex: "#1C1203",
            mutedTextHex: "#5C3B06",
            chipGradientHexes: ["#FFF7ED", "#B45309"],
            pattern: .terrazzo,
            symbolName: "circle.hexagongrid.fill",
            artworkOpacity: 0.16,
            borderOpacity: 0.36
        ),
        CreditCardDesign(
            id: "paper-white",
            name: "Paper White",
            category: .minimal,
            storageHex: "#F8FAFC",
            providerFallback: "VISA",
            gradientHexes: ["#FFFFFF", "#F8FAFC", "#E2E8F0"],
            glowHex: "#CBD5E1",
            textHex: "#0F172A",
            mutedTextHex: "#475569",
            chipGradientHexes: ["#FEF3C7", "#94A3B8"],
            pattern: .dots,
            symbolName: "circle.grid.2x2.fill",
            artworkOpacity: 0.14,
            borderOpacity: 0.34
        ),
        CreditCardDesign(
            id: "mono-black",
            name: "Mono Black",
            category: .minimal,
            storageHex: "#111111",
            providerFallback: "VISA",
            gradientHexes: ["#000000", "#111111", "#2A2A2A"],
            glowHex: "#FFFFFF",
            textHex: "#F8FAFC",
            mutedTextHex: "#D4D4D8",
            chipGradientHexes: ["#FAFAFA", "#737373"],
            pattern: .grid,
            symbolName: "square.fill",
            artworkOpacity: 0.12,
            borderOpacity: 0.30
        ),
        CreditCardDesign(
            id: "clean-navy",
            name: "Clean Navy",
            category: .minimal,
            storageHex: "#1E3A8A",
            providerFallback: "VISA",
            gradientHexes: ["#0F172A", "#1E3A8A", "#172554"],
            glowHex: "#3B82F6",
            textHex: "#EFF6FF",
            mutedTextHex: "#BFDBFE",
            chipGradientHexes: ["#FEF3C7", "#1D4ED8"],
            pattern: .softGlow,
            symbolName: "rectangle.fill",
            artworkOpacity: 0.12,
            borderOpacity: 0.30
        ),
        CreditCardDesign(
            id: "warm-cream",
            name: "Warm Cream",
            category: .minimal,
            storageHex: "#FED7AA",
            providerFallback: "MCARD",
            gradientHexes: ["#FFF7ED", "#FED7AA", "#FDBA74"],
            glowHex: "#FFFFFF",
            textHex: "#431407",
            mutedTextHex: "#7C2D12",
            chipGradientHexes: ["#FEF3C7", "#FB923C"],
            pattern: .rings,
            symbolName: "circle.fill",
            artworkOpacity: 0.12,
            borderOpacity: 0.34
        ),
        CreditCardDesign(
            id: "silver-line",
            name: "Silver Line",
            category: .minimal,
            storageHex: "#94A3B8",
            providerFallback: "VISA",
            gradientHexes: ["#F8FAFC", "#94A3B8", "#475569"],
            glowHex: "#FFFFFF",
            textHex: "#0F172A",
            mutedTextHex: "#334155",
            chipGradientHexes: ["#FEF3C7", "#64748B"],
            pattern: .diagonal,
            symbolName: "minus",
            artworkOpacity: 0.14,
            borderOpacity: 0.34
        ),
        CreditCardDesign(
            id: "lava-flow",
            name: "Lava Flow",
            category: .artwork,
            storageHex: "#DC2626",
            providerFallback: "VISA",
            gradientHexes: ["#450A0A", "#DC2626", "#F97316"],
            glowHex: "#FDBA74",
            textHex: "#FEF2F2",
            mutedTextHex: "#FECACA",
            chipGradientHexes: ["#FEF3C7", "#991B1B"],
            pattern: .liquid,
            symbolName: "flame.fill",
            artworkOpacity: 0.22,
            borderOpacity: 0.45
        ),
        CreditCardDesign(
            id: "deep-space",
            name: "Deep Space",
            category: .artwork,
            storageHex: "#312E81",
            providerFallback: "VISA",
            gradientHexes: ["#020617", "#312E81", "#9333EA"],
            glowHex: "#A78BFA",
            textHex: "#F5F3FF",
            mutedTextHex: "#DDD6FE",
            chipGradientHexes: ["#FDE68A", "#4C1D95"],
            pattern: .starfield,
            symbolName: "moon.stars.fill",
            artworkOpacity: 0.30,
            borderOpacity: 0.45
        ),
        CreditCardDesign(
            id: "marble-rose",
            name: "Marble Rose",
            category: .artwork,
            storageHex: "#FDA4AF",
            providerFallback: "AMEX",
            gradientHexes: ["#FFF1F2", "#FDA4AF", "#BE123C"],
            glowHex: "#FFE4E6",
            textHex: "#4C0519",
            mutedTextHex: "#881337",
            chipGradientHexes: ["#FEF3C7", "#F43F5E"],
            pattern: .marble,
            symbolName: "scribble.variable",
            artworkOpacity: 0.16,
            borderOpacity: 0.38
        ),
        CreditCardDesign(
            id: "terrazzo-pop",
            name: "Terrazzo Pop",
            category: .artwork,
            storageHex: "#FDE047",
            providerFallback: "MCARD",
            gradientHexes: ["#FEFCE8", "#FDE047", "#FB7185"],
            glowHex: "#FEF9C3",
            textHex: "#1E1B4B",
            mutedTextHex: "#4C1D95",
            chipGradientHexes: ["#FEF3C7", "#F59E0B"],
            pattern: .terrazzo,
            symbolName: "seal.fill",
            artworkOpacity: 0.18,
            borderOpacity: 0.38
        ),
        CreditCardDesign(
            id: "skyline-blue",
            name: "Skyline Blue",
            category: .artwork,
            storageHex: "#38BDF8",
            providerFallback: "VISA",
            gradientHexes: ["#0C4A6E", "#38BDF8", "#E0F2FE"],
            glowHex: "#BAE6FD",
            textHex: "#F0F9FF",
            mutedTextHex: "#E0F2FE",
            chipGradientHexes: ["#FEF3C7", "#0284C7"],
            pattern: .skyline,
            symbolName: "building.2.fill",
            artworkOpacity: 0.24,
            borderOpacity: 0.42
        ),
        CreditCardDesign(
            id: "prism-day",
            name: "Prism Day",
            category: .artwork,
            storageHex: "#A78BFA",
            providerFallback: "VISA",
            gradientHexes: ["#EDE9FE", "#A78BFA", "#F9A8D4"],
            glowHex: "#FFFFFF",
            textHex: "#2E1065",
            mutedTextHex: "#5B21B6",
            chipGradientHexes: ["#FEF3C7", "#A78BFA"],
            pattern: .prism,
            symbolName: "triangle.fill",
            artworkOpacity: 0.16,
            borderOpacity: 0.36
        ),
        CreditCardDesign(
            id: "sunset-alloy",
            name: "Sunset Alloy",
            category: .bold,
            storageHex: "#F43F5E",
            providerFallback: "VISA",
            gradientHexes: ["#881337", "#F43F5E", "#FB923C"],
            glowHex: "#FDA4AF",
            textHex: "#FFF1F2",
            mutedTextHex: "#FFE4E6",
            chipGradientHexes: ["#FEF3C7", "#BE123C"],
            pattern: .orbit,
            symbolName: "sunset.fill",
            artworkOpacity: 0.21,
            borderOpacity: 0.44
        ),
        CreditCardDesign(
            id: "blueprint",
            name: "Blueprint",
            category: .bold,
            storageHex: "#1D4ED8",
            providerFallback: "VISA",
            gradientHexes: ["#172554", "#1D4ED8", "#60A5FA"],
            glowHex: "#93C5FD",
            textHex: "#EFF6FF",
            mutedTextHex: "#DBEAFE",
            chipGradientHexes: ["#FEF3C7", "#2563EB"],
            pattern: .grid,
            symbolName: "ruler.fill",
            artworkOpacity: 0.22,
            borderOpacity: 0.44
        ),
        CreditCardDesign(
            id: "emerald-circuit",
            name: "Emerald Circuit",
            category: .bold,
            storageHex: "#10B981",
            providerFallback: "MCARD",
            gradientHexes: ["#022C22", "#10B981", "#6EE7B7"],
            glowHex: "#A7F3D0",
            textHex: "#ECFDF5",
            mutedTextHex: "#D1FAE5",
            chipGradientHexes: ["#FEF3C7", "#047857"],
            pattern: .circuit,
            symbolName: "memorychip.fill",
            artworkOpacity: 0.22,
            borderOpacity: 0.44
        ),
        CreditCardDesign(
            id: "magma-purple",
            name: "Magma Purple",
            category: .bold,
            storageHex: "#C026D3",
            providerFallback: "VISA",
            gradientHexes: ["#4A044E", "#C026D3", "#F97316"],
            glowHex: "#F0ABFC",
            textHex: "#FDF4FF",
            mutedTextHex: "#F5D0FE",
            chipGradientHexes: ["#FEF3C7", "#A21CAF"],
            pattern: .liquid,
            symbolName: "drop.fill",
            artworkOpacity: 0.21,
            borderOpacity: 0.46
        ),
        CreditCardDesign(
            id: "warning-stripe",
            name: "Warning Stripe",
            category: .bold,
            storageHex: "#FACC15",
            providerFallback: "VISA",
            gradientHexes: ["#111827", "#CA8A04", "#FACC15"],
            glowHex: "#FEF08A",
            textHex: "#FEFCE8",
            mutedTextHex: "#FEF9C3",
            chipGradientHexes: ["#FEF3C7", "#A16207"],
            pattern: .diagonal,
            symbolName: "exclamationmark.triangle.fill",
            artworkOpacity: 0.26,
            borderOpacity: 0.44
        ),
        CreditCardDesign(
            id: "petrol-shift",
            name: "Petrol Shift",
            category: .bold,
            storageHex: "#0F766E",
            providerFallback: "AMEX",
            gradientHexes: ["#042F2E", "#0F766E", "#7C3AED"],
            glowHex: "#5EEAD4",
            textHex: "#F0FDFA",
            mutedTextHex: "#CCFBF1",
            chipGradientHexes: ["#FEF3C7", "#0F766E"],
            pattern: .shards,
            symbolName: "arrow.triangle.2.circlepath",
            artworkOpacity: 0.22,
            borderOpacity: 0.42
        ),
        CreditCardDesign(
            id: "ruby-shadow",
            name: "Ruby Shadow",
            category: .bold,
            storageHex: "#991B1B",
            providerFallback: "VISA",
            gradientHexes: ["#1C1917", "#7F1D1D", "#EF4444"],
            glowHex: "#FCA5A5",
            textHex: "#FEF2F2",
            mutedTextHex: "#FECACA",
            chipGradientHexes: ["#FEF3C7", "#7F1D1D"],
            pattern: .orbit,
            symbolName: "suit.diamond.fill",
            artworkOpacity: 0.19,
            borderOpacity: 0.40
        ),
        CreditCardDesign(
            id: "coral-reef",
            name: "Coral Reef",
            category: .calm,
            storageHex: "#FB7185",
            providerFallback: "VISA",
            gradientHexes: ["#164E63", "#FB7185", "#FED7AA"],
            glowHex: "#FDA4AF",
            textHex: "#FFF1F2",
            mutedTextHex: "#FFE4E6",
            chipGradientHexes: ["#FEF3C7", "#F43F5E"],
            pattern: .waves,
            symbolName: "fish.fill",
            artworkOpacity: 0.18,
            borderOpacity: 0.38
        ),
        CreditCardDesign(
            id: "midnight-mint",
            name: "Midnight Mint",
            category: .premium,
            storageHex: "#2DD4BF",
            providerFallback: "MCARD",
            gradientHexes: ["#020617", "#0F766E", "#2DD4BF"],
            glowHex: "#99F6E4",
            textHex: "#F0FDFA",
            mutedTextHex: "#CCFBF1",
            chipGradientHexes: ["#FEF3C7", "#14B8A6"],
            pattern: .orbit,
            symbolName: "circle.dotted",
            artworkOpacity: 0.20,
            borderOpacity: 0.42
        ),
        CreditCardDesign(
            id: "solar-flare",
            name: "Solar Flare",
            category: .bold,
            storageHex: "#F97316",
            providerFallback: "VISA",
            gradientHexes: ["#7C2D12", "#F97316", "#FDE047"],
            glowHex: "#FDBA74",
            textHex: "#FFF7ED",
            mutedTextHex: "#FFEDD5",
            chipGradientHexes: ["#FEF3C7", "#C2410C"],
            pattern: .rings,
            symbolName: "sun.max.fill",
            artworkOpacity: 0.20,
            borderOpacity: 0.44
        ),
        CreditCardDesign(
            id: "ice-navy",
            name: "Ice Navy",
            category: .minimal,
            storageHex: "#0EA5E9",
            providerFallback: "VISA",
            gradientHexes: ["#F0F9FF", "#0EA5E9", "#0F172A"],
            glowHex: "#BAE6FD",
            textHex: "#F0F9FF",
            mutedTextHex: "#E0F2FE",
            chipGradientHexes: ["#FEF3C7", "#0284C7"],
            pattern: .crosshatch,
            symbolName: "sparkle",
            artworkOpacity: 0.15,
            borderOpacity: 0.36
        ),
        CreditCardDesign(
            id: "purple-rain",
            name: "Purple Rain",
            category: .artwork,
            storageHex: "#9333EA",
            providerFallback: "VISA",
            gradientHexes: ["#1E1B4B", "#9333EA", "#60A5FA"],
            glowHex: "#C4B5FD",
            textHex: "#F5F3FF",
            mutedTextHex: "#DDD6FE",
            chipGradientHexes: ["#FEF3C7", "#7E22CE"],
            pattern: .marble,
            symbolName: "cloud.rain.fill",
            artworkOpacity: 0.20,
            borderOpacity: 0.42
        ),
        CreditCardDesign(
            id: "smoke-blue",
            name: "Smoke Blue",
            category: .metal,
            storageHex: "#64748B",
            providerFallback: "AMEX",
            gradientHexes: ["#0F172A", "#64748B", "#CBD5E1"],
            glowHex: "#E2E8F0",
            textHex: "#F8FAFC",
            mutedTextHex: "#CBD5E1",
            chipGradientHexes: ["#FEF3C7", "#475569"],
            pattern: .brush,
            symbolName: "wind",
            artworkOpacity: 0.18,
            borderOpacity: 0.36
        ),
        CreditCardDesign(
            id: "candy-fade",
            name: "Candy Fade",
            category: .artwork,
            storageHex: "#F9A8D4",
            providerFallback: "MCARD",
            gradientHexes: ["#FDF2F8", "#F9A8D4", "#93C5FD"],
            glowHex: "#FFFFFF",
            textHex: "#831843",
            mutedTextHex: "#9D174D",
            chipGradientHexes: ["#FEF3C7", "#F472B6"],
            pattern: .dots,
            symbolName: "heart.fill",
            artworkOpacity: 0.14,
            borderOpacity: 0.36
        ),
        CreditCardDesign(
            id: "green-valley",
            name: "Green Valley",
            category: .calm,
            storageHex: "#65A30D",
            providerFallback: "VISA",
            gradientHexes: ["#365314", "#65A30D", "#BEF264"],
            glowHex: "#D9F99D",
            textHex: "#F7FEE7",
            mutedTextHex: "#ECFCCB",
            chipGradientHexes: ["#FEF3C7", "#4D7C0F"],
            pattern: .topographic,
            symbolName: "leaf.fill",
            artworkOpacity: 0.19,
            borderOpacity: 0.40
        ),
        CreditCardDesign(
            id: "red-carbon",
            name: "Red Carbon",
            category: .metal,
            storageHex: "#EF4444",
            providerFallback: "VISA",
            gradientHexes: ["#0A0A0A", "#7F1D1D", "#EF4444"],
            glowHex: "#FCA5A5",
            textHex: "#FEF2F2",
            mutedTextHex: "#FECACA",
            chipGradientHexes: ["#FEF3C7", "#991B1B"],
            pattern: .carbon,
            symbolName: "square.grid.3x3.fill",
            artworkOpacity: 0.18,
            borderOpacity: 0.40
        ),
        CreditCardDesign(
            id: "platinum-blue",
            name: "Platinum Blue",
            category: .metal,
            storageHex: "#93C5FD",
            providerFallback: "VISA",
            gradientHexes: ["#EFF6FF", "#93C5FD", "#1E40AF"],
            glowHex: "#FFFFFF",
            textHex: "#172554",
            mutedTextHex: "#1D4ED8",
            chipGradientHexes: ["#FEF3C7", "#60A5FA"],
            pattern: .diagonal,
            symbolName: "creditcard.fill",
            artworkOpacity: 0.15,
            borderOpacity: 0.36
        ),
        CreditCardDesign(
            id: "night-garden",
            name: "Night Garden",
            category: .premium,
            storageHex: "#15803D",
            providerFallback: "MCARD",
            gradientHexes: ["#020617", "#14532D", "#15803D"],
            glowHex: "#86EFAC",
            textHex: "#F0FDF4",
            mutedTextHex: "#BBF7D0",
            chipGradientHexes: ["#FEF3C7", "#166534"],
            pattern: .starfield,
            symbolName: "moon.fill",
            artworkOpacity: 0.24,
            borderOpacity: 0.42
        ),
        CreditCardDesign(
            id: "slate-orange",
            name: "Slate Orange",
            category: .minimal,
            storageHex: "#475569",
            providerFallback: "VISA",
            gradientHexes: ["#0F172A", "#475569", "#F97316"],
            glowHex: "#FDBA74",
            textHex: "#F8FAFC",
            mutedTextHex: "#CBD5E1",
            chipGradientHexes: ["#FEF3C7", "#C2410C"],
            pattern: .softGlow,
            symbolName: "circle.lefthalf.filled",
            artworkOpacity: 0.16,
            borderOpacity: 0.34
        )
    ]

    static func design(forStoredValue value: String?) -> CreditCardDesign {
        let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawValue.isEmpty else { return defaultDesign }

        let normalised = normalisedHex(rawValue)
        if let design = designs.first(where: {
            $0.id.caseInsensitiveCompare(rawValue) == .orderedSame ||
            $0.storageHex.caseInsensitiveCompare(normalised) == .orderedSame
        }) {
            return design
        }

        return customColorDesign(hex: rawValue)
    }

    static func selectableStorageValues() -> [String] {
        selectableDesigns.map(\.storageHex)
    }

    static func isKnownStoredValue(_ value: String) -> Bool {
        let normalised = normalisedHex(value)
        return designs.contains {
            $0.id.caseInsensitiveCompare(value) == .orderedSame ||
            $0.storageHex.caseInsensitiveCompare(normalised) == .orderedSame
        }
    }

    static func normalisedHex(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallbackStorageHex }

        if trimmed.hasPrefix("#") {
            return trimmed.uppercased()
        }

        if trimmed.count == 6 {
            return "#\(trimmed.uppercased())"
        }

        return trimmed.uppercased()
    }

    static func customColorDesign(hex rawValue: String) -> CreditCardDesign {
        let hex = normalisedHex(rawValue)
        let safeId = hex.replacingOccurrences(of: "#", with: "").lowercased()

        return CreditCardDesign(
            id: "custom-\(safeId)",
            name: "Custom Colour",
            category: .minimal,
            storageHex: hex,
            providerFallback: "CARD",
            gradientHexes: [hex, "#111827", "#020617"],
            glowHex: hex,
            textHex: "#F8FAFC",
            mutedTextHex: "#CBD5E1",
            chipGradientHexes: ["#FEF3C7", hex],
            pattern: .softGlow,
            symbolName: "creditcard.fill",
            artworkOpacity: 0.16,
            borderOpacity: 0.34
        )
    }
}

struct CreditCardDesignPicker: View {
    @Binding var selectedValue: String
    var title = "Card design"

    private let columns = [
        GridItem(.adaptive(minimum: 108), spacing: 12)
    ]

    private var selectedDesign: CreditCardDesign {
        CreditCardDesignCatalog.design(forStoredValue: selectedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .lastTextBaseline) {
                SectionTitle(title)
                Spacer()
                Text(selectedDesign.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(CreditCardDesignCatalog.selectableDesigns) { design in
                    CreditCardDesignOptionCard(
                        design: design,
                        isSelected: selectedValue.caseInsensitiveCompare(design.storageHex) == .orderedSame
                    ) {
                        selectedValue = design.storageHex
                    }
                }
            }
        }
    }
}

struct CreditCardDesignSelectionLink: View {
    @Binding var selectedValue: String
    var provider: String

    private var selectedDesign: CreditCardDesign {
        CreditCardDesignCatalog.design(forStoredValue: selectedValue)
    }

    var body: some View {
        NavigationLink {
            CreditCardDesignBrowserView(selectedValue: $selectedValue, provider: provider)
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose design")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(selectedDesign.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: AppTheme.Spacing.md)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(minHeight: 64)
            .background(AppTheme.Colors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose card design")
    }
}

private struct CreditCardDesignBrowserView: View {
    @Binding var selectedValue: String
    var provider: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                ForEach(CreditCardDesignCatalog.displayCategories) { category in
                    let designs = CreditCardDesignCatalog.selectableDesigns(in: category)

                    if !designs.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            SectionTitle(category.rawValue)

                            LazyVStack(spacing: AppTheme.Spacing.md) {
                                ForEach(Array(stride(from: 0, to: designs.count, by: 2)), id: \.self) { index in
                                    HStack(spacing: AppTheme.Spacing.md) {
                                        ForEach(Array(designs[index..<min(index + 2, designs.count)])) { design in
                                            CreditCardDesignBrowserOption(
                                                design: design,
                                                provider: provider,
                                                isSelected: isSelected(design)
                                            ) {
                                                selectedValue = design.storageHex
                                            }
                                            .frame(maxWidth: .infinity)
                                        }

                                        if index + 1 >= designs.count {
                                            Color.clear
                                                .aspectRatio(CreditCardVisualLayoutPolicy.cardAspectRatio, contentMode: .fit)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle("Choose design")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func isSelected(_ design: CreditCardDesign) -> Bool {
        selectedValue.caseInsensitiveCompare(design.storageHex) == .orderedSame
    }
}

private struct CreditCardDesignBrowserOption: View {
    var design: CreditCardDesign
    var provider: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CreditCardDesignMiniPreview(design: design, provider: provider)
                .aspectRatio(CreditCardVisualLayoutPolicy.cardAspectRatio, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: CreditCardVisualLayoutPolicy.cardCornerRadius, style: .continuous)
                        .stroke(
                            isSelected ? AppTheme.Colors.primaryOrange : Color.clear,
                            lineWidth: isSelected ? 2 : 0
                        )
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: CreditCardVisualLayoutPolicy.cardCornerRadius, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(design.name)")
    }
}

private struct CreditCardDesignOptionCard: View {
    var design: CreditCardDesign
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CreditCardDesignMiniPreview(design: design)
                .aspectRatio(CreditCardVisualLayoutPolicy.cardAspectRatio, contentMode: .fit)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(design.foregroundColor)
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: CreditCardVisualLayoutPolicy.cardCornerRadius, style: .continuous)
                        .stroke(
                            isSelected ? AppTheme.Colors.primaryOrange : AppTheme.Colors.divider.opacity(0.7),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Select \(design.name) card design")
    }
}

struct CreditCardDesignMiniPreview: View {
    var design: CreditCardDesign
    var provider: String = ""
    var networkLabel = "VISA"
    var badges: [CreditCardLinkBadge] = []

    private var providerLabel: String {
        let trimmed = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? design.providerFallback : trimmed.uppercased()
    }

    private var resolvedNetworkLabel: String {
        let trimmed = networkLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "VISA" : trimmed.uppercased()
    }

    var body: some View {
        PremiumCardView(
            badges: badges,
            provider: providerLabel,
            networkLabel: resolvedNetworkLabel,
            horizontalPadding: 0,
            designId: design.storageHex,
            isInteractive: false
        )
        .aspectRatio(CreditCardVisualLayoutPolicy.cardAspectRatio, contentMode: .fit)
    }
}

struct CreditCardArtworkBackground: View {
    var design: CreditCardDesign
    var cornerRadius: CGFloat = CreditCardVisualLayoutPolicy.cardCornerRadius
    var detail: CreditCardArtworkDetail = CreditCardVisualLayoutPolicy.fullArtworkDetail

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: design.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if detail == .full {
                CreditCardSurfaceArtwork(design: design)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                if let symbolName = design.symbolName {
                    GeometryReader { proxy in
                        Image(systemName: symbolName)
                            .font(.system(size: proxy.size.height * 0.62, weight: .bold))
                            .foregroundStyle(design.foregroundColor.opacity(0.055))
                            .offset(x: proxy.size.width * 0.56, y: proxy.size.height * 0.04)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            } else {
                compactArtwork
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(detail == .full ? .screen : .normal)
                .opacity(detail == .full ? 0.58 : 0.18)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            design.foregroundColor.opacity(design.borderOpacity),
                            design.foregroundColor.opacity(0.10),
                            design.foregroundColor.opacity(design.borderOpacity * 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var compactArtwork: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(design.glowColor.opacity(0.24))
                    .frame(width: proxy.size.width * 0.62, height: proxy.size.width * 0.62)
                    .offset(x: proxy.size.width * 0.46, y: -proxy.size.height * 0.36)

                RoundedRectangle(cornerRadius: cornerRadius * 0.8, style: .continuous)
                    .fill(design.foregroundColor.opacity(design.artworkOpacity * 0.34))
                    .frame(width: proxy.size.width * 0.46, height: proxy.size.height * 0.46)
                    .rotationEffect(.degrees(-16))
                    .offset(x: proxy.size.width * 0.46, y: proxy.size.height * 0.18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private struct CreditCardSurfaceArtwork: View {
    var design: CreditCardDesign

    var body: some View {
        GeometryReader { proxy in
            patternContent(size: proxy.size)
        }
    }

    @ViewBuilder
    private func patternContent(size: CGSize) -> some View {
        switch design.pattern {
        case .softGlow:
            softGlow(size: size)
        case .orbit:
            orbit(size: size)
        case .waves:
            waves(size: size)
        case .grid:
            grid(size: size)
        case .circuit:
            circuit(size: size)
        case .topographic:
            topographic(size: size)
        case .prism:
            prism(size: size)
        case .carbon:
            carbon(size: size)
        case .liquid:
            liquid(size: size)
        case .diagonal:
            diagonal(size: size)
        case .starfield:
            starfield(size: size)
        case .terrazzo:
            terrazzo(size: size)
        case .skyline:
            skyline(size: size)
        case .brush:
            brush(size: size)
        case .rings:
            rings(size: size)
        case .crosshatch:
            crosshatch(size: size)
        case .marble:
            marble(size: size)
        case .dots:
            dots(size: size)
        case .shards:
            shards(size: size)
        }
    }

    private func softGlow(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [design.glowColor.opacity(0.68), Color.clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: size.width * 0.44
                    )
                )
                .frame(width: size.width * 0.78, height: size.width * 0.78)
                .offset(x: size.width * 0.32, y: -size.height * 0.52)
                .blur(radius: size.height * 0.04)

            Circle()
                .fill(design.foregroundColor.opacity(design.artworkOpacity * 0.55))
                .frame(width: size.width * 0.42, height: size.width * 0.42)
                .offset(x: -size.width * 0.36, y: size.height * 0.44)
                .blur(radius: size.height * 0.08)
        }
        .frame(width: size.width, height: size.height)
    }

    private func orbit(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Ellipse()
                    .stroke(design.foregroundColor.opacity(design.artworkOpacity * (0.35 + Double(index) * 0.08)), lineWidth: 1)
                    .frame(width: size.width * (0.35 + CGFloat(index) * 0.14), height: size.height * (0.38 + CGFloat(index) * 0.10))
                    .rotationEffect(.degrees(Double(index) * 14))
                    .offset(x: size.width * 0.22, y: -size.height * 0.02)
            }

            Circle()
                .fill(design.glowColor.opacity(0.42))
                .frame(width: size.height * 0.17, height: size.height * 0.17)
                .offset(x: size.width * 0.22, y: -size.height * 0.02)
        }
        .frame(width: size.width, height: size.height)
    }

    private func waves(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                CreditCardWaveShape(
                    amplitude: size.height * (0.07 + CGFloat(index) * 0.004),
                    frequency: 1.1 + CGFloat(index) * 0.20,
                    phase: CGFloat(index) * 0.9
                )
                .stroke(design.foregroundColor.opacity(design.artworkOpacity * 0.72), lineWidth: index == 0 ? 1.6 : 1)
                .frame(width: size.width * 1.22, height: size.height * 0.46)
                .offset(x: -size.width * 0.08, y: -size.height * 0.18 + CGFloat(index) * size.height * 0.105)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func grid(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Rectangle()
                    .fill(design.foregroundColor.opacity(design.artworkOpacity * 0.38))
                    .frame(width: 1, height: size.height * 1.35)
                    .offset(x: -size.width * 0.50 + CGFloat(index) * size.width * 0.12)
            }

            ForEach(0..<6, id: \.self) { index in
                Rectangle()
                    .fill(design.foregroundColor.opacity(design.artworkOpacity * 0.34))
                    .frame(width: size.width * 1.22, height: 1)
                    .offset(y: -size.height * 0.50 + CGFloat(index) * size.height * 0.20)
            }
        }
        .rotationEffect(.degrees(-9))
        .frame(width: size.width, height: size.height)
    }

    private func circuit(size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.30))
                path.addLine(to: CGPoint(x: size.width * 0.34, y: size.height * 0.30))
                path.addLine(to: CGPoint(x: size.width * 0.34, y: size.height * 0.50))
                path.addLine(to: CGPoint(x: size.width * 0.56, y: size.height * 0.50))
                path.addLine(to: CGPoint(x: size.width * 0.56, y: size.height * 0.22))
                path.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * 0.22))

                path.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.74))
                path.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.74))
                path.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.62))
                path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.62))
                path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.84))
            }
            .stroke(design.foregroundColor.opacity(design.artworkOpacity), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(design.glowColor.opacity(0.42))
                    .frame(width: size.height * 0.045, height: size.height * 0.045)
                    .position(circuitNodePosition(index: index, size: size))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func circuitNodePosition(index: Int, size: CGSize) -> CGPoint {
        let points: [(CGFloat, CGFloat)] = [
            (0.08, 0.30), (0.34, 0.30), (0.56, 0.50), (0.86, 0.22),
            (0.20, 0.74), (0.42, 0.62), (0.72, 0.84)
        ]
        let point = points[index % points.count]
        return CGPoint(x: size.width * point.0, y: size.height * point.1)
    }

    private func topographic(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Ellipse()
                    .stroke(design.foregroundColor.opacity(design.artworkOpacity * 0.58), lineWidth: 1)
                    .frame(width: size.width * (0.30 + CGFloat(index) * 0.11), height: size.height * (0.24 + CGFloat(index) * 0.07))
                    .offset(x: size.width * 0.24, y: size.height * 0.02)
            }

            ForEach(0..<5, id: \.self) { index in
                Ellipse()
                    .stroke(design.glowColor.opacity(0.13), lineWidth: 1)
                    .frame(width: size.width * (0.18 + CGFloat(index) * 0.12), height: size.height * (0.14 + CGFloat(index) * 0.08))
                    .offset(x: -size.width * 0.30, y: size.height * 0.34)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func prism(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                CreditCardTriangleShape(direction: index % 2 == 0 ? .up : .down)
                    .fill(index % 2 == 0 ? design.foregroundColor.opacity(design.artworkOpacity * 0.72) : design.glowColor.opacity(0.18))
                    .frame(width: size.width * 0.30, height: size.height * 0.44)
                    .rotationEffect(.degrees(Double(index) * 19))
                    .offset(x: -size.width * 0.45 + CGFloat(index) * size.width * 0.17, y: CGFloat(index % 3 - 1) * size.height * 0.18)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func carbon(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { row in
                ForEach(0..<14, id: \.self) { column in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill((row + column).isMultiple(of: 2) ? design.foregroundColor.opacity(design.artworkOpacity * 0.22) : Color.black.opacity(0.12))
                        .frame(width: size.width * 0.09, height: size.height * 0.055)
                        .rotationEffect(.degrees((row + column).isMultiple(of: 2) ? 18 : -18))
                        .offset(
                            x: -size.width * 0.58 + CGFloat(column) * size.width * 0.09,
                            y: -size.height * 0.40 + CGFloat(row) * size.height * 0.13
                        )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func liquid(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(design.glowColor.opacity(0.28))
                .frame(width: size.width * 0.52, height: size.width * 0.52)
                .offset(x: size.width * 0.34, y: -size.height * 0.20)
                .blur(radius: size.height * 0.04)

            Ellipse()
                .fill(design.foregroundColor.opacity(design.artworkOpacity * 0.58))
                .frame(width: size.width * 0.62, height: size.height * 0.42)
                .rotationEffect(.degrees(-16))
                .offset(x: -size.width * 0.28, y: size.height * 0.34)
                .blur(radius: size.height * 0.025)

            CreditCardWaveShape(amplitude: size.height * 0.10, frequency: 1.6, phase: 0.2)
                .stroke(design.foregroundColor.opacity(design.artworkOpacity * 0.68), lineWidth: 1.5)
                .frame(width: size.width * 1.2, height: size.height * 0.42)
                .offset(x: -size.width * 0.08, y: size.height * 0.20)
        }
        .frame(width: size.width, height: size.height)
    }

    private func diagonal(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: size.height * 0.02, style: .continuous)
                    .fill(index.isMultiple(of: 2) ? design.foregroundColor.opacity(design.artworkOpacity * 0.50) : design.glowColor.opacity(0.16))
                    .frame(width: size.width * 0.09, height: size.height * 1.7)
                    .offset(x: -size.width * 0.52 + CGFloat(index) * size.width * 0.18)
            }
        }
        .rotationEffect(.degrees(24))
        .frame(width: size.width, height: size.height)
    }

    private func starfield(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 3) ? design.glowColor.opacity(0.78) : design.foregroundColor.opacity(design.artworkOpacity))
                    .frame(width: starSize(index: index, size: size), height: starSize(index: index, size: size))
                    .position(starPosition(index: index, size: size))
            }

            Circle()
                .stroke(design.foregroundColor.opacity(design.artworkOpacity * 0.55), lineWidth: 1)
                .frame(width: size.height * 0.42, height: size.height * 0.42)
                .position(x: size.width * 0.75, y: size.height * 0.28)
        }
        .frame(width: size.width, height: size.height)
    }

    private func starPosition(index: Int, size: CGSize) -> CGPoint {
        let points: [(CGFloat, CGFloat)] = [
            (0.10, 0.18), (0.18, 0.66), (0.26, 0.32), (0.34, 0.82),
            (0.42, 0.16), (0.50, 0.56), (0.58, 0.30), (0.66, 0.76),
            (0.74, 0.48), (0.82, 0.20), (0.90, 0.70), (0.14, 0.44),
            (0.30, 0.58), (0.46, 0.72), (0.62, 0.12), (0.78, 0.84),
            (0.88, 0.38), (0.52, 0.92)
        ]
        let point = points[index % points.count]
        return CGPoint(x: size.width * point.0, y: size.height * point.1)
    }

    private func starSize(index: Int, size: CGSize) -> CGFloat {
        size.height * (index.isMultiple(of: 4) ? 0.030 : 0.018)
    }

    private func terrazzo(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<15, id: \.self) { index in
                CreditCardTriangleShape(direction: index.isMultiple(of: 2) ? .up : .down)
                    .fill(index.isMultiple(of: 3) ? design.glowColor.opacity(0.28) : design.foregroundColor.opacity(design.artworkOpacity * 0.75))
                    .frame(width: size.width * terrazzoScale(index), height: size.height * terrazzoScale(index) * 0.95)
                    .rotationEffect(.degrees(Double((index * 37) % 160)))
                    .position(terrazzoPosition(index: index, size: size))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func terrazzoScale(_ index: Int) -> CGFloat {
        [0.06, 0.075, 0.045, 0.085, 0.055][index % 5]
    }

    private func terrazzoPosition(index: Int, size: CGSize) -> CGPoint {
        let points: [(CGFloat, CGFloat)] = [
            (0.10, 0.22), (0.24, 0.74), (0.34, 0.38), (0.45, 0.88),
            (0.56, 0.20), (0.68, 0.62), (0.82, 0.32), (0.91, 0.78),
            (0.16, 0.52), (0.30, 0.14), (0.50, 0.50), (0.64, 0.82),
            (0.76, 0.12), (0.88, 0.54), (0.42, 0.68)
        ]
        let point = points[index % points.count]
        return CGPoint(x: size.width * point.0, y: size.height * point.1)
    }

    private func skyline(size: CGSize) -> some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(0..<13, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(design.foregroundColor.opacity(design.artworkOpacity * 0.68))
                    .frame(width: size.width * 0.055, height: size.height * skylineHeightFactor(index))
                    .offset(x: CGFloat(index) * size.width * 0.077, y: 0)
            }

            Rectangle()
                .fill(design.foregroundColor.opacity(design.artworkOpacity * 0.24))
                .frame(height: 1)
                .offset(y: -size.height * 0.02)
        }
        .frame(width: size.width, height: size.height, alignment: .bottomLeading)
    }

    private func skylineHeightFactor(_ index: Int) -> CGFloat {
        [0.24, 0.38, 0.28, 0.52, 0.34, 0.44, 0.30, 0.58, 0.40, 0.27, 0.47, 0.33, 0.50][index % 13]
    }

    private func brush(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? design.foregroundColor.opacity(design.artworkOpacity * 0.50) : design.glowColor.opacity(0.15))
                    .frame(width: size.width * 0.86, height: size.height * 0.08)
                    .rotationEffect(.degrees(-18 + Double(index) * 4))
                    .offset(x: size.width * 0.08, y: -size.height * 0.30 + CGFloat(index) * size.height * 0.14)
                    .blur(radius: index.isMultiple(of: 2) ? 0 : size.height * 0.012)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func rings(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .stroke(index.isMultiple(of: 2) ? design.foregroundColor.opacity(design.artworkOpacity * 0.54) : design.glowColor.opacity(0.16), lineWidth: 1)
                    .frame(width: size.height * (0.24 + CGFloat(index) * 0.18), height: size.height * (0.24 + CGFloat(index) * 0.18))
                    .offset(x: size.width * 0.35, y: size.height * 0.02)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func crosshatch(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<9, id: \.self) { index in
                Rectangle()
                    .fill(design.foregroundColor.opacity(design.artworkOpacity * 0.28))
                    .frame(width: 1, height: size.height * 1.5)
                    .offset(x: -size.width * 0.52 + CGFloat(index) * size.width * 0.14)
            }

            ForEach(0..<9, id: \.self) { index in
                Rectangle()
                    .fill(design.glowColor.opacity(0.11))
                    .frame(width: 1, height: size.height * 1.5)
                    .offset(x: -size.width * 0.52 + CGFloat(index) * size.width * 0.14)
                    .rotationEffect(.degrees(90))
            }
        }
        .rotationEffect(.degrees(22))
        .frame(width: size.width, height: size.height)
    }

    private func marble(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                CreditCardWaveShape(
                    amplitude: size.height * (0.035 + CGFloat(index) * 0.008),
                    frequency: 1.2 + CGFloat(index) * 0.18,
                    phase: CGFloat(index) * 0.55
                )
                .stroke(index.isMultiple(of: 2) ? design.foregroundColor.opacity(design.artworkOpacity * 0.78) : design.glowColor.opacity(0.16), lineWidth: index.isMultiple(of: 2) ? 1.2 : 2)
                .frame(width: size.width * 1.22, height: size.height * 0.60)
                .offset(x: -size.width * 0.10, y: -size.height * 0.18 + CGFloat(index) * size.height * 0.13)
                .blur(radius: index.isMultiple(of: 2) ? 0 : size.height * 0.018)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func dots(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<7, id: \.self) { row in
                ForEach(0..<12, id: \.self) { column in
                    Circle()
                        .fill(design.foregroundColor.opacity(design.artworkOpacity * ((row + column).isMultiple(of: 3) ? 0.52 : 0.26)))
                        .frame(width: size.height * 0.025, height: size.height * 0.025)
                        .offset(
                            x: -size.width * 0.50 + CGFloat(column) * size.width * 0.10,
                            y: -size.height * 0.35 + CGFloat(row) * size.height * 0.13
                        )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func shards(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                CreditCardShardShape(skew: CGFloat(index % 4) * 0.12)
                    .fill(index.isMultiple(of: 2) ? design.foregroundColor.opacity(design.artworkOpacity * 0.72) : design.glowColor.opacity(0.20))
                    .frame(width: size.width * (0.18 + CGFloat(index % 3) * 0.05), height: size.height * (0.28 + CGFloat(index % 2) * 0.08))
                    .rotationEffect(.degrees(Double(index * 17)))
                    .position(shardPosition(index: index, size: size))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func shardPosition(index: Int, size: CGSize) -> CGPoint {
        let points: [(CGFloat, CGFloat)] = [
            (0.10, 0.28), (0.24, 0.70), (0.38, 0.35), (0.52, 0.82),
            (0.66, 0.24), (0.78, 0.62), (0.90, 0.38), (0.56, 0.48)
        ]
        let point = points[index % points.count]
        return CGPoint(x: size.width * point.0, y: size.height * point.1)
    }
}

private struct CreditCardWaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = max(2, rect.width / 90)
        var x: CGFloat = 0
        var isFirstPoint = true

        while x <= rect.width {
            let progress = x / max(rect.width, 1)
            let y = rect.midY + sin(progress * .pi * 2 * frequency + phase) * amplitude
            let point = CGPoint(x: x, y: y)

            if isFirstPoint {
                path.move(to: point)
                isFirstPoint = false
            } else {
                path.addLine(to: point)
            }

            x += step
        }

        return path
    }
}

private enum CreditCardTriangleDirection {
    case up
    case down
}

private struct CreditCardTriangleShape: Shape {
    var direction: CreditCardTriangleDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}

private struct CreditCardShardShape: Shape {
    var skew: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * skew, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.20))
        path.closeSubpath()
        return path
    }
}
