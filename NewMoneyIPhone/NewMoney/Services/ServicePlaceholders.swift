import Foundation

struct AuthUser: Sendable, Equatable {
    var uid: String
    var email: String?
    var phoneNumber: String?
    var isEmailVerified: Bool
    var providerIDs: [String]

    var requiresEmailVerification: Bool {
        providerIDs.contains("password") && !isEmailVerified
    }

    var providerLabel: String {
        if providerIDs.contains("apple.com") { return "Apple" }
        if providerIDs.contains("google.com") { return "Google" }
        if providerIDs.contains("phone") { return "Phone" }
        if providerIDs.contains("password") { return "Email" }
        return "Firebase"
    }
}

@MainActor
protocol AuthService {
    var isConfigured: Bool { get }
    func currentUser() async -> AuthUser?
    func refreshCurrentUser() async throws -> AuthUser?
    func signInWithEmail(email: String, password: String) async throws -> AuthUser
    func createEmailAccount(email: String, password: String) async throws -> AuthUser
    func sendEmailVerification() async throws
    func startPhoneSignIn(phoneNumber: String) async throws -> String
    func confirmPhoneCode(verificationID: String, code: String) async throws -> AuthUser
    func signInWithGoogle() async throws -> AuthUser
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> AuthUser
    func idToken(forceRefresh: Bool) async throws -> String
    func signOut() async throws
    func deleteAccount(idToken: String) async throws
}

struct PlaceholderAuthService: AuthService {
    var isConfigured: Bool { false }

    func currentUser() async -> AuthUser? { nil }

    func refreshCurrentUser() async throws -> AuthUser? { nil }

    // TODO: Add Firebase iOS Auth plus GoogleService-Info.plist before enabling native account sign-in.
    func signInWithEmail(email: String, password: String) async throws -> AuthUser {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func createEmailAccount(email: String, password: String) async throws -> AuthUser {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func sendEmailVerification() async throws {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func startPhoneSignIn(phoneNumber: String) async throws -> String {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func confirmPhoneCode(verificationID: String, code: String) async throws -> AuthUser {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func signInWithGoogle() async throws -> AuthUser {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> AuthUser {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func idToken(forceRefresh: Bool) async throws -> String {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func signOut() async throws {}

    func deleteAccount(idToken: String) async throws {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }
}

@MainActor
protocol CloudSyncService {
    func pullAccountCollection(for user: AuthUser) async throws -> CloudPlannerAccountCollectionRecord?
    func pushAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws
    func resetAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws
    func readAuthoritative(for user: AuthUser) async throws -> PlannerCloudRead
    func compareAndSet(_ pending: PlannerPendingUpload, for user: AuthUser) async throws -> PlannerCloudWriteResult
}

extension CloudSyncService {
    // Compatibility for existing test doubles. Production implements an explicit server read.
    func readAuthoritative(for user: AuthUser) async throws -> PlannerCloudRead {
        guard let record = try await pullAccountCollection(for: user) else { return .missing }
        return try PlannerCloudRead.collection(record.collection)
    }

    func compareAndSet(_ pending: PlannerPendingUpload, for user: AuthUser) async throws -> PlannerCloudWriteResult {
        // Never degrade a conditional write to the old unconditional upload API.
        throw PlannerSyncRecoveryError.conditionalWritesUnavailable
    }
}

struct PlaceholderCloudSyncService: CloudSyncService {
    // TODO: Mirror the web Firestore document users/{uid}/planner/snapshot once native auth can provide a UID.
    func pullAccountCollection(for user: AuthUser) async throws -> CloudPlannerAccountCollectionRecord? {
        throw ServicePlaceholderError.missingFirestoreConfiguration
    }

    func pushAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws {
        throw ServicePlaceholderError.missingFirestoreConfiguration
    }

    func resetAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws {
        throw ServicePlaceholderError.missingFirestoreConfiguration
    }
}

protocol AIPlannerService: Sendable {
    func sendAssistantMessage(_ message: String, snapshot: PlannerSnapshot, idToken: String) async throws -> String
    func createDailyBrief(snapshot: PlannerSnapshot, idToken: String) async throws -> String
}

struct PlaceholderAIPlannerService: AIPlannerService {
    // TODO: Call the existing Vercel APIs with a Firebase ID token; AI provider keys must remain server-side.
    func sendAssistantMessage(_ message: String, snapshot: PlannerSnapshot, idToken: String) async throws -> String {
        throw ServicePlaceholderError.missingAuthenticatedBackend
    }

    func createDailyBrief(snapshot: PlannerSnapshot, idToken: String) async throws -> String {
        throw ServicePlaceholderError.missingAuthenticatedBackend
    }
}

enum ServicePlaceholderError: Error, LocalizedError {
    case missingNativeFirebaseConfiguration
    case missingFirestoreConfiguration
    case missingAuthenticatedBackend

    var errorDescription: String? {
        switch self {
        case .missingNativeFirebaseConfiguration:
            return "Native Firebase is not configured yet. TODO: add GoogleService-Info.plist and Firebase iOS Auth dependencies."
        case .missingFirestoreConfiguration:
            return "Firestore sync is not configured yet. TODO: wire users/{uid}/planner/snapshot with the web snapshot schema."
        case .missingAuthenticatedBackend:
            return "AI endpoints need a Firebase ID token. TODO: connect native auth and call /api/ai-assistant, /api/daily-brief, and /api/ai-planner."
        }
    }
}
