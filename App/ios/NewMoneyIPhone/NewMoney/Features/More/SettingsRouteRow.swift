import SwiftUI

struct SettingsRouteRow: View {
    var route: SettingsRoute

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text(route.title)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer(minLength: AppTheme.Spacing.sm)
        }
        .frame(minHeight: SettingsLayoutPolicy.routeRowMinimumHeight)
        .contentShape(Rectangle())
    }
}
