import Foundation
import FirebaseAuth

enum AuthAccessRoute: Equatable {
    case signedOut
    case emailVerificationRequired
    case signedIn
}

enum AuthAccessRouter {
    static func route(for user: AuthUser?) -> AuthAccessRoute {
        guard let user else { return .signedOut }
        return user.requiresEmailVerification ? .emailVerificationRequired : .signedIn
    }
}

enum FirebaseAuthGateState: Equatable {
    case loading(String)
    case signedOut
    case emailVerificationRequired(AuthUser)
    case syncing(AuthUser, String)
    case ready(AuthUser)
    case failed(String)
}

@MainActor
final class FirebaseAuthSession: ObservableObject {
    @Published private(set) var state: FirebaseAuthGateState = .loading("Checking account")
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published private(set) var cloudStatus = "Not synced"
    @Published private(set) var phoneAuthDebugMessage: String?

    private let authService: AuthService
    private let cloudSyncService: CloudSyncService
    private var lastUploadedSignature: String?

    init(
        authService: AuthService = FirebaseAuthService(),
        cloudSyncService: CloudSyncService = FirebaseCloudSyncService()
    ) {
        self.authService = authService
        self.cloudSyncService = cloudSyncService
    }

    func start(store: PlannerStore) async {
        await routeCurrentUser(store: store)
    }

    func signInWithEmail(email: String, password: String, store: PlannerStore) async {
        await performWorkingAction {
            let user = try await authService.signInWithEmail(email: email, password: password)
            await openSession(for: user, store: store)
        }
    }

    func createEmailAccount(email: String, password: String) async {
        await performWorkingAction {
            let user = try await authService.createEmailAccount(email: email, password: password)
            cloudStatus = "Waiting for email verification"
            state = .emailVerificationRequired(user)
        }
    }

    func resendVerificationEmail() async {
        await performWorkingAction {
            try await authService.sendEmailVerification()
        }
    }

    func refreshVerificationStatus(store: PlannerStore) async {
        await performWorkingAction {
            let user = try await authService.refreshCurrentUser()
            await route(user: user, store: store)
        }
    }

    func startPhoneVerification(phoneNumber: String) async -> String? {
        isWorking = true
        errorMessage = nil
        let normalizedPhoneNumber = PhoneSignInNumberFormatter.normalizedForFirebase(phoneNumber)
        phoneAuthDebugMessage = PhoneAuthDebugPresenter.starting(
            phoneNumber: normalizedPhoneNumber,
            apnsStatus: FirebasePhoneAuthAPNsBridge.shared.debugStatus
        )
        defer { isWorking = false }

        do {
            let verificationID = try await authService.startPhoneSignIn(phoneNumber: phoneNumber)
            phoneAuthDebugMessage = PhoneAuthDebugPresenter.succeeded(
                phoneNumber: normalizedPhoneNumber,
                apnsStatus: FirebasePhoneAuthAPNsBridge.shared.debugStatus
            )
            return verificationID
        } catch {
            let message = userFacingMessage(for: error)
            errorMessage = message
            phoneAuthDebugMessage = PhoneAuthDebugPresenter.failed(
                phoneNumber: normalizedPhoneNumber,
                apnsStatus: FirebasePhoneAuthAPNsBridge.shared.debugStatus,
                errorMessage: message
            )
            return nil
        }
    }

    func confirmPhoneCode(verificationID: String, code: String, store: PlannerStore) async {
        await performWorkingAction {
            let user = try await authService.confirmPhoneCode(verificationID: verificationID, code: code)
            await openSession(for: user, store: store)
        }
    }

    func signInWithGoogle(store: PlannerStore) async {
        await performWorkingAction {
            let user = try await authService.signInWithGoogle()
            await openSession(for: user, store: store)
        }
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?, store: PlannerStore) async {
        await performWorkingAction {
            let user = try await authService.signInWithApple(idToken: idToken, nonce: nonce, fullName: fullName)
            await openSession(for: user, store: store)
        }
    }

    func uploadLatestPlannerData(from store: PlannerStore) async {
        guard case let .ready(user) = state else { return }
        let collection = store.accountCollectionForCloudUpload()
        guard let signature = try? PlannerCloudPayload.signature(for: collection),
              signature != lastUploadedSignature else { return }

        do {
            cloudStatus = "Uploading"
            try await cloudSyncService.pushAccountCollection(collection, for: user)
            lastUploadedSignature = signature
            cloudStatus = "Synced"
        } catch {
            cloudStatus = "Sync failed"
            errorMessage = userFacingMessage(for: error)
        }
    }

