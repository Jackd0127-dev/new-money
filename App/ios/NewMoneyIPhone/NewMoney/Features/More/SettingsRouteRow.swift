import SwiftUI

struct SettingsRouteRow: View {
    var route: SettingsRoute

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text(route.title)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}
