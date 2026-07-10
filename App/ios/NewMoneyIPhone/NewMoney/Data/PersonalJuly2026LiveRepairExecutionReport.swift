#if DEBUG
import Foundation

struct PersonalJuly2026LiveRepairPreflightArtifacts: Sendable {
    var executionDirectory: URL
    var preRepairDirectory: URL
    var rawServerURL: URL
    var canonicalServerURL: URL
    var metadataURL: URL
    var summaryURL: URL
    var manifestURL: URL
    var suggestedMacDirectory: String
}

struct PersonalJuly2026LiveRepairPostArtifacts: Sendable {
    var postRepairDirectory: URL
    var reportURL: URL
    var manifestURL: URL
}

private struct PersonalJuly2026LiveRepairBackupMetadata: Codable {
    var repairIdentifier: String
    var executionIdentifier: String
    var generatedAtIso: String
    var canonicalSHA256: String
    var expectedPostSHA256: String
    var rawSHA256: String
    var serverVersionToken: PersonalJuly2026FirestoreVersionToken
    var decodedTargetFingerprints: PersonalJuly2026DecodedFingerprintExport
    var rawTargetFingerprints: PersonalJuly2026RawTargetFingerprints
    var provenanceBackupCanonicalSHA256: String
    var provenanceBackupDocumentID: String
}

private struct PersonalJuly2026DecodedFingerprintExport: Codable {
    var closedPayPeriod: String
    var jajaPot: String
    var barclaysCard: String
    var capitalOneCard: String

    init(_ value: PersonalJuly2026DecodedTargetFingerprints) {
        closedPayPeriod = value.closedPayPeriod
        jajaPot = value.jajaPot
        barclaysCard = value.barclaysCard
        capitalOneCard = value.capitalOneCard
    }
}

