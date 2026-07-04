import AuthenticationServices
import Combine
import CryptoKit
import Security
import SwiftUI

struct AuthenticatedRootView: View {
    @StateObject private var store = PlannerStore()
    @StateObject private var session = FirebaseAuthSession()
    @State private var didStart = false

    var body: some View {
        Group {
            switch session.state {
            case .loading(let message):
                AuthProgressView(message: message)
            case .signedOut:
                AuthEntryView(session: session, store: store)
            case .emailVerificationRequired(let user):
                EmailVerificationView(session: session, store: store, user: user)
            case .syncing(_, let message):
                AuthProgressView(message: message)
            case .conflict(_, let cloud):
                CloudConflictView(session: session, store: store, cloud: cloud)
            case .ready:
                AppView(store: store)
            case .failed(let message):
                AuthFailureView(session: session, store: store, message: message)
            }
        }
        .environmentObject(session)
        .preferredColorScheme(.dark)
        .task {
            guard !didStart else { return }
            didStart = true
            await session.start(store: store)
        }
        .onReceive(store.snapshotPublisher.debounce(for: .milliseconds(900), scheduler: RunLoop.main)) { snapshot in
            Task {
                await session.uploadLatestSnapshot(snapshot)
            }
        }
    }
}

enum AuthEmailFormValidation {
    static func canCreateAccount(email: String, password: String, confirmPassword: String) -> Bool {
        isUsableEmail(email) && password.count >= 6 && password == confirmPassword
    }

    static func canSignIn(email: String, password: String) -> Bool {
        isUsableEmail(email) && !password.isEmpty
    }

    private static func isUsableEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedEmail.split(separator: "@")
        guard parts.count == 2 else { return false }
        return parts[1].contains(".")
    }
}

enum AuthScreenMode {
    case signUp
    case signIn

    var primaryTitle: String {
        switch self {
        case .signUp:
            "Create account"
        case .signIn:
            "Sign in"
        }
    }

    var primaryIcon: String {
        switch self {
        case .signUp:
            "person.crop.circle.badge.plus"
        case .signIn:
            "person.crop.circle"
        }
    }

    var heroTitle: String {
        switch self {
        case .signUp:
            "Create your account"
        case .signIn:
            "Sign in"
        }
    }

    var heroSubtitle: String {
        "Manage your money the way YOU want to."
    }

    var emailLabel: String {
        switch self {
        case .signUp:
            "Your email"
        case .signIn:
            "Enter your email"
        }
    }

    var passwordLabel: String {
        switch self {
        case .signUp:
            "Your password"
        case .signIn:
            "Enter your password"
        }
    }

    var footerPrompt: String {
        switch self {
        case .signUp:
            "Already have an account?"
        case .signIn:
            "Don't have an account yet?"
        }
    }

    var footerActionTitle: String {
        switch self {
        case .signUp:
            "Sign in"
        case .signIn:
            "Sign up"
        }
    }

    var showsNameField: Bool {
        self == .signUp
    }

    var showsConfirmPasswordField: Bool {
        self == .signUp
    }
}

private enum AuthFocusField: Hashable {
    case name
    case email
    case password
    case confirmPassword
    case phoneNumber
    case smsCode
}

private struct AuthEntryView: View {
    @ObservedObject var session: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    @State private var mode: AuthScreenMode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var acceptsTerms = false
    @State private var isPhoneFormVisible = false
    @State private var phoneNumber = ""
    @State private var smsCode = ""
    @State private var phoneVerificationID: String?
    @State private var currentAppleNonce: String?
    @FocusState private var focusedField: AuthFocusField?

