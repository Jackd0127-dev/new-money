import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class FirebaseAuthService: NSObject, AuthService {
    var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    func currentUser() async -> AuthUser? {
        Auth.auth().currentUser?.authUser
    }

    func refreshCurrentUser() async throws -> AuthUser? {
        guard let user = Auth.auth().currentUser else { return nil }
        try await user.reload()
        return Auth.auth().currentUser?.authUser
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthUser {
        let result = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        return result.user.authUser
    }

    func createEmailAccount(email: String, password: String) async throws -> AuthUser {
        let result = try await Auth.auth().createUser(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        try await result.user.sendEmailVerification()
        return result.user.authUser
    }

    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else { throw FirebaseNativeServiceError.missingCurrentUser }
        try await user.sendEmailVerification()
    }

    func startPhoneSignIn(phoneNumber: String) async throws -> String {
        let normalizedPhoneNumber = PhoneSignInNumberFormatter.normalizedForFirebase(phoneNumber)
        await FirebasePhoneAuthAPNsBridge.shared.waitForAPNSTokenIfNeeded()
        let retryDelays: [UInt64] = [
            250_000_000,
            750_000_000,
            1_500_000_000
        ]

        for attempt in 0...retryDelays.count {
            do {
                return try await PhoneAuthProvider.provider().verifyPhoneNumber(normalizedPhoneNumber, uiDelegate: nil)
            } catch {
                guard PhoneAuthStartupRetryPolicy.shouldRetry(error),
                      attempt < retryDelays.count else {
                    throw error
                }
                try await Task.sleep(nanoseconds: retryDelays[attempt])
            }
        }

        return try await PhoneAuthProvider.provider().verifyPhoneNumber(normalizedPhoneNumber, uiDelegate: nil)
    }

    func confirmPhoneCode(verificationID: String, code: String) async throws -> AuthUser {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user.authUser
    }

    func signInWithGoogle() async throws -> AuthUser {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw FirebaseNativeServiceError.missingGoogleClientID
        }
        guard let presentingController = UIApplication.shared.activeRootViewController else {
            throw FirebaseNativeServiceError.missingPresentingController
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingController)
        guard let idToken = signInResult.user.idToken?.tokenString else {
            throw FirebaseNativeServiceError.missingGoogleIDToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: signInResult.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user.authUser
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> AuthUser {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: fullName
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user.authUser
    }

    func idToken(forceRefresh: Bool) async throws -> String {
        guard let user = Auth.auth().currentUser else { throw FirebaseNativeServiceError.missingCurrentUser }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    func deleteAccount(idToken: String) async throws {
        guard let url = URL(string: "https://money.scriptai.space/api/account") else {
            throw FirebaseNativeServiceError.invalidAccountEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw FirebaseNativeServiceError.accountDeletionFailed
        }

        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
    }
}

enum PhoneAuthStartupRetryPolicy {
    static func shouldRetry(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "FIRAuthErrorDomain"
            && nsError.code == AuthErrorCode.notificationNotForwarded.rawValue
    }
}

enum PhoneSignInNumberFormatter {
    static func normalizedForFirebase(_ rawValue: String, defaultCountryCode: String = "+44") -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("+") {
            let digits = trimmed.dropFirst().filter(\.isNumber)
            return digits.isEmpty ? trimmed : "+\(digits)"
        }

        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else { return trimmed }

        if digits.hasPrefix("00") {
            let internationalDigits = String(digits.dropFirst(2))
            return internationalDigits.isEmpty ? trimmed : "+\(internationalDigits)"
        }

        let countryCode = normalizedCountryCode(defaultCountryCode)
        let countryDigits = countryCode.filter(\.isNumber)
        if !countryDigits.isEmpty, digits.hasPrefix(countryDigits) {
            return "+\(digits)"
        }

        if countryDigits == "44" {
            if digits.hasPrefix("0") {
                return "+44\(String(digits.dropFirst()))"
            }
            if digits.hasPrefix("7"), digits.count == 10 {
                return "+44\(digits)"
            }
        }

        if countryDigits == "1", digits.count == 10 {
            return "+1\(digits)"
        }

        return "\(countryCode)\(digits)"
    }

    private static func normalizedCountryCode(_ rawValue: String) -> String {
        let digits = rawValue.filter(\.isNumber)
        return digits.isEmpty ? "+44" : "+\(digits)"
    }
}

struct FirebaseCloudSyncService: CloudSyncService {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func pullAccountCollection(for user: AuthUser) async throws -> CloudPlannerAccountCollectionRecord? {
        let read = try await readAuthoritative(for: user)
        guard let collection = read.collection else { return nil }
        return CloudPlannerAccountCollectionRecord(collection: collection, updatedAtIso: read.updatedAtIso)
    }

    func pushAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws {
        // Kept only for source compatibility. Every production write must carry its observed baseline.
        throw PlannerSyncRecoveryError.conditionalWritesUnavailable
    }

    func readAuthoritative(for user: AuthUser) async throws -> PlannerCloudRead {
        let document = try await snapshotDocument(for: user).getDocument(source: .server)
        guard !document.metadata.isFromCache, !document.metadata.hasPendingWrites else {
            throw PlannerSyncRecoveryError.invalidPayload
        }
        return try Self.plannerRead(document)
    }

    func compareAndSet(_ pending: PlannerPendingUpload, for user: AuthUser) async throws -> PlannerCloudWriteResult {
        let document = snapshotDocument(for: user)
        let context = PlannerFirestoreWriteContext(document: document,
            backup: document.collection("backups").document("sync-" + PlannerCloudFingerprint.data(Data(pending.operationID.utf8))),
            pending: pending, updatedAtIso: DateUtilities.nowIsoString())

        // Keep the SDK handle on its actor; only immutable context and typed results cross callback queues.
        let result: PlannerFirestoreTransactionResult = try await withCheckedThrowingContinuation { continuation in
            firestore.runTransaction({ @Sendable transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(context.document)
                    let current = try Self.plannerRead(snapshot)
                    if let collection = current.collection,
                       try PlannerCloudFingerprint.collection(collection) == PlannerCloudFingerprint.collection(context.pending.collection) {
                        return ["kind": "unchanged", "record": try JSONEncoder().encode(current)]
                    }
                    guard current.revision == context.pending.expectedRevision else {
                        return ["kind": "conflict", "record": try JSONEncoder().encode(current)]
                    }

                    var fields = snapshot.data() ?? [:]
                    let newCollection = try PlannerCloudPayload.accountCollectionDictionary(context.pending.collection)
                    if let oldRaw = fields["accountCollection"], let oldCollection = current.collection {
                        let oldKnown = try PlannerCloudPayload.accountCollectionDictionary(oldCollection)
                        fields["accountCollection"] = PlannerCloudDocumentCodec.preservingUnknownFields(
                            raw: oldRaw, before: oldKnown, after: newCollection)
                    } else {
                        fields["accountCollection"] = newCollection
                    }
                    fields["version"] = 2
                    fields["schema"] = "plannerAccountCollection"
                    fields["updatedAtIso"] = context.updatedAtIso
                    let expectedPayloadHash = try PlannerCloudDocumentCodec.read(fields: fields).revision.payloadSHA256
                    fields["updatedAt"] = FieldValue.serverTimestamp()
                    var backup = fields
                    backup["backupVersion"] = 2
                    transaction.setData(fields, forDocument: context.document)
                    transaction.setData(backup, forDocument: context.backup)
                    return ["kind": "written", "payloadSHA256": expectedPayloadHash ?? ""]
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
            }, completion: { @Sendable result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                do {
                    continuation.resume(returning: try PlannerFirestoreTransactionResult.decode(result))
                } catch {
                    continuation.resume(throwing: error)
                }
            })
        }

        switch result {
        case let .committed(read): return .committed(read)
        case let .conflict(read): return .conflict(read)
        case let .written(expectedHash):
            let verified = try await readAuthoritative(for: user)
            return verified.revision.payloadSHA256 == expectedHash ? .committed(verified) : .conflict(verified)
        }
    }

    nonisolated private static func plannerRead(_ document: DocumentSnapshot) throws -> PlannerCloudRead {
        guard document.exists else { return .missing }
        guard let fields = document.data() else { throw PlannerSyncRecoveryError.invalidPayload }
        let timestamp = (fields["updatedAt"] as? Timestamp).map {
            PlannerServerTimestamp(seconds: $0.seconds, nanoseconds: $0.nanoseconds)
        }
        return try PlannerCloudDocumentCodec.read(fields: fields, updatedAt: timestamp)
    }

    func resetAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws {
        let snapshotDocument = snapshotDocument(for: user)
        let backupReferences = try await snapshotDocument
            .collection("backups")
            .getDocuments()
            .documents
            .map(\.reference)

        try await deleteDocuments(backupReferences + [snapshotDocument])

        let updatedAtIso = DateUtilities.nowIsoString()
        var currentData = try PlannerCloudPayload.currentAccounts(collection: collection, updatedAtIso: updatedAtIso).firestoreData()
        currentData["updatedAt"] = FieldValue.serverTimestamp()
        try await snapshotDocument.setData(currentData, merge: false)
    }

    private func snapshotDocument(for user: AuthUser) -> DocumentReference {
        firestore
            .collection("users")
            .document(user.uid)
            .collection("planner")
            .document("snapshot")
    }

    private func deleteDocuments(_ references: [DocumentReference]) async throws {
        var remainingReferences = references

        while !remainingReferences.isEmpty {
            let batch = firestore.batch()
            let chunk = Array(remainingReferences.prefix(450))

            for reference in chunk {
                batch.deleteDocument(reference)
            }

            try await batch.commit()
            remainingReferences.removeFirst(chunk.count)
        }
    }
}

/// Firebase references are immutable handles; each retry constructs its own mutable dictionaries.
private struct PlannerFirestoreWriteContext: @unchecked Sendable {
    let document: DocumentReference
    let backup: DocumentReference
    let pending: PlannerPendingUpload
    let updatedAtIso: String
}

private enum PlannerFirestoreTransactionResult: Sendable {
    case committed(PlannerCloudRead)
    case conflict(PlannerCloudRead)
    case written(String)

    static func decode(_ value: Any?) throws -> Self {
        guard let result = value as? [String: Any], let kind = result["kind"] as? String else {
            throw PlannerSyncRecoveryError.invalidPayload
        }
        if let data = result["record"] as? Data {
            let read = try JSONDecoder().decode(PlannerCloudRead.self, from: data)
            switch kind {
            case "conflict": return .conflict(read)
            case "unchanged": return .committed(read)
            default: throw PlannerSyncRecoveryError.invalidPayload
            }
        }
        guard kind == "written", let expectedHash = result["payloadSHA256"] as? String else {
            throw PlannerSyncRecoveryError.invalidPayload
        }
        return .written(expectedHash)
    }
}

enum FirebaseNativeServiceError: Error, LocalizedError {
    case missingCurrentUser
    case missingGoogleClientID
    case missingGoogleIDToken
    case missingPresentingController
    case invalidAccountEndpoint
    case accountDeletionFailed
    case missingAppleIDToken

    var errorDescription: String? {
        switch self {
        case .missingCurrentUser:
            return "No signed-in Firebase user was found."
        case .missingGoogleClientID:
            return "Google sign-in is missing its Firebase client ID."
        case .missingGoogleIDToken:
            return "Google did not return an ID token."
        case .missingPresentingController:
            return "The app could not open the sign-in window."
        case .invalidAccountEndpoint:
            return "The account deletion endpoint is not valid."
        case .accountDeletionFailed:
            return "Account deletion failed. Try again from Settings."
        case .missingAppleIDToken:
            return "Apple did not return an identity token."
        }
    }
}

private extension FirebaseAuth.User {
    var authUser: AuthUser {
        let providerIDs = providerData.map(\.providerID)
        return AuthUser(
            uid: uid,
            email: email,
            phoneNumber: phoneNumber,
            isEmailVerified: isEmailVerified,
            providerIDs: providerIDs.isEmpty ? [providerID] : providerIDs
        )
    }
}

private extension UIApplication {
    var activeRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topPresentedController
    }
}

private extension UIViewController {
    var topPresentedController: UIViewController {
        presentedViewController?.topPresentedController ?? self
    }
}
