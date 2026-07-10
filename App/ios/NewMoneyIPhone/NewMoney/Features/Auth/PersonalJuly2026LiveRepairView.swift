#if DEBUG
import SwiftUI

enum PersonalJuly2026LiveRepairLaunchProfile {
    enum Mode: String {
        case dryRun = "dry-run"
        case execute
    }

    static let scenarioKey = "NEWMONEY_LIVE_REPAIR"
    static let modeKey = "NEWMONEY_LIVE_REPAIR_MODE"
    static let checkpointKey = "NEWMONEY_LIVE_REPAIR_CHECKPOINT"
    static let expectedSHA256Key = "NEWMONEY_LIVE_REPAIR_EXPECTED_SHA256"
    static let confirmationKey = "NEWMONEY_LIVE_REPAIR_CONFIRMATION"
    static let testSummaryKey = "NEWMONEY_LIVE_REPAIR_TEST_SUMMARY"
    static let expectedScenario = "personal-july-2026-v1"
    static let expectedConfirmation = "I_AUTHORIZE_EXACTLY_FOUR_PERSONAL_JULY_2026_CHANGES"
    static let typedConfirmation = "EXECUTE 4-RECORD LIVE REPAIR"

    static var requestedMode: Mode? {
        requestedMode(environment: ProcessInfo.processInfo.environment)
    }

    static func requestedMode(environment: [String: String]) -> Mode? {
        guard environment[scenarioKey] == expectedScenario else { return nil }
        return environment[modeKey].flatMap(Mode.init)
    }

    static var isActive: Bool {
        requestedMode != nil
    }

    static var executeEnvironmentIsValid: Bool {
        executeEnvironmentIsValid(environment: ProcessInfo.processInfo.environment)
    }

    static func executeEnvironmentIsValid(environment: [String: String]) -> Bool {
        requestedMode(environment: environment) == .execute &&
            environment[expectedSHA256Key] == PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256 &&
            environment[confirmationKey] == expectedConfirmation
    }

    static func executionButtonIsEnabled(
        environment: [String: String],
        preflightReady: Bool,
        typedPhrase: String,
        backupManifestVerified: Bool
    ) -> Bool {
        executeEnvironmentIsValid(environment: environment) &&
            preflightReady &&
            backupManifestVerified &&
            typedPhrase == typedConfirmation
    }
}

