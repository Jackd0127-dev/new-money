import Foundation

/// Owns one ordered sync stream. A checkpoint is never advanced ahead of durable local data.
@MainActor
final class PlannerSyncCoordinator {
    private let service: CloudSyncService
    private let recovery: PlannerSyncRecoveryRepository
    private var activeUserID: String?
    private var generation = 0
    private var tail: Task<Void, Never>?

    init(service: CloudSyncService, recovery: PlannerSyncRecoveryRepository = FilePlannerSyncRecoveryRepository()) {
        self.service = service
        self.recovery = recovery
    }

    func activate(userID: String) {
        generation &+= 1
        activeUserID = userID
    }

    /// Fence new work immediately, then let an already-issued conditional write finish before reset/sign-out.
    func suspendAndWait() async {
        generation &+= 1
        activeUserID = nil
        await tail?.value
    }

    func synchronize(local: PlannerAccountCollection, hadPersistedLocalData: Bool, user: AuthUser) async throws -> PlannerSyncResult {
        let token = generation
        return try await serialized {
            try self.check(user: user, generation: token)
            try await self.initializeLocalState(local: local, hadPersistedLocalData: hadPersistedLocalData, user: user)
            let checkpoint = try await self.recovery.loadCheckpoint(userID: user.uid)
            let ownerID = try await self.recovery.localOwnerID()
            let cloud = try await self.service.readAuthoritative(for: user)
            try self.check(user: user, generation: token)
            let localFingerprint = try PlannerCloudFingerprint.collection(local)

            if let checkpoint, let conflictID = checkpoint.conflictID {
                guard let conflict = try await self.recovery.conflict(id: conflictID, userID: user.uid) else {
                    throw PlannerSyncRecoveryError.missingConflict
                }
                try self.check(user: user, generation: token)
                if let resumed = try await self.resumeLocalChoice(conflict: conflict, checkpoint: checkpoint,
                    cloud: cloud, latestLocal: local, user: user, generation: token) {
                    return resumed
                }
                if conflict.local == local && conflict.cloud.revision == cloud.revision {
                    return .conflict(conflict)
                }
                return try await self.preserveConflict(local: local, cloud: cloud, checkpoint: checkpoint, user: user,
                    ownership: conflict.requiresOwnershipConfirmation, generation: token)
            }

            if let ownerID, ownerID != user.uid {
                return try await self.preserveConflict(local: local, cloud: cloud, checkpoint: checkpoint, user: user,
                    ownership: true, generation: token)
            }

            if let cloudCollection = cloud.collection,
               try PlannerCloudFingerprint.collection(cloudCollection) == localFingerprint {
                try await self.acknowledge(localFingerprint: localFingerprint, cloud: cloud, user: user, generation: token)
                return .acknowledged(fingerprint: localFingerprint)
            }

            guard var checkpoint else {
                guard !hadPersistedLocalData, ownerID == nil else {
                    return try await self.preserveConflict(local: local, cloud: cloud, checkpoint: nil, user: user,
                        ownership: true, generation: token)
                }
                if let collection = cloud.collection {
                    return .replaceLocal(collection: collection, cloud: cloud)
                }
                try await self.acknowledge(localFingerprint: localFingerprint, cloud: cloud, user: user, generation: token)
                return .acknowledged(fingerprint: localFingerprint)
            }

            // Recover a successful write whose acknowledgement was interrupted by a crash/network error.
            if let pending = checkpoint.pendingUpload, let cloudCollection = cloud.collection,
               try PlannerCloudFingerprint.collection(pending.collection) == PlannerCloudFingerprint.collection(cloudCollection) {
                checkpoint.baselineRevision = cloud.revision
                checkpoint.acknowledgedLocalFingerprint = try PlannerCloudFingerprint.collection(pending.collection)
                checkpoint.pendingUpload = nil
                try await self.recovery.saveCheckpoint(checkpoint)
                try self.check(user: user, generation: token)
            }

            guard let baseline = checkpoint.baselineRevision else {
                if let initial = checkpoint.initialLocalFingerprint, ownerID == user.uid {
                    if let collection = cloud.collection, initial == localFingerprint {
                        return .replaceLocal(collection: collection, cloud: cloud)
                    }
                    if cloud.revision == .missing {
                        if initial == localFingerprint {
                            try await self.acknowledge(localFingerprint: localFingerprint, cloud: cloud, user: user, generation: token)
                            return .acknowledged(fingerprint: localFingerprint)
                        }
                        let pending = PlannerPendingUpload(collection: local, expectedRevision: .missing)
                        checkpoint.baselineRevision = .missing
                        checkpoint.pendingUpload = pending
                        try await self.recovery.saveCheckpoint(checkpoint)
                        try self.check(user: user, generation: token)
                        return try await self.upload(pending, latestLocal: local, checkpoint: checkpoint, user: user, generation: token)
                    }
                }
                return try await self.preserveConflict(local: local, cloud: cloud, checkpoint: checkpoint, user: user,
                    ownership: ownerID == nil, generation: token)
            }

            if let pending = checkpoint.pendingUpload {
                guard cloud.revision == pending.expectedRevision else {
                    return try await self.preserveConflict(local: local, cloud: cloud, checkpoint: checkpoint, user: user,
                        ownership: false, generation: token)
                }
                return try await self.upload(pending, latestLocal: local, checkpoint: checkpoint, user: user, generation: token)
            }

            let isDirty = checkpoint.acknowledgedLocalFingerprint != localFingerprint
            if cloud.revision != baseline {
                if !isDirty, let collection = cloud.collection {
                    // Preserve the outgoing version even on an uncontested download.
                    _ = try await self.archive(local: local, cloud: cloud, checkpoint: checkpoint, user: user, ownership: false)
                    try self.check(user: user, generation: token)
                    return .replaceLocal(collection: collection, cloud: cloud)
                }
                return try await self.preserveConflict(local: local, cloud: cloud, checkpoint: checkpoint, user: user,
                    ownership: false, generation: token)
            }

            guard isDirty else { return .acknowledged(fingerprint: localFingerprint) }
            let pending = PlannerPendingUpload(collection: local, expectedRevision: baseline)
            checkpoint.pendingUpload = pending
            try await self.recovery.saveCheckpoint(checkpoint)
            try self.check(user: user, generation: token)
            return try await self.upload(pending, latestLocal: local, checkpoint: checkpoint, user: user, generation: token)
        }
    }

