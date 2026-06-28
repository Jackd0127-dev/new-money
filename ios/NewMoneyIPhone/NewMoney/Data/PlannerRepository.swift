import Foundation

protocol PlannerRepository: Sendable {
    func loadSnapshot() async throws -> PlannerSnapshot
    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws
    func resetSnapshot() async throws
}

enum PlannerLaunchProfile {
    static let fixtureEnvironmentKey = "NEWMONEY_PLANNER_FIXTURE"
    static let basicDataFixtureValue = "basic-data"
    static let complexStressFixtureValue = "complex-stress-sep-oct-2026"
    static let complexStressJanMar2027FixtureValue = "complex-stress-jan-mar-2027"
    static let groupedComplexJanMar2027FixtureValue = "grouped-complex-jan-mar-2027"

    static func repository(environment: [String: String] = ProcessInfo.processInfo.environment) -> PlannerRepository {
        switch environment[fixtureEnvironmentKey] {
        case basicDataFixtureValue:
            return InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot)
        case complexStressFixtureValue:
            return InMemoryPlannerRepository(seedSnapshot: DefaultData.complexStressSnapshot)
        case complexStressJanMar2027FixtureValue:
            return InMemoryPlannerRepository(seedSnapshot: DefaultData.complexStressJanMar2027Snapshot)
        case groupedComplexJanMar2027FixtureValue:
            return InMemoryPlannerRepository(seedSnapshot: DefaultData.groupedComplexJanMar2027Snapshot)
        default:
            return FilePlannerRepository()
        }
    }
}

actor InMemoryPlannerRepository: PlannerRepository {
    private let seedSnapshot: PlannerSnapshot
    private var snapshot: PlannerSnapshot

    init(seedSnapshot: PlannerSnapshot) {
        self.seedSnapshot = seedSnapshot
        self.snapshot = seedSnapshot
    }

    func loadSnapshot() async throws -> PlannerSnapshot {
        snapshot
    }

    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws {
        self.snapshot = snapshot
    }

    func resetSnapshot() async throws {
        snapshot = seedSnapshot
    }
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