    func signOut() async {
        await performWorkingAction {
            try await authService.signOut()
            lastUploadedSignature = nil
            cloudStatus = "Signed out"
            state = .signedOut
        }
    }

    func deleteAccount() async {
        await performWorkingAction {
            let idToken = try await authService.idToken(forceRefresh: true)
            try await authService.deleteAccount(idToken: idToken)
            lastUploadedSignature = nil
            cloudStatus = "Account deleted"
            state = .signedOut
        }
    }

    private func routeCurrentUser(store: PlannerStore) async {
        let user = await authService.currentUser()
        await route(user: user, store: store)
    }

    private func route(user: AuthUser?, store: PlannerStore) async {
        switch AuthAccessRouter.route(for: user) {
        case .signedOut:
            cloudStatus = "Signed out"
            state = .signedOut
        case .emailVerificationRequired:
            guard let user else { return }
            cloudStatus = "Waiting for email verification"
            state = .emailVerificationRequired(user)
        case .signedIn:
            guard let user else { return }
            await openSession(for: user, store: store)
        }
    }

    private func openSession(for user: AuthUser, store: PlannerStore) async {
        guard !user.requiresEmailVerification else {
            cloudStatus = "Waiting for email verification"
            state = .emailVerificationRequired(user)
            return
        }

        state = .syncing(user, "Resolving cloud sync")
        cloudStatus = "Checking cloud"
        await store.load()

        do {
            let cloud = try await cloudSyncService.pullAccountCollection(for: user)
            let local = store.accountCollectionForCloudUpload()
            let decision = PlannerCloudSyncResolver.decision(local: local, cloud: cloud)

            switch decision {
            case .uploadLocal:
                cloudStatus = "Uploading iPhone data"
                try await cloudSyncService.pushAccountCollection(local, for: user)
                lastUploadedSignature = try? PlannerCloudPayload.signature(for: local)
                cloudStatus = "Synced"
                state = .ready(user)
            case .downloadCloud:
                guard let cloud else {
                    cloudStatus = "Synced"
                    state = .ready(user)
                    return
                }
                cloudStatus = "Downloading cloud data"
                let savedCollection = try await store.replaceAccountCollection(cloud.collection)
                lastUploadedSignature = try? PlannerCloudPayload.signature(for: savedCollection)
                cloudStatus = "Synced"
                state = .ready(user)
            case .alreadySynced, .keepEmptyLocal:
                lastUploadedSignature = try? PlannerCloudPayload.signature(for: local)
                cloudStatus = "Synced"
                state = .ready(user)
            }
        } catch {
            cloudStatus = "Sync failed"
            state = .failed(userFacingMessage(for: error))
        }
    }

    private func performWorkingAction(_ action: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await action()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        FirebaseAuthErrorPresenter.message(for: error)
    }
}

enum PhoneAuthDebugPresenter {
    static func starting(phoneNumber: String, apnsStatus: String) -> String {
        [
            "Phone auth request started",
            "Phone: \(maskedPhoneNumber(phoneNumber))",
            "APNs: \(apnsStatus)"
        ].joined(separator: "\n")
    }

    static func succeeded(phoneNumber: String, apnsStatus: String) -> String {
        [
            "Phone auth request succeeded",
            "Phone: \(maskedPhoneNumber(phoneNumber))",
            "APNs: \(apnsStatus)",
            "Firebase returned an SMS verification ID."
        ].joined(separator: "\n")
    }

    static func failed(phoneNumber: String, apnsStatus: String, errorMessage: String) -> String {
        [
            "Phone auth request failed",
            "Phone: \(maskedPhoneNumber(phoneNumber))",
            "APNs: \(apnsStatus)",
            "Error: \(errorMessage)"
        ].joined(separator: "\n")
    }

    private static func maskedPhoneNumber(_ phoneNumber: String) -> String {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return trimmed }

        let prefix = trimmed.prefix(3)
        let suffix = trimmed.suffix(4)
        return "\(prefix)******\(suffix)"
    }
}

