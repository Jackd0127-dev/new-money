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
    case conflict(AuthUser, CloudPlannerSnapshotRecord)
    case ready(AuthUser)
    case failed(String)
}

enum CloudConflictChoice {
    case useLocal
    case useCloud
}

@MainActor
final class FirebaseAuthSession: ObservableObject {
    @Published private(set) var state: FirebaseAuthGateState = .loading("Checking account")
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published private(set) var cloudStatus = "Not synced"

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
        defer { isWorking = false }

        do {
            return try await authService.startPhoneSignIn(phoneNumber: phoneNumber)
        } catch {
            errorMessage = userFacingMessage(for: error)
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

    func resolveConflict(_ choice: CloudConflictChoice, store: PlannerStore) async {
        guard case let .conflict(user, cloud) = state else { return }

        await performWorkingAction {
            state = .syncing(user, "Applying sync choice")
            switch choice {
            case .useLocal:
                try await cloudSyncService.pushSnapshot(store.snapshot, for: user)
                lastUploadedSignature = try? PlannerCloudPayload.signature(for: store.snapshot)
            case .useCloud:
                try await store.replaceSnapshot(cloud.snapshot)
                lastUploadedSignature = try? PlannerCloudPayload.signature(for: cloud.snapshot)
            }
            cloudStatus = "Synced"
            state = .ready(user)
        }
    }

    func uploadLatestSnapshot(_ snapshot: PlannerSnapshot) async {
        guard case let .ready(user) = state else { return }
        guard let signature = try? PlannerCloudPayload.signature(for: snapshot),
              signature != lastUploadedSignature else { return }

        do {
            cloudStatus = "Uploading"
            try await cloudSyncService.pushSnapshot(snapshot, for: user)
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
            let cloud = try await cloudSyncService.pullSnapshot(for: user)
            let decision = PlannerCloudSyncResolver.decision(local: store.snapshot, cloud: cloud)

            switch decision {
            case .uploadLocal:
                cloudStatus = "Uploading iPhone data"
                try await cloudSyncService.pushSnapshot(store.snapshot, for: user)
                lastUploadedSignature = try? PlannerCloudPayload.signature(for: store.snapshot)
                cloudStatus = "Synced"
                state = .ready(user)
            case .downloadCloud:
                guard let cloud else {
                    cloudStatus = "Synced"
                    state = .ready(user)
                    return
                }
                cloudStatus = "Downloading cloud data"
                try await store.replaceSnapshot(cloud.snapshot)
                lastUploadedSignature = try? PlannerCloudPayload.signature(for: cloud.snapshot)
                cloudStatus = "Synced"
                state = .ready(user)
            case .alreadySynced, .keepEmptyLocal:
                lastUploadedSignature = try? PlannerCloudPayload.signature(for: store.snapshot)
                cloudStatus = "Synced"
                state = .ready(user)
            case .needsUserChoice:
                guard let cloud else {
                    cloudStatus = "Synced"
                    state = .ready(user)
                    return
                }
                cloudStatus = "Needs review"
                state = .conflict(user, cloud)
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
        }

        parts.append("Firebase Auth: \(codeName) (\(nsError.code))")
        return parts.joined(separator: "\n\n")
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
}
