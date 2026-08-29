import SwiftUI
import UIKit

struct AppCard<Content: View>: View {
    var glow: Bool = false
    var cornerRadius: CGFloat = AppTheme.Radius.lg
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            content
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

/// A denser, icon-led surface for profile and settings navigation.
struct CompactMenuCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

struct CompactMenuRow: View {
    var title: String
    var subtitle: String? = nil
    var systemImage: String
    var tint: Color = AppTheme.Colors.primaryOrange
    var isDestructive = false
    var showsDisclosure = true

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDestructive ? AppTheme.Colors.danger : tint)
                .frame(width: 34, height: 34)
                .background((isDestructive ? AppTheme.Colors.danger : tint).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDestructive ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct SettingsPanel<Content: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color = AppTheme.Colors.primaryOrange
    var isDestructive = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDestructive ? AppTheme.Colors.danger : tint)
                    .frame(width: 34, height: 34)
                    .background((isDestructive ? AppTheme.Colors.danger : tint).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isDestructive ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }

            AppDivider()
            content
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(isDestructive ? AppTheme.Colors.danger.opacity(0.25) : AppTheme.Colors.border, lineWidth: 1)
        )
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
                        .tint(AppTheme.Colors.controlText)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(AppTheme.Colors.controlText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(isDisabled ? AnyShapeStyle(AppTheme.Colors.darkDisabled) : AnyShapeStyle(AppTheme.Colors.accent))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
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

struct RefundAmountEditor: View {
    var originalAmountPence: Int
    @Binding var isEnabled: Bool
    @Binding var amount: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Toggle(isOn: enabledBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Refund received")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("Full or partial")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .tint(AppTheme.Colors.success)

            if isEnabled {
                MoneyField(title: "Refund amount", text: $amount)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("Maximum \(MoneyParser.formatPence(originalAmountPence))")
                        .font(.caption)
                        .foregroundStyle(isValid ? AppTheme.Colors.secondaryText : AppTheme.Colors.danger)

                    Spacer()

                    Button("Full amount") {
                        amount = Self.inputValue(for: originalAmountPence)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .buttonStyle(.plain)
                }

                if let statusText {
                    Label(statusText, systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.success)
                }
            }
        }
        .animation(AppTheme.Animation.standard, value: isEnabled)
    }

    var parsedAmountPence: Int {
        isEnabled ? MoneyParser.parsePoundsToPence(amount) : 0
    }

    var isValid: Bool {
        !isEnabled || (parsedAmountPence > 0 && parsedAmountPence <= originalAmountPence)
    }

    static func inputValue(for amountPence: Int) -> String {
        amountPence > 0 ? String(format: "%.2f", Double(amountPence) / 100) : ""
    }

    private var enabledBinding: Binding<Bool> {
        Binding {
            isEnabled
        } set: { newValue in
            isEnabled = newValue
            if newValue && MoneyParser.parsePoundsToPence(amount) <= 0 {
                amount = Self.inputValue(for: originalAmountPence)
            }
        }
    }

    private var statusText: String? {
        guard isValid else { return nil }
        return parsedAmountPence == originalAmountPence
            ? "Full refund"
            : "Partial refund · \(MoneyParser.formatPence(parsedAmountPence))"
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

struct SelectionField<MenuContent: View>: View {
    var title: String
    var value: String
    var placeholder: String = "Select"
    var systemImage: String? = nil
    var isDisabled = false
    var menuContent: MenuContent

    init(
        title: String,
        value: String,
        placeholder: String = "Select",
        systemImage: String? = nil,
        isDisabled: Bool = false,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.title = title
        self.value = value
        self.placeholder = placeholder
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.menuContent = menuContent()
    }

    var body: some View {
        let displayValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValue = !displayValue.isEmpty

        Menu {
            menuContent
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                if let systemImage {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                            .fill(AppTheme.Colors.accentSoft)

                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    .frame(width: 38, height: 38)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .textCase(.uppercase)
                        .tracking(0.45)

                    Text(displayValue.isEmpty ? placeholder : displayValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(hasValue ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: AppTheme.Spacing.md)

                ZStack {
                    Circle()
                        .fill(hasValue ? AppTheme.Colors.accentSoft : AppTheme.Colors.surface)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(hasValue ? AppTheme.Colors.accent : AppTheme.Colors.tertiaryText)
                }
                .frame(width: 30, height: 30)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(minHeight: 58)
            .background(
                hasValue ? AppTheme.Colors.elevatedSurface : AppTheme.Colors.cardBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(hasValue ? AppTheme.Colors.selectedStroke.opacity(0.7) : AppTheme.Colors.border, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.55 : 1)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityValue(hasValue ? displayValue : placeholder)
        .accessibilityHint(isDisabled ? "Unavailable" : "Double tap to choose an option")
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
            PremiumScreenBackground()
        }
    }

    func navigationTopDividerHidden() -> some View {
        toolbarBackground(.hidden, for: .navigationBar)
            .background {
                NavigationTopDividerHiddenInstaller()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }
    }
}

enum ScreenTopDividerPolicy {
    static let hiddenScreens = [
        "Add card",
        "Create paycheck plan",
        "Assistant",
        "Card",
        "Card payments",
        "Add debt",
        "Pot Overview",
        "Edit Pot"
    ]
    static let keepsToolbarBackgroundHidden = true
    static let usesNavigationBarAppearanceInstaller = true
}

private struct PremiumScreenBackground: View {
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.defaultPreset.rawValue

    var body: some View {
        AppTheme.Colors.appBackground
        .id("screen-background-\(selectedThemeRawValue)")
        .ignoresSafeArea()
    }
}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissInstallerView {
        KeyboardDismissInstallerView()
    }

    func updateUIView(_ uiView: KeyboardDismissInstallerView, context: Context) {}
}

private struct NavigationTopDividerHiddenInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> NavigationTopDividerHiddenController {
        NavigationTopDividerHiddenController()
    }

    func updateUIViewController(_ uiViewController: NavigationTopDividerHiddenController, context: Context) {
        uiViewController.apply()
    }
}

private final class NavigationTopDividerHiddenController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        apply()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        DispatchQueue.main.async { [weak self] in
            self?.apply()
        }
    }

    func apply() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        navigationBar.standardAppearance = dividerHiddenAppearance(from: navigationBar.standardAppearance)
        navigationBar.scrollEdgeAppearance = dividerHiddenAppearance(from: navigationBar.scrollEdgeAppearance ?? navigationBar.standardAppearance)
        navigationBar.compactAppearance = dividerHiddenAppearance(from: navigationBar.compactAppearance ?? navigationBar.standardAppearance)
        navigationBar.compactScrollEdgeAppearance = dividerHiddenAppearance(from: navigationBar.compactScrollEdgeAppearance ?? navigationBar.standardAppearance)
    }

    private func dividerHiddenAppearance(from appearance: UINavigationBarAppearance) -> UINavigationBarAppearance {
        let copy = appearance.copy()
        copy.shadowColor = .clear
        copy.shadowImage = UIImage()
        return copy
    }
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
    static var darkDisabled: Color { AppTheme.Colors.border.opacity(0.82) }
}
