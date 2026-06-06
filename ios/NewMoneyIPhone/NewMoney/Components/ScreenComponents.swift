import SwiftUI

struct ScreenScaffold<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    ScreenHeader(subtitle: subtitle)
                    content
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.sm)
                .padding(.bottom, 110)
            }
            .premiumScreenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct ScreenHeader: View {
    var subtitle: String

    var body: some View {
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    var title: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
            }
        }
    }
}

struct MetricRow: View {
    var label: String
    var value: String
    var valueColor: Color = AppTheme.Colors.primaryText

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct Pill: View {
    var text: String
    var systemImage: String?
    var color: Color = AppTheme.Colors.primaryOrange

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct AppDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.Colors.divider)
            .frame(height: 1)
    }
}

struct AddButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.md)
                .frame(minHeight: 38)
                .background(AppTheme.Gradients.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

extension Date {
    var isoDateString: String {
        FinanceEngine.toIsoDate(self)
    }
}

extension String {
    var isoDate: Date {
        FinanceEngine.parseDate(self)
    }
}