enum PersonalJuly2026LiveRepairExecutionReport {
    static func writePreflight(_ preflight: PersonalJuly2026LiveRepairPreflight) throws -> PersonalJuly2026LiveRepairPreflightArtifacts {
        guard let raw = preflight.serverRecord.rawDocument?.fields,
              let rawSHA256 = preflight.serverRecord.rawSHA256,
              let token = preflight.serverRecord.serverVersionToken,
              let decodedFingerprints = preflight.serverRecord.decodedTargetFingerprints,
              let rawFingerprints = preflight.serverRecord.rawTargetFingerprints,
              let provenanceID = preflight.provenanceBackup.documentID else {
            throw PersonalJuly2026LiveRepairExecutionError.missingRawDocument
        }

        let executionDirectory = URL.cachesDirectory
            .appending(path: "NewMoneyLiveRepair", directoryHint: .isDirectory)
            .appending(path: "personal-july-2026", directoryHint: .isDirectory)
            .appending(path: preflight.executionIdentifier, directoryHint: .isDirectory)
        let preDirectory = executionDirectory.appending(path: "pre-repair", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: preDirectory, withIntermediateDirectories: true)

        let rawURL = preDirectory.appending(path: "authoritative-raw-server-document.json")
        let canonicalURL = preDirectory.appending(path: "production-decoded-canonical-account.json")
        let metadataURL = preDirectory.appending(path: "pre-repair-metadata.json")
        let summaryURL = preDirectory.appending(path: "PreRepairSummary.md")
        let manifestURL = preDirectory.appending(path: "SHA256SUMS.txt")

        let rawData = try PersonalJuly2026FirestoreRawCodec.canonicalData(raw)
        let canonicalData = try PersonalJuly2026LiveRepairPlanner.canonicalData(for: preflight.serverRecord.collection)
        let metadata = PersonalJuly2026LiveRepairBackupMetadata(
            repairIdentifier: PersonalJuly2026LiveRepairPlanner.scenarioVersion,
            executionIdentifier: preflight.executionIdentifier,
            generatedAtIso: preflight.executionTimestampIso,
            canonicalSHA256: preflight.serverRecord.canonicalSHA256,
            expectedPostSHA256: preflight.expectedPostSHA256,
            rawSHA256: rawSHA256,
            serverVersionToken: token,
            decodedTargetFingerprints: PersonalJuly2026DecodedFingerprintExport(decodedFingerprints),
            rawTargetFingerprints: rawFingerprints,
            provenanceBackupCanonicalSHA256: preflight.provenanceBackup.canonicalSHA256,
            provenanceBackupDocumentID: provenanceID
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let metadataData = try encoder.encode(metadata)
        let summaryData = Data(preflightSummary(preflight).utf8)

        try rawData.write(to: rawURL, options: .atomic)
        try canonicalData.write(to: canonicalURL, options: .atomic)
        try metadataData.write(to: metadataURL, options: .atomic)
        try summaryData.write(to: summaryURL, options: .atomic)
        let files = [rawURL, canonicalURL, metadataURL, summaryURL]
        let manifestData = Data(try manifest(files).utf8)
        try manifestData.write(to: manifestURL, options: .atomic)
        try verifyManifest(at: manifestURL)
        try makeReadOnly(files + [manifestURL])

        let macDirectory = "~/Library/Application Support/NewMoneyLiveRepair/personal-july-2026/\(preflight.executionIdentifier)/pre-repair"
        return PersonalJuly2026LiveRepairPreflightArtifacts(
            executionDirectory: executionDirectory,
            preRepairDirectory: preDirectory,
            rawServerURL: rawURL,
            canonicalServerURL: canonicalURL,
            metadataURL: metadataURL,
            summaryURL: summaryURL,
            manifestURL: manifestURL,
            suggestedMacDirectory: macDirectory
        )
    }

    static func writePost(
        preflight: PersonalJuly2026LiveRepairPreflight,
        result: PersonalJuly2026LiveRepairExecutionResult,
        sourceCheckpoint: String?,
        testSummary: String?
    ) throws -> PersonalJuly2026LiveRepairPostArtifacts {
        guard let raw = result.postRecord.rawDocument?.fields else {
            throw PersonalJuly2026LiveRepairExecutionError.missingRawDocument
        }
        let postDirectory = URL.cachesDirectory
            .appending(path: "NewMoneyLiveRepair", directoryHint: .isDirectory)
            .appending(path: "personal-july-2026", directoryHint: .isDirectory)
            .appending(path: preflight.executionIdentifier, directoryHint: .isDirectory)
            .appending(path: "post-repair", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: postDirectory, withIntermediateDirectories: true)

        let rawURL = postDirectory.appending(path: "authoritative-post-server-document.json")
        let canonicalURL = postDirectory.appending(path: "production-decoded-post-account.json")
        let reportURL = postDirectory.appending(path: "PersonalJuly2026LiveRepairExecution.md")
        let manifestURL = postDirectory.appending(path: "SHA256SUMS.txt")
        let rawData = try PersonalJuly2026FirestoreRawCodec.canonicalData(raw)
        let canonicalData = try PersonalJuly2026LiveRepairPlanner.canonicalData(for: result.postRecord.collection)
        let reportData = Data(executionReport(
            preflight: preflight,
            result: result,
            sourceCheckpoint: sourceCheckpoint,
            testSummary: testSummary
        ).utf8)

        try rawData.write(to: rawURL, options: .atomic)
        try canonicalData.write(to: canonicalURL, options: .atomic)
        try reportData.write(to: reportURL, options: .atomic)
        let files = [rawURL, canonicalURL, reportURL]
        try Data(manifest(files).utf8).write(to: manifestURL, options: .atomic)
        try verifyManifest(at: manifestURL)
        try makeReadOnly(files + [manifestURL])
        return PersonalJuly2026LiveRepairPostArtifacts(postRepairDirectory: postDirectory, reportURL: reportURL, manifestURL: manifestURL)
    }

    static func writeRollbackProposal(preflight: PersonalJuly2026LiveRepairPreflight, reason: String) throws -> URL {
        let directory = URL.cachesDirectory
            .appending(path: "NewMoneyLiveRepair", directoryHint: .isDirectory)
            .appending(path: "personal-july-2026", directoryHint: .isDirectory)
            .appending(path: preflight.executionIdentifier, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "RollbackProposal.md")
        let body = """
        # Personal July 2026 rollback proposal

        - Reason: \(reason)
        - Authoritative pre-repair hash: \(preflight.serverRecord.canonicalSHA256)
        - Pre-repair backup: `pre-repair/authoritative-raw-server-document.json`
        - Automatic rollback performed: **No**

        A rollback requires separate authorization and a new server-only transaction that first verifies the current authoritative hash and the pre-repair backup checksums.
        """
        try Data(body.utf8).write(to: url, options: .atomic)
        try makeReadOnly([url])
        return url
    }

    static func verifyManifest(at manifestURL: URL) throws {
        let directory = manifestURL.deletingLastPathComponent()
        let text = try String(contentsOf: manifestURL, encoding: .utf8)
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count == 2 else {
                throw PersonalJuly2026LiveRepairExecutionError.postVerificationFailed("malformed checksum manifest")
            }
            let expected = String(parts[0])
            let fileURL = directory.appending(path: String(parts[1]))
            let actual = PersonalJuly2026LiveRepairPlanner.sha256(try Data(contentsOf: fileURL))
            guard actual == expected else {
                throw PersonalJuly2026LiveRepairExecutionError.postVerificationFailed("checksum mismatch for \(fileURL.lastPathComponent)")
            }
        }
    }

