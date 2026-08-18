import SwiftUI

struct SettingsRouteRow: View {
    var route: SettingsRoute

    var body: some View {
        CompactMenuRow(
            title: route.title,
            systemImage: route.symbol,
            tint: route.tint
        )
    }
}