    var body: some View {
        AuthScaffold {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                authHeader

                if let message = session.errorMessage {
                    AuthErrorBanner(message: message) {
                        session.errorMessage = nil
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    emailFields
                    modeSupportRow

                    AuthPrimaryButton(
                        title: mode.primaryTitle,
                        isLoading: session.isWorking,
                        isDisabled: isPrimaryActionDisabled
                    ) {
                        submitEmailForm()
                    }
                }

                AuthSocialActions(
                    googleAction: {
                        Task {
                            await session.signInWithGoogle(store: store)
                        }
                    },
                    phoneAction: {
                        withAnimation(AppTheme.Animation.standard) {
                            isPhoneFormVisible.toggle()
                        }
                    },
                    isPhoneSelected: isPhoneFormVisible,
                    appleRequest: configureAppleRequest,
                    appleCompletion: handleAppleResult
                )

                if isPhoneFormVisible {
                    phoneForm
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                AuthModeFooter(
                    prompt: mode.footerPrompt,
                    actionTitle: mode.footerActionTitle
                ) {
                    switchMode()
                }
            }
            .padding(.vertical, AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var authHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(mode.heroTitle)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.76)

            Text(mode.heroSubtitle)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var emailFields: some View {
        if mode.showsNameField {
            LabeledAuthField("Your name") {
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .email }
                    .textFieldStyle(AuthTextFieldStyle())
            }
        }

        LabeledAuthField(mode.emailLabel) {
            TextField(mode.emailLabel, text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }
                .textFieldStyle(AuthTextFieldStyle())
        }

        LabeledAuthField(mode.passwordLabel) {
            SecureField(mode.passwordLabel, text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .submitLabel(mode == .signUp ? .next : .go)
                .focused($focusedField, equals: .password)
                .onSubmit {
                    if mode == .signUp {
                        focusedField = .confirmPassword
                    } else if !isPrimaryActionDisabled {
                        submitEmailForm()
                    }
                }
                .textFieldStyle(AuthTextFieldStyle())
        }

        if mode.showsConfirmPasswordField {
            LabeledAuthField("Confirm password") {
                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .confirmPassword)
                    .onSubmit {
                        if !isPrimaryActionDisabled {
                            submitEmailForm()
                        }
                    }
                    .textFieldStyle(AuthTextFieldStyle())
            }

            if !confirmPassword.isEmpty && password != confirmPassword {
                Text("Passwords need to match.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var modeSupportRow: some View {
        switch mode {
        case .signUp:
            AuthTermsCheckboxRow(isChecked: $acceptsTerms)
        case .signIn:
            HStack {
                Spacer()
                Text("Forgot password?")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var phoneForm: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            LabeledAuthField("Phone number") {
                TextField("Phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focusedField, equals: .phoneNumber)
                    .textFieldStyle(AuthTextFieldStyle())
            }

            if phoneVerificationID != nil {
                LabeledAuthField("SMS code") {
                    TextField("SMS code", text: $smsCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .smsCode)
                        .textFieldStyle(AuthTextFieldStyle())
                }
            }

            AuthPrimaryButton(
                title: phoneVerificationID == nil ? "Send SMS Code" : "Verify Code",
                isLoading: session.isWorking,
                isDisabled: phoneVerificationID == nil ? phoneNumber.isEmpty : smsCode.isEmpty
            ) {
                Task {
                    if let phoneVerificationID {
                        await session.confirmPhoneCode(verificationID: phoneVerificationID, code: smsCode, store: store)
                    } else {
                        phoneVerificationID = await session.startPhoneVerification(phoneNumber: phoneNumber)
                    }
                }
            }

#if DEBUG
            if let message = session.phoneAuthDebugMessage {
                PhoneAuthDiagnosticsBanner(message: message)
            }
#endif

            if phoneVerificationID != nil {
                SecondaryButton(title: "Change Number", systemImage: "arrow.counterclockwise") {
                    phoneVerificationID = nil
                    smsCode = ""
                }
            }
        }
    }

    private var isPrimaryActionDisabled: Bool {
        switch mode {
        case .signUp:
            return !AuthEmailFormValidation.canCreateAccount(
                email: email,
                password: password,
                confirmPassword: confirmPassword
            )
        case .signIn:
            return !AuthEmailFormValidation.canSignIn(email: email, password: password)
        }
    }

    private func submitEmailForm() {
        Task {
            switch mode {
            case .signUp:
                await session.createEmailAccount(email: email, password: password)
            case .signIn:
                await session.signInWithEmail(email: email, password: password, store: store)
            }
        }
    }

    private func switchMode() {
        withAnimation(AppTheme.Animation.standard) {
            mode = mode == .signUp ? .signIn : .signUp
            isPhoneFormVisible = false
            phoneVerificationID = nil
            smsCode = ""
            focusedField = nil
        }
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleSignInNonce.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInNonce.sha256(nonce)
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            handleAppleAuthorization(authorization)
        case .failure(let error):
            session.errorMessage = error.localizedDescription
        }
    }

    private func handleAppleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentAppleNonce,
              let identityToken = credential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8) else {
            session.errorMessage = FirebaseNativeServiceError.missingAppleIDToken.localizedDescription
            return
        }

        Task {
            await session.signInWithApple(
                idToken: idToken,
                nonce: nonce,
                fullName: credential.fullName,
                store: store
            )
        }
    }
}

private struct PhoneAuthDiagnosticsBanner: View {
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Phone auth diagnostics")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.warning)
            Text(message)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(AppTheme.Colors.warning.opacity(0.28), lineWidth: 1)
        )
    }
}

private enum AuthEntryPalette {
    static let deepRed = Color(hex: "#8F120A")
    static let fieldFill = Color.white.opacity(0.15)
    static let fieldBorder = Color.white.opacity(0.24)
    static let softText = Color.white.opacity(0.76)
}

private struct AuthPrimaryButton: View {
    var title: String
    var isLoading = false
    var isDisabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(AuthEntryPalette.deepRed)
                }

                Text(title)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(isDisabled ? AuthEntryPalette.deepRed.opacity(0.42) : AuthEntryPalette.deepRed)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(Color.white.opacity(isDisabled ? 0.54 : 0.96))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .shadow(color: Color.black.opacity(isDisabled ? 0 : 0.16), radius: 16, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
    }
}

private struct AuthErrorBanner: View {
    var message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .stroke(AuthEntryPalette.fieldBorder, lineWidth: 1)
        )
    }
}

private struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(minHeight: 50)
            .background(AuthEntryPalette.fieldFill)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AuthEntryPalette.fieldBorder, lineWidth: 1)
            )
    }
}