    /// Establish fresh-install provenance before a network outage can leave newly entered data ambiguous.
    func initializeLocalState(local: PlannerAccountCollection, hadPersistedLocalData: Bool, user: AuthUser) async throws {
        let token = generation
        try check(user: user, generation: token)
        let existing = try await recovery.loadCheckpoint(userID: user.uid)
        let owner = try await recovery.localOwnerID()
        try check(user: user, generation: token)
        if owner == nil, existing?.initialLocalFingerprint != nil {
            try await recovery.setLocalOwnerID(user.uid)
        } else if !hadPersistedLocalData, existing == nil, owner == nil {
            let checkpoint = PlannerSyncCheckpoint(ownerUID: user.uid,
                initialLocalFingerprint: try PlannerCloudFingerprint.collection(local))
            try await recovery.saveCheckpoint(checkpoint)
            try check(user: user, generation: token)
            try await recovery.setLocalOwnerID(user.uid)
        }
        try check(user: user, generation: token)
    }

    /// Unknown legacy data and another account's cached data must stay gated when the server is unavailable.
    func hasVerifiedLocalOwner(user: AuthUser) async throws -> Bool {
        let token = generation
        try check(user: user, generation: token)
        let owner = try await recovery.localOwnerID()
        try check(user: user, generation: token)
        return owner == user.uid
    }

