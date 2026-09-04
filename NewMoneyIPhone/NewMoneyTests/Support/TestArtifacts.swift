import Foundation

/// Test reports stay in an isolated temporary run unless an export directory is explicitly supplied.
enum TestArtifacts {
    private static let runIdentifier = UUID().uuidString

    static func directory(for scenario: String) throws -> URL {
        let root: URL
        if let configured = ProcessInfo.processInfo.environment["NEWMONEY_TEST_OUTPUT_DIRECTORY"] {
            guard configured.hasPrefix("/") else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            root = URL(fileURLWithPath: configured, isDirectory: true)
        } else {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("NewMoneyIPhoneTests", isDirectory: true)
        }
        let directory = root
            .appendingPathComponent(runIdentifier, isDirectory: true)
            .appendingPathComponent(scenario, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
