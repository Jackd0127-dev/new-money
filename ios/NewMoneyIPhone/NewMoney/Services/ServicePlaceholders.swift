import Foundation

struct AuthUser: Sendable, Equatable {
    var uid: String
    var email: String?
}

protocol AuthService: Sendable {
    var isConfigured: Bool { get }
    func currentUser() async -> AuthUser?
    func signInWithEmail(email: String, password: String) async throws -> AuthUser
    func createEmailAccount(email: String, password: String) async throws -> AuthUser
    func signOut() async throws
    func deleteAccount(idToken: String) async throws
}

struct PlaceholderAuthService: AuthService {
    var isConfigured: Bool { false }

    func currentUser() async -> AuthUser? { nil }

    // TODO: Add Firebase iOS Auth plus GoogleService-Info.plist before enabling native account sign-in.
    func signInWithEmail(email: String, password: String) async throws -> AuthUser {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func createEmailAccount(email: String, password: String) async throws -> AuthUser {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }

    func signOut() async throws {}

    func deleteAccount(idToken: String) async throws {
        throw ServicePlaceholderError.missingNativeFirebaseConfiguration
    }
}

protocol CloudSyncService: Sendable {
    func pullSnapshot(for user: AuthUser) async throws -> PlannerSnapshot
    func pushSnapshot(_ snapshot: PlannerSnapshot, for user: AuthUser) async throws
}

struct PlaceholderCloudSyncService: CloudSyncService {
    // TODO: Mirror the web Firestore document users/{uid}/planner/snapshot once native auth can provide a UID.
    func pullSnapshot(for user: AuthUser) async throws -> PlannerSnapshot {
        throw ServicePlaceholderError.missingFirestoreConfiguration
    }

    func pushSnapshot(_ snapshot: PlannerSnapshot, for user: AuthUser) async throws {
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