    func chooseLocal(conflictID: String, currentLocal: PlannerAccountCollection, user: AuthUser) async throws -> PlannerSyncResult {
        let token = generation
        return try await serialized {
            let (conflict, checkpoint, cloud) = try await self.reviewedConflict(id: conflictID, local: currentLocal, user: user, generation: token)
            if let resumed = try await self.resumeLocalChoice(conflict: conflict, checkpoint: checkpoint,
                cloud: cloud, latestLocal: currentLocal, user: user, generation: token) {
                return resumed
            }
            if conflict.local != currentLocal || conflict.cloud.revision != cloud.revision {
                return try await self.preserveConflict(local: currentLocal, cloud: cloud, checkpoint: checkpoint, user: user,
                    ownership: conflict.requiresOwnershipConfirmation, generation: token)
            }
            let pending = PlannerPendingUpload(collection: conflict.local, expectedRevision: cloud.revision,
                resolutionConflictID: conflict.id)
            var updated = checkpoint
            updated.baselineRevision = cloud.revision
            updated.pendingUpload = pending
            // Retain the review until acknowledgement; a failed attempt reuses this exact durable choice.
            try await self.recovery.saveCheckpoint(updated)
            try await self.recovery.setLocalOwnerID(user.uid)
            try self.check(user: user, generation: token)
            return try await self.upload(pending, latestLocal: currentLocal, checkpoint: updated, user: user, generation: token)
        }
    }

    func chooseCloud(conflictID: String, currentLocal: PlannerAccountCollection, user: AuthUser) async throws -> PlannerSyncResult {
        let token = generation
        return try await serialized {
            let (conflict, checkpoint, cloud) = try await self.reviewedConflict(id: conflictID, local: currentLocal, user: user, generation: token)
            if conflict.local != currentLocal || conflict.cloud.revision != cloud.revision {
                return try await self.preserveConflict(local: currentLocal, cloud: cloud, checkpoint: checkpoint, user: user,
                    ownership: conflict.requiresOwnershipConfirmation, generation: token)
            }
            let replacement = cloud.collection ?? PlannerAccountCollection.singleAccount(snapshot: DefaultData.emptySnapshot)
            return .replaceLocal(collection: replacement, cloud: cloud)
        }
    }

    /// Call only after the chosen/downloaded collection has been saved locally. Migrations remain dirty.
    func acknowledgeDownload(originalCollection: PlannerAccountCollection, cloud: PlannerCloudRead, user: AuthUser) async throws {
        let token = generation
        _ = try await serialized {
            try self.check(user: user, generation: token)
            try await self.acknowledge(localFingerprint: PlannerCloudFingerprint.collection(originalCollection), cloud: cloud,
                user: user, generation: token)
            return true
        }
    }

    func reset(to collection: PlannerAccountCollection, user: AuthUser) async throws -> PlannerCloudRead {
        let token = generation
        return try await serialized {
            try self.check(user: user, generation: token)
            try await self.service.resetAccountCollection(collection, for: user)
            try self.check(user: user, generation: token)
            let cloud = try await self.service.readAuthoritative(for: user)
            try self.check(user: user, generation: token)
            guard cloud.collection == collection else { throw PlannerSyncRecoveryError.invalidPayload }
            // The session persists the local reset before acknowledging this new baseline.
            return cloud
        }
    }

    private func upload(_ pending: PlannerPendingUpload, latestLocal: PlannerAccountCollection, checkpoint: PlannerSyncCheckpoint,
                        user: AuthUser, generation token: Int) async throws -> PlannerSyncResult {
        try check(user: user, generation: token)
        switch try await service.compareAndSet(pending, for: user) {
        case let .committed(cloud):
            try check(user: user, generation: token)
            let fingerprint = try PlannerCloudFingerprint.collection(pending.collection)
            try await acknowledge(localFingerprint: fingerprint, cloud: cloud, user: user, generation: token)
            return .acknowledged(fingerprint: fingerprint)
        case let .conflict(cloud):
            try check(user: user, generation: token)
            return try await preserveConflict(local: latestLocal, cloud: cloud, checkpoint: checkpoint, user: user,
                ownership: false, generation: token)
        }
    }

