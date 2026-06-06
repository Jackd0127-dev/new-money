import Foundation

protocol PlannerRepository: Sendable {
    func loadSnapshot() async throws -> PlannerSnapshot
    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws
    func resetSnapshot() async throws
}

actor FilePlannerRepository: PlannerRepository {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = supportDirectory
            .appendingPathComponent("NewMoneyIPhone", isDirectory: true)
            .appendingPathComponent("planner-snapshot-v1.json")
    }

    func loadSnapshot() async throws -> PlannerSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return DefaultData.emptySnapshot
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PlannerSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    func resetSnapshot() async throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
