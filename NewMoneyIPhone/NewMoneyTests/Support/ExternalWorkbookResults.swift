import Foundation
import XCTest
@testable import NewMoneyIPhone

struct FinalDebtFullAppSimJanApr2028SimulationResult {
    var fixtureSeeded: Bool
    var dailyRowCount: Int
    var rowCounts: [String: Int]
    var totalMismatches: Int
    var actualJsonPath: String
    var expectedWorkbookPath: String
    var actualWorkbookPath: String
    var comparisonReportPath: String
}

/// Optional checks consume explicitly supplied exporter results; ordinary tests never run external scripts.
@MainActor
enum FinalDebtFullAppSimJanApr2028Simulation {
    static func readArtifacts() async throws -> FinalDebtFullAppSimJanApr2028SimulationResult {
        let environment = ProcessInfo.processInfo.environment
        guard let directory = environment["NEWMONEY_EXTERNAL_DEBT_RESULTS_DIRECTORY"], !directory.isEmpty else {
            throw XCTSkip("Optional workbook verification requires NEWMONEY_EXTERNAL_DEBT_RESULTS_DIRECTORY and NEWMONEY_EXTERNAL_DEBT_EXPECTED_WORKBOOK. The external exporter and workbooks are not in this repository.")
        }
        let expectedWorkbookPath = try XCTUnwrap(
            environment["NEWMONEY_EXTERNAL_DEBT_EXPECTED_WORKBOOK"],
            "Supply the expected workbook when enabling external debt-result verification."
        )
        guard directory.hasPrefix("/"), expectedWorkbookPath.hasPrefix("/") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        guard FileManager.default.isReadableFile(atPath: expectedWorkbookPath) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let outputDirectory = URL(fileURLWithPath: directory, isDirectory: true)
        let actualJsonURL = outputDirectory.appendingPathComponent("final_debt_full_app_sim_actual_jan_apr_2028.json")
        let actualWorkbookURL = outputDirectory.appendingPathComponent("final_debt_full_app_sim_actual_jan_apr_2028.xlsx")
        let comparisonReportURL = outputDirectory.appendingPathComponent("final_debt_full_app_sim_mismatch_report_jan_apr_2028.md")
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: actualJsonURL)) as? [String: Any]
        )
        let rowCounts = intDictionary(payload["rowCounts"] as? [String: Any] ?? [:])
        let comparison = payload["comparison"] as? [String: Any]
        let totalMismatches = intValue(comparison?["totalMismatches"]) ?? -1
        let fixtureRepository = PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.finalDebtFullAppSimJanApr2028FixtureValue
        ])
        _ = try await fixtureRepository.loadSnapshot()

        return FinalDebtFullAppSimJanApr2028SimulationResult(
            fixtureSeeded: fixtureRepository is InMemoryPlannerRepository,
            dailyRowCount: rowCounts["Daily Actual"] ?? 0,
            rowCounts: rowCounts,
            totalMismatches: totalMismatches,
            actualJsonPath: actualJsonURL.path,
            expectedWorkbookPath: expectedWorkbookPath,
            actualWorkbookPath: actualWorkbookURL.path,
            comparisonReportPath: comparisonReportURL.path
        )
    }

    private static func intDictionary(_ dictionary: [String: Any]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: dictionary.compactMap { key, value in
            guard let int = intValue(value) else { return nil }
            return (key, int)
        })
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let double = value as? Double { return Int(double) }
        return nil
    }
}