enum FirebaseAuthErrorPresenter {
    static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return detailedMessage(for: error, baseDescription: description)
        }

        return detailedMessage(for: error, baseDescription: error.localizedDescription)
    }

    private static func detailedMessage(for error: Error, baseDescription: String) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrors.domain else {
            return baseDescription
        }

        let code = AuthErrorCode(rawValue: nsError.code)
        let codeName = (nsError.userInfo[AuthErrors.userInfoNameKey] as? String)
            ?? code.map { String(describing: $0) }
            ?? "UNKNOWN"
        var parts = [baseDescription]

        if let hint = hint(for: code) {
            parts.append(hint)
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("Underlying: \(underlying.domain) \(underlying.code) - \(underlying.localizedDescription)")
            parts.append(contentsOf: diagnosticParts(for: underlying))
        }

        parts.append(contentsOf: diagnosticParts(for: nsError))
        parts.append("Firebase Auth: \(codeName) (\(nsError.code))")
        let message = parts.uniqued().joined(separator: "\n\n")
#if DEBUG
        print("Firebase Auth error details:\n\(message)")
#endif
        return message
    }

    private static func hint(for code: AuthErrorCode?) -> String? {
        switch code {
        case .operationNotAllowed:
            return "Check Firebase Console: Authentication > Sign-in method > Phone must be enabled, and the SMS region policy must allow this country."
        case .appNotAuthorized:
            return "Check Firebase Console: the iOS app bundle ID and downloaded GoogleService-Info.plist must match this build."
        case .missingAppCredential, .invalidAppCredential, .captchaCheckFailed:
            return "Check Firebase Console: upload/configure APNs for this iOS app, then verify the app URL schemes are present."
        case .quotaExceeded, .tooManyRequests:
            return "Firebase is rate-limiting or the SMS quota is exceeded. Wait, use a test phone number, or check Firebase Auth quotas."
        case .invalidPhoneNumber:
            return "The phone number Firebase received is invalid. Use full international format, for example +447483260885."
        case .notificationNotForwarded:
            return "Firebase Phone Auth could not verify its APNs notification callback. Reinstall the latest build and confirm Firebase app delegate proxying is enabled."
        default:
            return nil
        }
    }

    private static func diagnosticParts(for error: NSError) -> [String] {
        var parts: [String] = []

        if let failureReason = error.localizedFailureReason, !failureReason.isEmpty {
            parts.append("Failure reason: \(failureReason)")
        }

        if let recoverySuggestion = error.localizedRecoverySuggestion, !recoverySuggestion.isEmpty {
            parts.append("Recovery suggestion: \(recoverySuggestion)")
        }

        if let response = error.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] {
            if diagnosticContains("BILLING_NOT_ENABLED", in: response) {
                parts.append("Billing is not enabled for this Firebase project. Real phone-number SMS verification requires Firebase/Google Cloud billing on the Blaze plan; test phone numbers can still be used without sending SMS.")
            }
            parts.append("Firebase response: \(diagnosticDescription(for: response))")
        }

        return parts
    }

    private static func diagnosticContains(_ needle: String, in value: Any) -> Bool {
        switch value {
        case let string as String:
            return string.localizedCaseInsensitiveContains(needle)
        case let dictionary as [String: Any]:
            return dictionary.contains { key, value in
                key.localizedCaseInsensitiveContains(needle) || diagnosticContains(needle, in: value)
            }
        case let dictionary as [String: AnyHashable]:
            return dictionary.contains { key, value in
                key.localizedCaseInsensitiveContains(needle) || diagnosticContains(needle, in: value)
            }
        case let array as [Any]:
            return array.contains { diagnosticContains(needle, in: $0) }
        default:
            return String(describing: value).localizedCaseInsensitiveContains(needle)
        }
    }

    private static func diagnosticDescription(for value: Any) -> String {
        switch value {
        case let dictionary as [String: Any]:
            dictionary
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \(diagnosticDescription(for: $0.value))" }
                .joined(separator: ", ")
        case let dictionary as [String: AnyHashable]:
            dictionary
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \(diagnosticDescription(for: $0.value))" }
                .joined(separator: ", ")
        case let array as [Any]:
            array.map(diagnosticDescription(for:)).joined(separator: ", ")
        default:
            String(describing: value)
        }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