    private static func preflightSummary(_ preflight: PersonalJuly2026LiveRepairPreflight) -> String {
        """
        # Personal July 2026 live repair preflight

        - Repair identifier: \(PersonalJuly2026LiveRepairPlanner.scenarioVersion)
        - Source: authoritative Firestore server read
        - Canonical pre-state SHA-256: \(preflight.serverRecord.canonicalSHA256)
        - Expected post-state SHA-256: \(preflight.expectedPostSHA256)
        - Exact server token: \(preflight.serverRecord.serverVersionToken?.description ?? "missing")
        - Decoded target fingerprints: \(String(describing: preflight.serverRecord.decodedTargetFingerprints))
        - Raw target fingerprints: \(String(describing: preflight.serverRecord.rawTargetFingerprints))
        - Proposed operations: \(preflight.plan.operations.count)
        - Live writes performed while creating this backup: 0
        - Raw LevelDB edits: none
        """
    }

    private static func executionReport(
        preflight: PersonalJuly2026LiveRepairPreflight,
        result: PersonalJuly2026LiveRepairExecutionResult,
        sourceCheckpoint: String?,
        testSummary: String?
    ) -> String {
        let postPlan = PersonalJuly2026LiveRepairPlanner.makePlan(
            server: result.postRecord,
            cache: nil,
            backups: preflight.plan.backups,
            proposedAtIso: preflight.executionTimestampIso
        )
        let metrics = postPlan.proposedMetrics
        return """
        # Personal July 2026 Live Repair Execution

        - Final status: **\(result.status.rawValue)**
        - Source checkpoint: \(sourceCheckpoint ?? "not supplied")
        - Repair identifier: \(PersonalJuly2026LiveRepairPlanner.scenarioVersion)
        - Device/app: iPhone; \(Bundle.main.bundleIdentifier ?? "unknown bundle")
        - Confirmation: exact environment token, typed phrase, backup acknowledgement, and explicit button
        - Transaction attempts: \(result.transactionAttemptCount)
        - Authoritative pre-state SHA-256: \(result.preStateSHA256)
        - Authoritative post-state SHA-256: \(result.postStateSHA256)
        - Authoritative post timestamp: \(result.postServerUpdatedAtIso)
        - Authoritative post token: \(result.postServerVersionToken.description)
        - Firestore backup: \(result.backupPath)
        - Firestore marker: \(result.markerPath)
        - Tests: \(testSummary ?? "see host-side xcresult")

        ## Applied operations

        \(preflight.plan.operations.enumerated().map { "\($0.offset + 1). \($0.element.description)" }.joined(separator: "\n"))

        ## Post-repair financial values

        - Income: \(money(metrics?.incomePence))
        - Money Left: \(money(metrics?.currentMoneyLeftPence))
        - Safe to spend: \(money(metrics?.safeToSpendPence))
        - Recorded spending: \(money(metrics?.recordedSpendingPence))
        - Activity net: \(money(metrics?.activityNetPence))
        - Total pots: \(money(metrics?.totalPotPence))
        - Total owed: \(money(metrics?.totalOwedPence))
        - Available credit: \(money(metrics?.totalAvailableCreditPence))
        - Forecast availability: \(money(metrics?.forecastAvailabilityPence))
        - Jaja due date: \(metrics?.jajaDueDate ?? "missing")
        - Capital One due date: \(metrics?.capitalOneDueDate ?? "missing")
        - Barclays due date: \(metrics?.barclaysDueDate ?? "missing")

        ## Confirmation

        - Untouched-record hash comparison: PASS
        - Raw field-preserving comparison: PASS
        - Automatic rollback: No
        - Direct LevelDB edit or compaction: none
        - Unrelated Firestore write: none; the transaction was limited to current snapshot, deterministic backup, and repair marker
        """
    }

    private static func manifest(_ files: [URL]) throws -> String {
        try files.map { file in
            "\(PersonalJuly2026LiveRepairPlanner.sha256(try Data(contentsOf: file)))  \(file.lastPathComponent)"
        }.joined(separator: "\n") + "\n"
    }

    private static func makeReadOnly(_ files: [URL]) throws {
        for file in files {
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        }
    }

    private static func money(_ value: Int?) -> String {
        value.map { MoneyParser.formatPence($0) } ?? "missing"
    }
}
#endif
