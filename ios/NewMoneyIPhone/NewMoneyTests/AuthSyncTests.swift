import Foundation
import FirebaseAuth
import XCTest
@testable import NewMoneyIPhone

final class AuthSyncTests: XCTestCase {
    func testAuthAccessRoutesSignedOutUser() {
        XCTAssertEqual(AuthAccessRouter.route(for: nil), .signedOut)
    }

    func testAuthAccessRoutesUnverifiedEmailUserToVerification() {
        let user = AuthUser(
            uid: "email-user",
            email: "test@example.com",
            phoneNumber: nil,
            isEmailVerified: false,
            providerIDs: ["password"]
        )

        XCTAssertEqual(AuthAccessRouter.route(for: user), .emailVerificationRequired)
    }

    func testAuthAccessRoutesPhoneUserToSignedIn() {
        let user = AuthUser(
            uid: "phone-user",
            email: nil,
            phoneNumber: "+15555550123",
            isEmailVerified: false,
            providerIDs: ["phone"]
        )

        XCTAssertEqual(AuthAccessRouter.route(for: user), .signedIn)
    }

    func testPhoneSignInNumberFormatterKeepsE164Number() {
        XCTAssertEqual(
            PhoneSignInNumberFormatter.normalizedForFirebase("+44 7483 260885"),
            "+447483260885"
        )
    }

    func testPhoneSignInNumberFormatterConvertsUkMobileWithLeadingZero() {
        XCTAssertEqual(
            PhoneSignInNumberFormatter.normalizedForFirebase("07483 260885"),
            "+447483260885"
        )
    }

    func testPhoneSignInNumberFormatterConvertsUkMobileWithoutLeadingZero() {
        XCTAssertEqual(
            PhoneSignInNumberFormatter.normalizedForFirebase("7483260885"),
            "+447483260885"
        )
    }

    func testPhoneSignInNumberFormatterConvertsInternationalPrefix() {
        XCTAssertEqual(
            PhoneSignInNumberFormatter.normalizedForFirebase("0044 7483 260885"),
            "+447483260885"
        )
    }

    func testPhoneAuthStartupRetryPolicyOnlyRetriesNotificationForwardingError() {
        let retryableError = NSError(
            domain: "FIRAuthErrorDomain",
            code: AuthErrorCode.notificationNotForwarded.rawValue
        )
        let otherAuthError = NSError(
            domain: "FIRAuthErrorDomain",
            code: AuthErrorCode.invalidPhoneNumber.rawValue
        )
        let otherDomainError = NSError(domain: NSURLErrorDomain, code: AuthErrorCode.notificationNotForwarded.rawValue)

        XCTAssertTrue(PhoneAuthStartupRetryPolicy.shouldRetry(retryableError))
        XCTAssertFalse(PhoneAuthStartupRetryPolicy.shouldRetry(otherAuthError))
        XCTAssertFalse(PhoneAuthStartupRetryPolicy.shouldRetry(otherDomainError))
    }

    func testFirebaseAuthErrorPresenterIncludesFirebaseCodeAndConsoleHint() {
        let error = NSError(
            domain: AuthErrors.domain,
            code: AuthErrorCode.operationNotAllowed.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "This provider is disabled.",
                AuthErrors.userInfoNameKey: "ERROR_OPERATION_NOT_ALLOWED"
            ]
        )

        let message = FirebaseAuthErrorPresenter.message(for: error)

        XCTAssertTrue(message.contains("This provider is disabled."))
        XCTAssertTrue(message.contains("Authentication > Sign-in method > Phone"))
        XCTAssertTrue(message.contains("Firebase Auth: ERROR_OPERATION_NOT_ALLOWED (17006)"))
    }

    func testFirebaseAuthErrorPresenterLeavesNonFirebaseErrorsSimple() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The internet connection appears to be offline."]
        )

        XCTAssertEqual(
            FirebaseAuthErrorPresenter.message(for: error),
            "The internet connection appears to be offline."
        )
    }

    func testSyncDecisionUploadsMeaningfulLocalSnapshotWhenCloudIsMissing() {
        let decision = PlannerCloudSyncResolver.decision(
            local: DefaultData.basicDataSnapshot,
            cloud: nil
        )

        XCTAssertEqual(decision, .uploadLocal)
    }

    func testSyncDecisionDownloadsCloudSnapshotWhenLocalIsEmpty() {
        let cloud = CloudPlannerSnapshotRecord(
            snapshot: DefaultData.basicDataSnapshot,
            updatedAtIso: "2026-06-28T12:00:00.000Z"
        )

        let decision = PlannerCloudSyncResolver.decision(
            local: DefaultData.emptySnapshot,
            cloud: cloud
        )

        XCTAssertEqual(decision, .downloadCloud)
    }

    func testSyncDecisionRequiresChoiceWhenBothSnapshotsHaveDifferentUserData() {
        let local = DefaultData.basicDataSnapshot
        var cloudSnapshot = DefaultData.basicDataSnapshot
        cloudSnapshot.settings.assistantName = "Cloud"

        let cloud = CloudPlannerSnapshotRecord(
            snapshot: cloudSnapshot,
            updatedAtIso: "2026-06-28T12:00:00.000Z"
        )

        let decision = PlannerCloudSyncResolver.decision(local: local, cloud: cloud)

        XCTAssertEqual(decision, .needsUserChoice)
    }

    func testCloudPayloadRoundTripsSnapshotAndMarksBackups() throws {
        let snapshot = DefaultData.basicDataSnapshot
        let payload = try PlannerCloudPayload.current(
            snapshot: snapshot,
            updatedAtIso: "2026-06-28T12:00:00.000Z"
        ).firestoreData()

        XCTAssertEqual(payload["version"] as? Int, 1)
        XCTAssertEqual(payload["updatedAtIso"] as? String, "2026-06-28T12:00:00.000Z")

        let snapshotData = try XCTUnwrap(payload["snapshot"] as? [String: Any])
        let decoded = try PlannerCloudPayload.decodeSnapshot(from: snapshotData)
        XCTAssertEqual(decoded, snapshot)

        let backupPayload = try PlannerCloudPayload.backup(
            snapshot: snapshot,
            updatedAtIso: "2026-06-28T12:00:00.000Z"
        ).firestoreData()
        XCTAssertEqual(backupPayload["backupVersion"] as? Int, 1)
    }
}
