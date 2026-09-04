import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    @MainActor
    func testFinalDebtFullAppSimJanApr2028SimulationExportsActualOutputAndMismatchReport() async throws {
        let result = try await FinalDebtFullAppSimJanApr2028Simulation.readArtifacts()

        XCTAssertTrue(result.fixtureSeeded)
        XCTAssertEqual(result.dailyRowCount, 121)
        let requiredSheets = [
            "Daily Actual",
            "Priority UI Actual",
            "Income Actual",
            "Checklist Actual",
            "Transactions Actual",
            "Debt Schedule Actual",
            "Debt Payments Actual",
            "Debt Snapshots Actual",
            "Statements Actual",
            "Card DD Actual",
            "Manual Actions Actual",
            "Warning Periods Actual",
        ]
        XCTAssertEqual(Set(result.rowCounts.keys), Set(requiredSheets))
        XCTAssertEqual(result.rowCounts["Daily Actual"], 121)
        XCTAssertEqual(result.rowCounts["Priority UI Actual"], 29)
        XCTAssertEqual(result.rowCounts["Income Actual"], 23)
        XCTAssertEqual(result.rowCounts["Debt Snapshots Actual"], 605)
        XCTAssertEqual(result.totalMismatches, 0)
        for sheetName in requiredSheets where sheetName != "Daily Actual" {
            XCTAssertGreaterThan(result.rowCounts[sheetName] ?? 0, 0, "\(sheetName) should contain generated rows")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.actualJsonPath))
        XCTAssertFalse(result.expectedWorkbookPath.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.actualWorkbookPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.comparisonReportPath))
    }
}
