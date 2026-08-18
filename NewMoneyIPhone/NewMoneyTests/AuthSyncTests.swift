import Foundation
import FirebaseAuth
import UIKit
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

    func testPhoneAuthDebugPresenterMasksNumberAndShowsAPNsStatus() {
        let message = PhoneAuthDebugPresenter.starting(
            phoneNumber: "+447483260885",
            apnsStatus: "APNs token received"
        )

        XCTAssertTrue(message.contains("Phone auth request started"))
        XCTAssertTrue(message.contains("+44******0885"))
        XCTAssertFalse(message.contains("+447483260885"))
        XCTAssertTrue(message.contains("APNs token received"))
    }

    func testPhoneAuthDebugPresenterIncludesFailureDetails() {
        let message = PhoneAuthDebugPresenter.failed(
            phoneNumber: "+447483260885",
            apnsStatus: "APNs token missing",
            errorMessage: "Firebase response: error: message: INVALID_APP_CREDENTIAL"
        )

        XCTAssertTrue(message.contains("Phone auth request failed"))
        XCTAssertTrue(message.contains("+44******0885"))
        XCTAssertTrue(message.contains("APNs token missing"))
        XCTAssertTrue(message.contains("INVALID_APP_CREDENTIAL"))
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

    func testFirebaseAuthErrorPresenterSurfacesInternalErrorDiagnostics() {
        let underlyingError = NSError(
            domain: "FIRAuthInternalErrorDomain",
            code: 3,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn't be completed.",
                NSLocalizedFailureReasonErrorKey: "APNs token did not match the Firebase app configuration.",
                "FIRAuthErrorUserInfoDeserializedResponseKey": [
                    "error": [
                        "message": "INVALID_APP_CREDENTIAL"
                    ]
                ]
            ]
        )
        let error = NSError(
            domain: AuthErrors.domain,
            code: AuthErrorCode.internalError.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "An internal error has occurred.",
                AuthErrors.userInfoNameKey: "ERROR_INTERNAL_ERROR",
                NSUnderlyingErrorKey: underlyingError
            ]
        )

        let message = FirebaseAuthErrorPresenter.message(for: error)

        XCTAssertTrue(message.contains("APNs token did not match the Firebase app configuration."))
        XCTAssertTrue(message.contains("INVALID_APP_CREDENTIAL"))
        XCTAssertTrue(message.contains("Firebase Auth: ERROR_INTERNAL_ERROR (17999)"))
    }

    func testFirebaseAuthErrorPresenterExplainsBillingNotEnabled() {
        let underlyingError = NSError(
            domain: "FIRAuthInternalErrorDomain",
            code: 3,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn't be completed.",
                "FIRAuthErrorUserInfoDeserializedResponseKey": [
                    "error": [
                        "code": 400,
                        "message": "BILLING_NOT_ENABLED"
                    ]
                ]
            ]
        )
        let error = NSError(
            domain: AuthErrors.domain,
            code: AuthErrorCode.internalError.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "An internal error has occurred.",
                AuthErrors.userInfoNameKey: "ERROR_INTERNAL_ERROR",
                NSUnderlyingErrorKey: underlyingError
            ]
        )

        let message = FirebaseAuthErrorPresenter.message(for: error)

        XCTAssertTrue(message.contains("Billing is not enabled"))
        XCTAssertTrue(message.contains("Blaze"))
        XCTAssertTrue(message.contains("BILLING_NOT_ENABLED"))
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

    func testSyncDecisionDownloadsExistingCloudSnapshotEvenWhenCloudIsEmpty() {
        let cloud = CloudPlannerSnapshotRecord(
            snapshot: DefaultData.emptySnapshot,
            updatedAtIso: "2026-06-28T12:00:00.000Z"
        )

        let decision = PlannerCloudSyncResolver.decision(
            local: DefaultData.basicDataSnapshot,
            cloud: cloud
        )

        XCTAssertEqual(decision, .downloadCloud)
        XCTAssertTrue(PlannerCloudSyncPolicy.treatsExistingCloudSnapshotAsAuthoritative)
        XCTAssertFalse(PlannerCloudSyncPolicy.promptsForConflicts)
        XCTAssertFalse(AuthLaunchPresentationPolicy.promptsForCloudDataChoice)
    }

    func testSyncDecisionDownloadsCloudWhenBothSnapshotsHaveDifferentUserData() {
        let local = DefaultData.basicDataSnapshot
        var cloudSnapshot = DefaultData.basicDataSnapshot
        cloudSnapshot.settings.assistantName = "Cloud"

        let cloud = CloudPlannerSnapshotRecord(
            snapshot: cloudSnapshot,
            updatedAtIso: "2026-06-28T12:00:00.000Z"
        )

        let decision = PlannerCloudSyncResolver.decision(local: local, cloud: cloud)

        XCTAssertEqual(decision, .downloadCloud)
        XCTAssertTrue(PlannerCloudSyncPolicy.prefersMeaningfulCloudByDefault)
        XCTAssertTrue(PlannerCloudSyncPolicy.treatsExistingCloudSnapshotAsAuthoritative)
        XCTAssertFalse(PlannerCloudSyncPolicy.promptsForConflicts)
        XCTAssertFalse(AuthLaunchPresentationPolicy.showsLoadingScreens)
        XCTAssertFalse(AuthLaunchPresentationPolicy.promptsForCloudDataChoice)
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

    func testCloudPayloadRoundTripsFullPlannerAccountCollectionAndMarksBackups() throws {
        var personalSnapshot = DefaultData.emptySnapshot
        personalSnapshot.pots = [
            Pot(
                id: "personal-pot",
                name: "Personal Pot",
                type: .saving,
                category: nil,
                icon: nil,
                balancePence: 1_500,
                targetPence: nil,
                color: "#F97316",
                linkedCreditCardId: nil,
                linkedDebtId: nil,
                archived: false,
                createdAt: "2026-07-01T10:00:00.000Z",
                updatedAt: "2026-07-01T10:00:00.000Z",
                deletedAt: nil
            )
        ]

        var sideSnapshot = DefaultData.emptySnapshot
        sideSnapshot.transactions = [
            Transaction(
                id: "side-spend",
                potId: nil,
                payPeriodId: nil,
                amountPence: 725,
                type: .spending,
                paymentMethod: nil,
                creditCardId: nil,
                recurringPaymentId: nil,
                date: "2026-07-02",
                note: "Side coffee",
                createdAt: "2026-07-02T10:00:00.000Z",
                updatedAt: "2026-07-02T10:00:00.000Z",
                deletedAt: nil
            )
        ]

        let collection = PlannerAccountCollection(
            activeAccountId: "side-account",
            selectedThemePresetId: AppThemePreset.warmLight.rawValue,
            accounts: [
                PlannerAccount(
                    id: "personal-account",
                    name: "Personal",
                    color: "#F97316",
                    avatarImageName: "personal-avatar.jpg",
                    avatarImageDataBase64: "encoded-personal-avatar",
                    snapshot: personalSnapshot,
                    createdAt: "2026-07-01T09:00:00.000Z",
                    updatedAt: "2026-07-01T10:00:00.000Z"
                ),
                PlannerAccount(
                    id: "side-account",
                    name: "Side",
                    color: "#14B8A6",
                    avatarImageName: nil,
                    avatarImageDataBase64: nil,
                    snapshot: sideSnapshot,
                    createdAt: "2026-07-02T09:00:00.000Z",
                    updatedAt: "2026-07-02T10:00:00.000Z"
                )
            ],
            updatedAt: "2026-07-02T10:00:00.000Z"
        )

        let payload = try PlannerCloudPayload.currentAccounts(
            collection: collection,
            updatedAtIso: "2026-07-03T12:00:00.000Z"
        ).firestoreData()

        XCTAssertEqual(payload["version"] as? Int, 2)
        XCTAssertEqual(payload["schema"] as? String, "plannerAccountCollection")
        XCTAssertEqual(payload["updatedAtIso"] as? String, "2026-07-03T12:00:00.000Z")

        let accountCollectionData = try XCTUnwrap(payload["accountCollection"] as? [String: Any])
        let decoded = try PlannerCloudPayload.decodeAccountCollection(from: accountCollectionData)

        XCTAssertEqual(decoded.activeAccountId, "side-account")
        XCTAssertEqual(decoded.selectedThemePresetId, AppThemePreset.warmLight.rawValue)
        XCTAssertEqual(decoded.accounts.map(\.name), ["Personal", "Side"])
        XCTAssertEqual(decoded.accounts[0].avatarImageDataBase64, "encoded-personal-avatar")
        XCTAssertEqual(decoded.accounts[0].snapshot.pots.map(\.name), ["Personal Pot"])
        XCTAssertEqual(decoded.accounts[1].snapshot.transactions.map(\.note), ["Side coffee"])

        let backupPayload = try PlannerCloudPayload.backupAccounts(
            collection: collection,
            updatedAtIso: "2026-07-03T12:00:00.000Z"
        ).firestoreData()
        XCTAssertEqual(backupPayload["backupVersion"] as? Int, 2)
    }

    func testCloudPayloadDecodesLegacySnapshotDocumentAsSingleAccountCollection() throws {
        let snapshot = DefaultData.basicDataSnapshot
        let legacyPayload = try PlannerCloudPayload.current(
            snapshot: snapshot,
            updatedAtIso: "2026-06-28T12:00:00.000Z"
        ).firestoreData()

        let record = try XCTUnwrap(PlannerCloudPayload.decodeAccountCollectionRecord(from: legacyPayload))

        XCTAssertEqual(record.updatedAtIso, "2026-06-28T12:00:00.000Z")
        XCTAssertEqual(record.collection.accounts.count, 1)
        XCTAssertEqual(record.collection.activeAccount?.name, "Personal")
        XCTAssertEqual(record.collection.activeAccount?.snapshot, snapshot)
    }

    func testAccountCollectionSyncDecisionUsesFullCloudCollection() {
        let local = PlannerAccountCollection.singleAccount(snapshot: DefaultData.emptySnapshot)
        let cloud = CloudPlannerAccountCollectionRecord(
            collection: PlannerAccountCollection.singleAccount(snapshot: DefaultData.basicDataSnapshot),
            updatedAtIso: "2026-07-03T12:00:00.000Z"
        )

        XCTAssertEqual(PlannerCloudSyncResolver.decision(local: local, cloud: cloud), .downloadCloud)
        XCTAssertEqual(PlannerCloudSyncResolver.decision(local: cloud.collection, cloud: cloud), .alreadySynced)

        let multiAccountLocal = PlannerAccountCollection(
            activeAccountId: "two",
            selectedThemePresetId: nil,
            accounts: [
                PlannerAccount(id: "one", name: "One", color: "#F97316", snapshot: DefaultData.emptySnapshot, createdAt: "2026-07-01T10:00:00.000Z", updatedAt: "2026-07-01T10:00:00.000Z"),
                PlannerAccount(id: "two", name: "Two", color: "#14B8A6", snapshot: DefaultData.emptySnapshot, createdAt: "2026-07-02T10:00:00.000Z", updatedAt: "2026-07-02T10:00:00.000Z")
            ],
            updatedAt: "2026-07-02T10:00:00.000Z"
        )

        XCTAssertEqual(PlannerCloudSyncResolver.decision(local: multiAccountLocal, cloud: nil), .uploadLocal)
    }

    func testCloudPlannerResetPolicyClearsPlannerDataWithoutDeletingAuthUser() {
        XCTAssertTrue(PlannerCloudResetPolicy.deletesCurrentPlannerDocument)
        XCTAssertTrue(PlannerCloudResetPolicy.deletesPlannerBackups)
        XCTAssertTrue(PlannerCloudResetPolicy.writesEmptyCurrentPlannerDocument)
        XCTAssertFalse(PlannerCloudResetPolicy.deletesFirebaseAuthUser)
    }
}

