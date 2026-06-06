import SwiftUI
import UIKit

struct AppCard<Content: View>: View {
    var glow: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            content
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Gradients.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(glow ? AppTheme.Colors.primaryOrange.opacity(0.5) : AppTheme.Colors.border, lineWidth: 1)
        )
        .shadow(color: glow ? AppTheme.Colors.glowOrange : .black.opacity(0.25), radius: glow ? 18 : 10, y: glow ? 8 : 4)
    }
}

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var isLoading = false
    var isDisabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(isDisabled ? AnyShapeStyle(AppTheme.Colors.darkDisabled) : AnyShapeStyle(AppTheme.Gradients.primary))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .shadow(color: isDisabled ? .clear : AppTheme.Colors.glowOrange, radius: 16, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
    }
}

struct SecondaryButton: View {
    var title: String
    var systemImage: String?
    var role: ButtonRole?
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(role == .destructive ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(AppTheme.Colors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(role == .destructive ? AppTheme.Colors.danger.opacity(0.35) : AppTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct StatCard: View {
    var title: String
    var value: String
    var subtitle: String?
    var systemImage: String
    var tone: Color = AppTheme.Colors.primaryOrange

    var body: some View {
        AppCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(value)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                }
                Spacer()
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tone)
                    .frame(width: 34, height: 34)
                    .background(tone.opacity(0.13))
                    .clipShape(Circle())
            }
        }
    }
}

struct EmptyStateView: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryOrange)
                .frame(width: 70, height: 70)
                .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.xl)
    }
}

struct LoadingView: View {
    var title: String = "Loading planner"

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
                .tint(AppTheme.Colors.primaryOrange)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(AppTheme.Spacing.xl)
    }
}

struct ErrorBanner: View {
    var message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.Colors.warning)
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .stroke(AppTheme.Colors.warning.opacity(0.28), lineWidth: 1)
        )
    }
}

struct MoneyField: View {
    var title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.decimalPad)
            .textFieldStyle(AppTextFieldStyle())
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(AppTheme.Colors.primaryText)
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(minHeight: 48)
            .background(AppTheme.Colors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}

extension View {
    func dismissKeyboardOnBackgroundTap() -> some View {
        background {
            KeyboardDismissTapInstaller()
                .allowsHitTesting(false)
        }
    }

    func premiumScreenBackground() -> some View {
        background {
            AppTheme.Colors.appBackground
                .ignoresSafeArea()
            AppTheme.Gradients.hero
                .blur(radius: 28)
                .ignoresSafeArea()
        }
    }

}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissInstallerView {
        KeyboardDismissInstallerView()
    }

    func updateUIView(_ uiView: KeyboardDismissInstallerView, context: Context) {}
}

private final class KeyboardDismissInstallerView: UIView, UIGestureRecognizerDelegate {
    private weak var installedWindow: UIWindow?
    private var recognizer: UITapGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard installedWindow !== window else { return }
        removeRecognizer()

        guard let window else { return }
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)

        installedWindow = window
        self.recognizer = recognizer
    }

    @objc private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func removeRecognizer() {
        if let recognizer, let installedWindow {
            recognizer.delegate = nil
            installedWindow.removeGestureRecognizer(recognizer)
        }

        recognizer = nil
        installedWindow = nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view?.isTextInputInSuperviewChain ?? false)
    }
}

private extension UIView {
    var isTextInputInSuperviewChain: Bool {
        if self is UITextField || self is UITextView || self is UISearchBar {
            return true
        }

        return superview?.isTextInputInSuperviewChain ?? false
    }
}

private extension AppTheme.Colors {
    static var darkDisabled: Color { Color(hex: "#333333") }
}