@MainActor
final class PersonalJuly2026LiveRepairRunner: ObservableObject {
    enum State: Equatable {
        case idle
        case readingServer
        case readingCache
        case readingBackups
        case planning
        case completed(reportPath: String, isValid: Bool, recommendation: String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    private var didRun = false

    func runIfNeeded() async {
        guard PersonalJuly2026LiveRepairLaunchProfile.requestedMode == .dryRun, !didRun else { return }
        didRun = true

        do {
            let authService = FirebaseAuthService()
            guard let user = await authService.currentUser() else {
                state = .failed("Dry-run aborted: no signed-in Firebase user is available on this app installation.")
                return
            }

            let reader = FirebasePersonalJuly2026LiveRepairReader()
            state = .readingServer
            state = .planning
            let plan = try await PersonalJuly2026LiveRepairCoordinator.readAndPlan(reader: reader, userID: user.uid)
            let artifacts = try PersonalJuly2026LiveRepairReport.write(
                plan: plan,
                checkpointIdentifier: ProcessInfo.processInfo.environment[PersonalJuly2026LiveRepairLaunchProfile.checkpointKey],
                deviceDescription: Self.deviceDescription
            )
            state = .completed(reportPath: artifacts.reportURL.path, isValid: plan.isValid, recommendation: plan.recommendation)
        } catch {
            state = .failed("Dry-run aborted before any repair proposal: \(error.localizedDescription)")
        }
    }

    private static var deviceDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(UIDevice.current.name); New Money \(version) (\(build)); \(Bundle.main.bundleIdentifier ?? "unknown bundle")"
    }
}

struct PersonalJuly2026LiveRepairView: View {
    var body: some View {
        if PersonalJuly2026LiveRepairLaunchProfile.requestedMode == .execute {
            PersonalJuly2026LiveRepairExecuteView()
        } else {
            PersonalJuly2026LiveRepairDryRunView()
        }
    }
}

private struct PersonalJuly2026LiveRepairDryRunView: View {
    @StateObject private var runner = PersonalJuly2026LiveRepairRunner()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Personal July 2026", systemImage: "stethoscope")
                        .font(.title.bold())
                    Text("Authoritative live-repair dry run")
                        .font(.headline)
                    Text("This diagnostic can read the signed-in Firestore account and write private report files to this app’s cache. It has no live repair or cloud-write path.")
                        .foregroundStyle(.secondary)
                    statusContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Repair dry run")
        }
        .task {
            await runner.runIfNeeded()
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch runner.state {
        case .idle:
            Label("Waiting to start", systemImage: "clock")
        case .readingServer:
            progress("Reading authoritative server document")
        case .readingCache:
            progress("Comparing Firebase cache")
        case .readingBackups:
            progress("Reading server provenance backups")
        case .planning:
            progress("Validating cloned proposed state")
        case let .completed(reportPath, isValid, recommendation):
            Label(isValid ? "Dry run passed" : "Dry run found blocking failures", systemImage: isValid ? "checkmark.shield" : "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(isValid ? .green : .orange)
            Text(recommendation)
            Text(reportPath)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .accessibilityLabel("Report path: \(reportPath)")
        case let .failed(message):
            Label("Dry run aborted", systemImage: "xmark.octagon")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .textSelection(.enabled)
        }
    }

    private func progress(_ title: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(title)
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private final class PersonalJuly2026LiveRepairExecuteRunner: ObservableObject {
    enum State {
        case idle
        case blocked(String)
        case preparing
        case ready
        case executing
        case completed(PersonalJuly2026LiveRepairExecutionResult, PersonalJuly2026LiveRepairPostArtifacts)
        case failed(String, rollbackProposalPath: String?)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var operationDescriptions: [String] = []
    @Published private(set) var preStateSHA256 = ""
    @Published private(set) var expectedPostSHA256 = ""
    @Published private(set) var exactServerToken = ""
    @Published private(set) var deviceBackupPath = ""
    @Published private(set) var suggestedMacBackupPath = ""
    private var didPrepare = false
    private var preflight: PersonalJuly2026LiveRepairPreflight?
    private var preflightArtifacts: PersonalJuly2026LiveRepairPreflightArtifacts?

    var isReady: Bool {
        if case .ready = state { true } else { false }
    }

    func prepareIfNeeded() async {
        guard !didPrepare else { return }
        didPrepare = true
        guard PersonalJuly2026LiveRepairLaunchProfile.executeEnvironmentIsValid else {
            state = .blocked("Execute mode is blocked because its exact expected hash or confirmation environment token is missing.")
            return
        }
        state = .preparing
        do {
            let authService = FirebaseAuthService()
            guard let user = await authService.currentUser() else {
                state = .blocked("No signed-in Firebase account is available on this app installation.")
                return
            }
            let reader = FirebasePersonalJuly2026LiveRepairReader()
            let prepared = try await PersonalJuly2026LiveRepairExecutionCoordinator.prepare(reader: reader, userID: user.uid)
            let artifacts = try PersonalJuly2026LiveRepairExecutionReport.writePreflight(prepared)
            try PersonalJuly2026LiveRepairExecutionReport.verifyManifest(at: artifacts.manifestURL)
            preflight = prepared
            preflightArtifacts = artifacts
            operationDescriptions = prepared.plan.operations.map(\.description)
            preStateSHA256 = prepared.serverRecord.canonicalSHA256
            expectedPostSHA256 = prepared.expectedPostSHA256
            exactServerToken = prepared.serverRecord.serverVersionToken?.description ?? "missing"
            deviceBackupPath = artifacts.preRepairDirectory.path
            suggestedMacBackupPath = artifacts.suggestedMacDirectory
            state = .ready
        } catch {
            state = .failed("Preflight aborted with zero writes: \(error.localizedDescription)", rollbackProposalPath: nil)
        }
    }

    func execute(typedConfirmation: String, backupAcknowledged: Bool) async {
        guard isReady,
              typedConfirmation == PersonalJuly2026LiveRepairLaunchProfile.typedConfirmation,
              backupAcknowledged,
              let preflight,
              let preflightArtifacts else {
            state = .failed(PersonalJuly2026LiveRepairExecutionError.confirmationGateFailed.localizedDescription, rollbackProposalPath: nil)
            return
        }
        do {
            try PersonalJuly2026LiveRepairExecutionReport.verifyManifest(at: preflightArtifacts.manifestURL)
            state = .executing
            let executor = FirebasePersonalJuly2026LiveRepairExecutor()
            let result = try await executor.execute(preflight)
            let postArtifacts = try PersonalJuly2026LiveRepairExecutionReport.writePost(
                preflight: preflight,
                result: result,
                sourceCheckpoint: ProcessInfo.processInfo.environment[PersonalJuly2026LiveRepairLaunchProfile.checkpointKey],
                testSummary: ProcessInfo.processInfo.environment[PersonalJuly2026LiveRepairLaunchProfile.testSummaryKey]
            )
            state = .completed(result, postArtifacts)
        } catch {
            let rollbackPath: String?
            if case PersonalJuly2026LiveRepairExecutionError.postVerificationFailed = error {
                rollbackPath = try? PersonalJuly2026LiveRepairExecutionReport.writeRollbackProposal(
                    preflight: preflight,
                    reason: error.localizedDescription
                ).path
            } else {
                rollbackPath = nil
            }
            state = .failed("Execution stopped: \(error.localizedDescription)", rollbackProposalPath: rollbackPath)
        }
    }
}

private struct PersonalJuly2026LiveRepairExecuteView: View {
    @StateObject private var runner = PersonalJuly2026LiveRepairExecuteRunner()
    @State private var typedConfirmation = ""
    @State private var backupAcknowledged = false

    private var canExecute: Bool {
        PersonalJuly2026LiveRepairLaunchProfile.executionButtonIsEnabled(
            environment: ProcessInfo.processInfo.environment,
            preflightReady: runner.isReady,
            typedPhrase: typedConfirmation,
            backupManifestVerified: backupAcknowledged
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Live Firestore repair", systemImage: "exclamationmark.shield")
                        .font(.title.bold())
                        .foregroundStyle(.red)
                    Text("Personal July 2026 — exactly four approved logical changes")
                        .font(.headline)
                    Text("This screen is isolated from PlannerStore and normal cloud sync. The button below writes to the signed-in live Firestore account only after every preflight and backup gate passes.")
                        .foregroundStyle(.secondary)
                    statusContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Live repair")
        }
        .task {
            await runner.prepareIfNeeded()
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch runner.state {
        case .idle, .preparing:
            progress("Reading server and building a read-only pre-repair backup")
        case let .blocked(message):
            failure(title: "Execution gate blocked", message: message, rollbackPath: nil)
        case .ready:
            readyContent
        case .executing:
            progress("Executing one authoritative Firestore transaction")
        case let .completed(result, artifacts):
            Label(result.status == .committed ? "Live repair verified" : "Repair already applied", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("Post-state SHA-256: \(result.postStateSHA256)")
                .font(.body.monospaced())
                .textSelection(.enabled)
            Text("Report: \(artifacts.reportURL.path)")
                .font(.body.monospaced())
                .textSelection(.enabled)
        case let .failed(message, rollbackPath):
            failure(title: "Repair stopped", message: message, rollbackPath: rollbackPath)
        }
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("All runtime preconditions passed", systemImage: "checkmark.shield")
                .font(.headline)
                .foregroundStyle(.green)
            ForEach(Array(runner.operationDescriptions.enumerated()), id: \.offset) { index, operation in
                Text("\(index + 1). \(operation)")
            }
            LabeledContent("Current server hash") {
                Text(runner.preStateSHA256).font(.body.monospaced()).textSelection(.enabled)
            }
            LabeledContent("Expected post hash") {
                Text(runner.expectedPostSHA256).font(.body.monospaced()).textSelection(.enabled)
            }
            LabeledContent("Exact server token") {
                Text(runner.exactServerToken).font(.body.monospaced()).textSelection(.enabled)
            }
            Text("Device backup: \(runner.deviceBackupPath)")
                .font(.body.monospaced())
                .textSelection(.enabled)
            Text("Required Mac copy: \(runner.suggestedMacBackupPath)")
                .font(.body.monospaced())
                .textSelection(.enabled)
            TextField("Type exact confirmation phrase", text: $typedConfirmation)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .accessibilityIdentifier("live-repair-confirmation-phrase")
            Text("Required phrase: \(PersonalJuly2026LiveRepairLaunchProfile.typedConfirmation)")
                .foregroundStyle(.secondary)
            Toggle("I verified the read-only Mac backup and its SHA-256 manifest", isOn: $backupAcknowledged)
                .accessibilityIdentifier("live-repair-backup-acknowledgement")
            Button("Execute 4-record live repair", systemImage: "exclamationmark.shield.fill") {
                Task {
                    await runner.execute(typedConfirmation: typedConfirmation, backupAcknowledged: backupAcknowledged)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!canExecute)
            .frame(minHeight: 44)
            .accessibilityIdentifier("execute-four-record-live-repair")
        }
    }

    private func progress(_ title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            ProgressView()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func failure(title: String, message: String, rollbackPath: String?) -> some View {
        Label(title, systemImage: "xmark.octagon.fill")
            .font(.headline)
            .foregroundStyle(.red)
        Text(message).textSelection(.enabled)
        if let rollbackPath {
            Text("Rollback proposal only; no rollback executed: \(rollbackPath)")
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }
}
#endif
