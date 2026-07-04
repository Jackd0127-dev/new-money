import Foundation

protocol PlannerRepository: Sendable {
    func loadSnapshot() async throws -> PlannerSnapshot
    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws
    func resetSnapshot() async throws
}

struct PlannerAccount: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var color: String
    var snapshot: PlannerSnapshot
    var createdAt: String
    var updatedAt: String
}

struct PlannerAccountCollection: Codable, Equatable, Sendable {
    static let maxAccounts = 3

    var activeAccountId: String
    var accounts: [PlannerAccount]
    var updatedAt: String

    var activeAccount: PlannerAccount? {
        accounts.first { $0.id == activeAccountId } ?? accounts.first
    }

    static func singleAccount(snapshot: PlannerSnapshot, name: String = "Personal") -> PlannerAccountCollection {
        let now = DateUtilities.nowIsoString()
        let account = PlannerAccount(
            id: DateUtilities.newId(prefix: "planner-account"),
            name: name,
            color: "#F97316",
            snapshot: snapshot,
            createdAt: now,
            updatedAt: now
        )
        return PlannerAccountCollection(activeAccountId: account.id, accounts: [account], updatedAt: now)
    }
}

enum PlannerAccountError: Error, Equatable, LocalizedError {
    case blankName
    case duplicateName
    case limitReached
    case missingAccount
    case cannotDeleteLastAccount

    var errorDescription: String? {
        switch self {
        case .blankName:
            return "Account name cannot be empty."
        case .duplicateName:
            return "An account with that name already exists."
        case .limitReached:
            return "You can create up to 3 accounts."
        case .missingAccount:
            return "That account could not be found."
        case .cannotDeleteLastAccount:
            return "Keep at least one account."
        }
    }
}

protocol PlannerAccountRepository: Sendable {
    func loadAccountCollection() async throws -> PlannerAccountCollection?
    func saveAccountCollection(_ collection: PlannerAccountCollection) async throws
    func resetAccountCollection() async throws
}

enum PlannerLaunchProfile {
    static let fixtureEnvironmentKey = "NEWMONEY_PLANNER_FIXTURE"
    static let basicDataFixtureValue = "basic-data"
    static let complexStressFixtureValue = "complex-stress-sep-oct-2026"
    static let complexStressJanMar2027FixtureValue = "complex-stress-jan-mar-2027"
    static let groupedComplexJanMar2027FixtureValue = "grouped-complex-jan-mar-2027"
    static let fullAppLogicTortureJulSep2027FixtureValue = "full-app-logic-torture-jul-sep-2027"
    static let finalDebtFullAppSimJanApr2028FixtureValue = "final-debt-full-app-sim-jan-apr-2028"
    static let debtDemoFixtureValue = "debt-demo"

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
        case fullAppLogicTortureJulSep2027FixtureValue:
            return InMemoryPlannerRepository(seedSnapshot: DefaultData.fullAppLogicTortureJulSep2027Snapshot)
        case finalDebtFullAppSimJanApr2028FixtureValue:
            return InMemoryPlannerRepository(seedSnapshot: DefaultData.finalDebtFullAppSimJanApr2028Snapshot)
        case debtDemoFixtureValue:
            return InMemoryPlannerRepository(seedSnapshot: DefaultData.debtDemoSnapshot)
        default:
            return FilePlannerRepository()
        }
    }

    static func isUsingFixture(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[fixtureEnvironmentKey] != nil
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

actor InMemoryPlannerAccountRepository: PlannerAccountRepository {
    private let seedCollection: PlannerAccountCollection?
    private var collection: PlannerAccountCollection?

    init(seedCollection: PlannerAccountCollection? = nil) {
        self.seedCollection = seedCollection
        self.collection = seedCollection
    }

    func loadAccountCollection() async throws -> PlannerAccountCollection? {
        collection
    }

    func saveAccountCollection(_ collection: PlannerAccountCollection) async throws {
        self.collection = collection
    }

    func resetAccountCollection() async throws {
        collection = seedCollection
    }
}

actor FilePlannerAccountRepository: PlannerAccountRepository {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = supportDirectory
            .appendingPathComponent("NewMoneyIPhone", isDirectory: true)
            .appendingPathComponent("planner-accounts-v1.json")
    }

    func loadAccountCollection() async throws -> PlannerAccountCollection? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PlannerAccountCollection.self, from: data)
    }

    func saveAccountCollection(_ collection: PlannerAccountCollection) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(collection)
        try data.write(to: fileURL, options: [.atomic])
    }

    func resetAccountCollection() async throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