    private func resumeLocalChoice(conflict: PlannerSyncConflict, checkpoint: PlannerSyncCheckpoint, cloud: PlannerCloudRead,
                                   latestLocal: PlannerAccountCollection, user: AuthUser, generation token: Int) async throws -> PlannerSyncResult? {
        guard let pending = checkpoint.pendingUpload, pending.resolutionConflictID == conflict.id else { return nil }
        let fingerprint = try PlannerCloudFingerprint.collection(pending.collection)
        if let collection = cloud.collection, try PlannerCloudFingerprint.collection(collection) == fingerprint {
            try await acknowledge(localFingerprint: fingerprint, cloud: cloud, user: user, generation: token)
            return .acknowledged(fingerprint: fingerprint)
        }
        guard cloud.revision == pending.expectedRevision else { return nil }
        return try await upload(pending, latestLocal: latestLocal, checkpoint: checkpoint, user: user, generation: token)
    }

    private func acknowledge(localFingerprint: String, cloud: PlannerCloudRead, user: AuthUser, generation token: Int) async throws {
        try check(user: user, generation: token)
        let checkpoint = PlannerSyncCheckpoint(ownerUID: user.uid, baselineRevision: cloud.revision,
            acknowledgedLocalFingerprint: localFingerprint, pendingUpload: nil, conflictID: nil)
        try await recovery.saveCheckpoint(checkpoint)
        try check(user: user, generation: token)
        try await recovery.setLocalOwnerID(user.uid)
        try check(user: user, generation: token)
    }

    private func reviewedConflict(id: String, local: PlannerAccountCollection, user: AuthUser, generation token: Int)
        async throws -> (PlannerSyncConflict, PlannerSyncCheckpoint, PlannerCloudRead) {
        try check(user: user, generation: token)
        guard let checkpoint = try await recovery.loadCheckpoint(userID: user.uid), checkpoint.conflictID == id,
              let conflict = try await recovery.conflict(id: id, userID: user.uid) else {
            throw PlannerSyncRecoveryError.missingConflict
        }
        let cloud = try await service.readAuthoritative(for: user)
        try check(user: user, generation: token)
        return (conflict, checkpoint, cloud)
    }

    private func archive(local: PlannerAccountCollection, cloud: PlannerCloudRead, checkpoint: PlannerSyncCheckpoint?,
                         user: AuthUser, ownership: Bool) async throws -> PlannerSyncConflict {
        let conflict = PlannerSyncConflict(id: UUID().uuidString.lowercased(), ownerUID: user.uid,
            capturedAtIso: DateUtilities.nowIsoString(), local: local, cloud: cloud,
            baselineRevision: checkpoint?.baselineRevision, requiresOwnershipConfirmation: ownership)
        try await recovery.archive(conflict)
        return conflict
    }

    private func preserveConflict(local: PlannerAccountCollection, cloud: PlannerCloudRead, checkpoint: PlannerSyncCheckpoint?,
                                  user: AuthUser, ownership: Bool, generation token: Int) async throws -> PlannerSyncResult {
        try check(user: user, generation: token)
        let conflict = try await archive(local: local, cloud: cloud, checkpoint: checkpoint, user: user, ownership: ownership)
        try check(user: user, generation: token)
        var updated = checkpoint ?? PlannerSyncCheckpoint(ownerUID: user.uid)
        updated.conflictID = conflict.id
        try await recovery.saveCheckpoint(updated)
        try check(user: user, generation: token)
        return .conflict(conflict)
    }

    private func check(user: AuthUser, generation token: Int) throws {
        guard activeUserID == user.uid, generation == token else { throw PlannerSyncRecoveryError.staleSession }
    }

    private func serialized<T: Sendable>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            return try await operation()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}