private struct LabeledAuthField<Content: View>: View {
    var title: String
    var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AuthEntryPalette.softText)
            content
        }
    }
}

private struct AuthTermsCheckboxRow: View {
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                (
                    Text("I accept the ")
                        .foregroundColor(AuthEntryPalette.softText)
                    + Text("terms of use")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    + Text(" and ")
                        .foregroundColor(AuthEntryPalette.softText)
                    + Text("privacy policy")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                )
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AuthSocialActions: View {
    var googleAction: () -> Void
    var phoneAction: () -> Void
    var isPhoneSelected: Bool
    var appleRequest: (ASAuthorizationAppleIDRequest) -> Void
    var appleCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            SocialCircleButton(systemImage: "g.circle", accessibilityLabel: "Continue with Google", action: googleAction)

            AppleCircleSignInButton(onRequest: appleRequest, onCompletion: appleCompletion)

            SocialCircleButton(
                systemImage: "iphone",
                accessibilityLabel: isPhoneSelected ? "Hide phone sign in" : "Continue with phone number",
                isSelected: isPhoneSelected,
                action: phoneAction
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SocialCircleButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var isSelected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(AuthEntryPalette.deepRed)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(isSelected ? 1 : 0.92))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.42), lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct AppleCircleSignInButton: View {
    var onRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(.white)
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color.white)
                    Image(systemName: "apple.logo")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.black)
                }
                .allowsHitTesting(false)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            .accessibilityLabel("Continue with Apple")
    }
}

private struct AuthModeFooter: View {
    var prompt: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            (
                Text("\(prompt) ")
                    .foregroundColor(AuthEntryPalette.softText)
                + Text(actionTitle)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            )
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(prompt) \(actionTitle)")
    }
}

private struct EmailVerificationView: View {
    @ObservedObject var session: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    var user: AuthUser

    var body: some View {
        AuthScaffold {
            AppCard(glow: true) {
                SectionTitle("Verify Email")
                Text(user.email ?? "Your email address")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text("Open the Firebase verification link, then return here to continue.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                if let message = session.errorMessage {
                    ErrorBanner(message: message) {
                        session.errorMessage = nil
                    }
                }

                PrimaryButton(
                    title: "I've Verified",
                    systemImage: "checkmark.circle",
                    isLoading: session.isWorking
                ) {
                    Task {
                        await session.refreshVerificationStatus(store: store)
                    }
                }

                SecondaryButton(title: "Resend Link", systemImage: "envelope") {
                    Task {
                        await session.resendVerificationEmail()
                    }
                }

                SecondaryButton(title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                    Task {
                        await session.signOut()
                    }
                }
            }
        }
    }
}

private struct CloudConflictView: View {
    @ObservedObject var session: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    var cloud: CloudPlannerSnapshotRecord

    var body: some View {
        AuthScaffold {
            AppCard(glow: true) {
                SectionTitle("Choose Planner Data")
                Text("Cloud and iPhone planner data are both populated and different.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                MetricRow(label: "This iPhone", value: localSummary)
                MetricRow(label: "Cloud backup", value: cloud.updatedAtIso ?? "Saved")

                if let message = session.errorMessage {
                    ErrorBanner(message: message) {
                        session.errorMessage = nil
                    }
                }

                PrimaryButton(
                    title: "Use This iPhone Data",
                    systemImage: "iphone",
                    isLoading: session.isWorking
                ) {
                    Task {
                        await session.resolveConflict(.useLocal, store: store)
                    }
                }

                SecondaryButton(title: "Use Cloud Data", systemImage: "icloud.and.arrow.down") {
                    Task {
                        await session.resolveConflict(.useCloud, store: store)
                    }
                }

                SecondaryButton(title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                    Task {
                        await session.signOut()
                    }
                }
            }
        }
    }

    private var localSummary: String {
        "\(store.snapshot.pots.count) pots, \(store.snapshot.transactions.count) spends"
    }
}

private struct AuthFailureView: View {
    @ObservedObject var session: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    var message: String

    var body: some View {
        AuthScaffold {
            AppCard(glow: true) {
                SectionTitle("Sync Issue")
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise", isLoading: session.isWorking) {
                    Task {
                        await session.start(store: store)
                    }
                }
                SecondaryButton(title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                    Task {
                        await session.signOut()
                    }
                }
            }
        }
    }
}

private struct AuthProgressView: View {
    var message: String

    var body: some View {
        AuthScaffold {
            LoadingView(title: message)
        }
    }
}

private struct AuthScaffold<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    content
                }
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.lg)
            }
        }
        .premiumScreenBackground()
        .dismissKeyboardOnBackgroundTap()
    }
}

private enum AppleSignInNonce {
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            guard status == errSecSuccess else {
                fatalError("Unable to generate secure random bytes for Apple sign-in.")
            }

            randomBytes.forEach { randomByte in
                guard remainingLength > 0 else { return }
                if randomByte < UInt8(charset.count) {
                    result.append(charset[Int(randomByte)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}
