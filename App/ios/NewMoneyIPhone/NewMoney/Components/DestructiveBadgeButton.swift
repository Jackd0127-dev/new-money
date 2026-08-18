import SwiftUI

struct DestructiveBadgeButton: View {
    var accessibilityLabel: String
    var confirmationTitle: String
    var confirmationMessage: String
    let action: () -> Void

    @State private var isConfirmationPresented = false

    var body: some View {
        Button {
            isConfirmationPresented = true
        } label: {
            Image(systemName: "trash.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(AppTheme.Colors.danger)
                        .frame(width: 30, height: 30)
                        .shadow(color: AppTheme.Colors.danger.opacity(0.24), radius: 7, y: 3)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Shows a confirmation before deleting")
        .alert(confirmationTitle, isPresented: $isConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: action)
        } message: {
            Text(confirmationMessage)
        }
    }
}
