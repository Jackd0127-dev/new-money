import SwiftUI

/// Shown before the planner whenever ownership or conflicting edits need review.
struct SyncRecoveryView: View {
    @ObservedObject var store: PlannerStore
    @ObservedObject var session: FirebaseAuthSession
    let conflict: PlannerSyncConflict
    @State private var choice: RecoveryChoice?
    @State private var isResolving = false
    @State private var showSignOut = false

    private enum RecoveryChoice: String, Identifiable {
        case local, cloud
        var id: String { rawValue }
    }

    private var localTitle: String {
        conflict.requiresOwnershipConfirmation ? "Import this iPhone data" : "Use this iPhone copy"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Choose your planner copy")
                        .font(.title2.bold())
                    Text(conflict.requiresOwnershipConfirmation
                         ? "This iPhone has planner data whose owner could not be confirmed. Import it only if it belongs to you."
                         : "This iPhone and the cloud have different edits. Both copies are preserved on this iPhone while you choose.")
                        .fixedSize(horizontal: false, vertical: true)

                    if !conflict.requiresOwnershipConfirmation {
                        Text("iPhone: \(conflict.local.accounts.count) planner accounts\nCloud: \(conflict.cloud.collection?.accounts.count ?? 0) planner accounts")
                            .font(.subheadline)
                        Text("iPhone saved: \(conflict.local.updatedAt)\nCloud saved: \(conflict.cloud.updatedAtIso ?? "Unknown")")
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let error = session.errorMessage {
                        Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                    }

                    Button(localTitle) { choice = .local }
                        .buttonStyle(.borderedProminent)
                    Button(conflict.cloud.collection == nil ? "Start an empty planner" : "Use the cloud copy") { choice = .cloud }
                        .buttonStyle(.bordered)
                    if case .failed = session.syncStatus {
                        Button("Retry sync") {
                            Task { await session.retryPlannerSync(store: store) }
                        }
                    }
                    Text("Neither choice deletes the saved recovery copies.")
                        .font(.footnote)
                    Button("Sign out") { showSignOut = true }
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color.black)
            .foregroundStyle(.white)
            .disabled(isResolving)
            .navigationTitle("Sync recovery")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(choice == .local ? localTitle : "Replace this iPhone copy?", isPresented: Binding(
            get: { choice != nil }, set: { if !$0 { choice = nil } }
        ), titleVisibility: .visible) {
            if let choice {
                Button(choice == .local ? localTitle : "Use cloud data") {
                    isResolving = true
                    Task {
                        if choice == .local { await session.chooseLocalSyncConflict(store: store) }
                        else { await session.chooseCloudSyncConflict(store: store) }
                        isResolving = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(choice == .local
                 ? "This will upload the iPhone copy to your signed-in account. Only continue if this data belongs to you."
                 : "This will replace the active iPhone copy with your cloud data. The previous copy remains in local recovery storage.")
        }
        .alert("Sign out?", isPresented: $showSignOut) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text("Both planner copies remain preserved on this iPhone.")
        }
        .accessibilityIdentifier("planner-sync-recovery")
    }
}

struct PlannerSaveStatusView: View {
    @ObservedObject var store: PlannerStore
    @ObservedObject var session: FirebaseAuthSession

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if store.saveState == .failed || isSyncFailed {
                Button("Retry") {
                    Task {
                        await store.retrySaving()
                        if store.saveState == .saved { await session.retryPlannerSync(store: store) }
                    }
                }
                .font(.footnote.bold())
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .foregroundStyle(AppTheme.Colors.primaryText)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(AppTheme.Colors.appBackground)
        .accessibilityIdentifier("planner-save-status")
    }

    private var title: String {
        switch store.saveState {
        case .failed: "Changes could not be saved on this iPhone"
        case .pending: "Saving on this iPhone"
        case .saved: session.syncStatus.title
        }
    }

    private var isSyncFailed: Bool {
        if case .failed = session.syncStatus { return true }
        return false
    }
}
