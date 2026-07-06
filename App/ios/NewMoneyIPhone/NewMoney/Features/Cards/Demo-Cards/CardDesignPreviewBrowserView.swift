import SwiftUI

struct CardDesignPreviewBrowserView: View {
    @State private var selectedDesign: CreditCardDesign?

    private let demoBadges: [CreditCardLinkBadge] = [.pot, .bill, .debt]
    private let featuredDesignIds = ["original-flame", "obsidian-reserve", "northern-aurora"]
    private let galleryColumns = [
        GridItem(.adaptive(minimum: 156), spacing: 18)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                featuredSection

                ForEach(CreditCardDesignCategory.allCases) { category in
                    categorySection(category)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, 30)
        }
        .premiumScreenBackground()
        .navigationTitle("Card Designs")
        .fullScreenCover(item: $selectedDesign) { design in
            CardDesignPreviewDetailView(design: design, badges: demoBadges)
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Featured")

            VStack(spacing: AppTheme.Spacing.lg) {
                ForEach(featuredDesignIds, id: \.self) { designId in
                    if let design = CreditCardDesignCatalog.designs.first(where: { $0.id == designId }) {
                        Button {
                            selectedDesign = design
                        } label: {
                            PremiumCardView(
                                badges: demoBadges,
                                cardNumber: "••••  ••••  ••••  2847",
                                cardHolder: "JACK",
                                expiryDate: "09/29",
                                provider: design.providerFallback,
                                horizontalPadding: 0,
                                designId: design.storageHex
                            )
                            .frame(maxWidth: 380)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(design.name) card design")
                    }
                }
            }
        }
    }

    private func categorySection(_ category: CreditCardDesignCategory) -> some View {
        let designs = CreditCardDesignCatalog.designs.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .lastTextBaseline) {
                SectionTitle(category.rawValue)
                Spacer()
                Text("\(designs.count) designs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            LazyVGrid(columns: galleryColumns, spacing: 18) {
                ForEach(designs) { design in
                    Button {
                        selectedDesign = design
                    } label: {
                        CardDesignPreviewTile(design: design, badges: demoBadges)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(design.name) card design")
                }
            }
        }
    }
}

private struct CardDesignPreviewTile: View {
    var design: CreditCardDesign
    var badges: [CreditCardLinkBadge]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CreditCardDesignMiniPreview(
                design: design,
                provider: design.providerFallback,
                badges: badges
            )
            .frame(height: 82)
            .shadow(color: design.glowColor.opacity(0.16), radius: 10, y: 5)

            Text(design.name)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)

            Text(design.storageHex)
                .font(.caption2.monospaced())
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(10)
        .background(AppTheme.Colors.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

private struct CardDesignPreviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var design: CreditCardDesign
    var badges: [CreditCardLinkBadge]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    PremiumCardView(
                        badges: badges,
                        cardNumber: "••••  ••••  ••••  2847",
                        cardHolder: "JACK",
                        expiryDate: "09/29",
                        provider: design.providerFallback,
                        horizontalPadding: 0,
                        designId: design.storageHex
                    )
                    .frame(maxWidth: 390)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, AppTheme.Spacing.md)

                    AppCard(glow: true) {
                        SectionTitle(design.name)
                        MetricRow(label: "Category", value: design.category.rawValue)
                        MetricRow(label: "Stored value", value: design.storageHex)
                        MetricRow(label: "Fallback provider", value: design.providerFallback)
                        MetricRow(label: "Pattern", value: design.pattern.rawValue.capitalized)
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle(design.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CardDesignPreviewBrowserView()
    }
}
