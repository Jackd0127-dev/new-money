import Foundation

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
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
