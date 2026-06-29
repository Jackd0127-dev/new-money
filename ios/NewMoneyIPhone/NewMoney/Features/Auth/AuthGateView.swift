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

private enum AuthEntryMode: String, CaseIterable, Identifiable {
    case email
    case phone

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private enum EmailAuthMode: String, CaseIterable, Identifiable {
    case signIn
    case create

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn:
            return "Sign In"
        case .create:
            return "Create"
        }
    }
}

private struct AuthEntryView: View {
    @ObservedObject var session: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    @State private var entryMode: AuthEntryMode = .email
    @State private var emailMode: EmailAuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var phoneNumber = ""
    @State private var smsCode = ""
    @State private var phoneVerificationID: String?
    @State private var currentAppleNonce: String?

    var body: some View {
        AuthScaffold {
            AppCard(glow: true) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("New Money")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("Sign in to keep planner data backed up across app updates and installs.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                if let message = session.errorMessage {
                    ErrorBanner(message: message) {
                        session.errorMessage = nil
                    }
                }

                Picker("Login type", selection: $entryMode) {
                    ForEach(AuthEntryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch entryMode {
                case .email:
                    emailForm
                case .phone:
                    phoneForm
                }

                AppDivider()

                socialButtons
            }
        }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Picker("Email mode", selection: $emailMode) {
                ForEach(EmailAuthMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(AppTextFieldStyle())

            SecureField("Password", text: $password)
                .textContentType(emailMode == .signIn ? .password : .newPassword)
                .textFieldStyle(AppTextFieldStyle())

            PrimaryButton(
                title: emailMode == .signIn ? "Sign In" : "Create Account",
                systemImage: emailMode == .signIn ? "person.crop.circle" : "person.crop.circle.badge.plus",
                isLoading: session.isWorking,
                isDisabled: email.isEmpty || password.count < 6
            ) {
                Task {
                    switch emailMode {
                    case .signIn:
                        await session.signInWithEmail(email: email, password: password, store: store)
                    case .create:
                        await session.createEmailAccount(email: email, password: password)
                    }
                }
            }
        }
    }

    private var phoneForm: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            TextField("Phone number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .textFieldStyle(AppTextFieldStyle())

            if phoneVerificationID != nil {
                TextField("SMS code", text: $smsCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(AppTextFieldStyle())
            }

            PrimaryButton(
                title: phoneVerificationID == nil ? "Send SMS Code" : "Verify Code",
                systemImage: phoneVerificationID == nil ? "message" : "checkmark.shield",
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

            if phoneVerificationID != nil {
                SecondaryButton(title: "Change Number", systemImage: "arrow.counterclockwise") {
                    phoneVerificationID = nil
                    smsCode = ""
                }
            }
        }
    }

    private var socialButtons: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SecondaryButton(title: "Continue with Google", systemImage: "g.circle") {
                Task {
                    await session.signInWithGoogle(store: store)
                }
            }

            SignInWithAppleButton(.continue) { request in
                let nonce = AppleSignInNonce.randomNonceString()
                currentAppleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInNonce.sha256(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    handleAppleAuthorization(authorization)
                case .failure(let error):
                    session.errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
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

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                content
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xl)
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