@MainActor
final class PlannerAccountsTests: XCTestCase {
    func testPlannerAccountsCreateUpToThreeAndRejectFourth() async throws {
        let store = PlannerStore(
            repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.emptySnapshot),
            accountRepository: InMemoryPlannerAccountRepository()
        )

        await store.load()

        XCTAssertEqual(store.plannerAccounts.map(\.name), ["Personal"])
        XCTAssertTrue(store.canCreatePlannerAccount)

        try await store.createPlannerAccount(named: "Work")
        XCTAssertEqual(store.activePlannerAccount?.name, "Work")

        try await store.createPlannerAccount(named: "Bills")
        XCTAssertEqual(store.activePlannerAccount?.name, "Bills")

        XCTAssertEqual(store.plannerAccounts.map(\.name), ["Personal", "Work", "Bills"])
        XCTAssertFalse(store.canCreatePlannerAccount)

        do {
            try await store.createPlannerAccount(named: "Fourth")
            XCTFail("Creating a fourth planner account should fail.")
        } catch PlannerAccountError.limitReached {
            XCTAssertEqual(store.plannerAccounts.map(\.name), ["Personal", "Work", "Bills"])
        }
    }

    func testPlannerAccountCollectionDecodesLegacyAccountsWithoutAvatarMetadata() throws {
        let collection = PlannerAccountCollection.singleAccount(snapshot: DefaultData.emptySnapshot)
        let data = try JSONEncoder().encode(collection)
        let encoded = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(encoded.contains("avatarImageName"))

        let decoded = try JSONDecoder().decode(PlannerAccountCollection.self, from: data)

        XCTAssertNil(decoded.selectedThemePresetId)
        XCTAssertNil(decoded.accounts.first?.avatarImageName)
        XCTAssertNil(decoded.accounts.first?.avatarImageDataBase64)
    }

    func testPlannerAccountAvatarMetadataPersistsAndCanBeRemoved() async throws {
        let store = PlannerStore(
            repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.emptySnapshot),
            accountRepository: InMemoryPlannerAccountRepository()
        )

        await store.load()

        let accountId = try XCTUnwrap(store.activePlannerAccount?.id)
        let avatar = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
            UIColor.black.setFill()
            context.fill(CGRect(x: 20, y: 0, width: 40, height: 40))
        }

        try await store.savePlannerAccountAvatar(accountId: accountId, image: avatar)

        let accountWithAvatar = try XCTUnwrap(store.activePlannerAccount)
        XCTAssertNotNil(accountWithAvatar.avatarImageName)
        XCTAssertNotNil(accountWithAvatar.avatarImageDataBase64)
        XCTAssertNotNil(store.plannerAccountAvatarImage(for: accountWithAvatar))

        try await store.removePlannerAccountAvatar(accountId: accountId)

        XCTAssertNil(store.activePlannerAccount?.avatarImageName)
        XCTAssertNil(store.activePlannerAccount?.avatarImageDataBase64)
    }

    func testPlannerAccountsKeepSnapshotsIsolatedWhenSwitching() async throws {
        let store = PlannerStore(
            repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.emptySnapshot),
            accountRepository: InMemoryPlannerAccountRepository()
        )

        await store.load()
        let personalId = try XCTUnwrap(store.activePlannerAccount?.id)

        store.addPot(
            name: "Personal Pot",
            type: .saving,
            category: nil,
            targetPence: nil,
            color: "#F97316",
            balancePence: 1_500
        )
        try await store.saveCurrentSnapshot()

        try await store.createPlannerAccount(named: "Side")
        let sideId = try XCTUnwrap(store.activePlannerAccount?.id)

        XCTAssertTrue(store.snapshot.pots.isEmpty)

        store.addPot(
            name: "Side Pot",
            type: .saving,
            category: nil,
            targetPence: nil,
            color: "#14B8A6",
            balancePence: 2_500
        )
        try await store.saveCurrentSnapshot()

        try await store.switchPlannerAccount(id: personalId)
        XCTAssertEqual(store.snapshot.pots.map(\.name), ["Personal Pot"])

        try await store.switchPlannerAccount(id: sideId)
        XCTAssertEqual(store.snapshot.pots.map(\.name), ["Side Pot"])
    }

    func testResetAllPlannerDataKeepsSignedInAuthAccountButClearsPlannerCollection() async throws {
        var personalSnapshot = DefaultData.emptySnapshot
        personalSnapshot.pots = [
            Pot(
                id: "personal-pot",
                name: "Personal Pot",
                type: .saving,
                category: nil,
                icon: nil,
                balancePence: 1_500,
                targetPence: 5_000,
                color: "#F97316",
                linkedCreditCardId: nil,
                linkedDebtId: nil,
                archived: false,
                createdAt: "2026-07-01T10:00:00.000Z",
                updatedAt: "2026-07-01T10:00:00.000Z",
                deletedAt: nil
            )
        ]

        let collection = PlannerAccountCollection(
            activeAccountId: "work",
            selectedThemePresetId: AppThemePreset.warmLight.rawValue,
            accounts: [
                PlannerAccount(
                    id: "personal",
                    name: "Personal",
                    color: "#F97316",
                    avatarImageName: "personal-avatar.jpg",
                    avatarImageDataBase64: "encoded-avatar",
                    snapshot: personalSnapshot,
                    createdAt: "2026-07-01T09:00:00.000Z",
                    updatedAt: "2026-07-01T10:00:00.000Z"
                ),
                PlannerAccount(
                    id: "work",
                    name: "Work",
                    color: "#14B8A6",
                    snapshot: DefaultData.basicDataSnapshot,
                    createdAt: "2026-07-02T09:00:00.000Z",
                    updatedAt: "2026-07-02T10:00:00.000Z"
                )
            ],
            updatedAt: "2026-07-02T10:00:00.000Z"
        )
        let store = PlannerStore(
            repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot),
            accountRepository: InMemoryPlannerAccountRepository(seedCollection: collection)
        )

        await store.load()
        XCTAssertTrue(store.accountCollectionForCloudUpload().hasMeaningfulPlannerData)

        let resetCollection = try await store.resetAllPlannerDataKeepingSignedInAccount()

        XCTAssertEqual(resetCollection.accounts.count, 1)
        XCTAssertEqual(resetCollection.activeAccount?.name, "Personal")
        XCTAssertNil(resetCollection.selectedThemePresetId)
        XCTAssertNil(resetCollection.activeAccount?.avatarImageName)
        XCTAssertNil(resetCollection.activeAccount?.avatarImageDataBase64)
        XCTAssertEqual(resetCollection.activeAccount?.snapshot, DefaultData.emptySnapshot)
        XCTAssertFalse(resetCollection.hasMeaningfulPlannerData)
        XCTAssertEqual(store.snapshot, DefaultData.emptySnapshot)
        XCTAssertEqual(store.plannerAccounts.map(\.name), ["Personal"])
    }
}
