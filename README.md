# New Money

Native iPhone finance planner built with Swift 6 and SwiftUI, targeting iOS 17 or later. Open `NewMoneyIPhone/NewMoneyIPhone.xcodeproj` and use the `NewMoneyIPhone` scheme for the normal app.

## Repository layout

- `NewMoneyIPhone/NewMoney/App`: application lifecycle, navigation, and planner state.
- `NewMoneyIPhone/NewMoney/Domain`, `Models`, and `Data`: calculations, persisted models, defaults, migrations, and repositories.
- `NewMoneyIPhone/NewMoney/Features`, `Components`, and `Theme`: feature screens and shared presentation.
- `NewMoneyIPhone/NewMoney/Services`: service integration. Authentication and access control require their own explicit change scope.
- `NewMoneyIPhone/NewMoneyTests/Finance`: finance test extensions grouped by behavior. `FinanceEngineTests.swift` keeps their existing shared setup and teardown.
- `NewMoneyIPhone/NewMoneyTests/Scenarios` and `Support`: simulation tests, reusable fixtures, artifact helpers, and optional external workbook checks.
- `scripts`: local project checks and verification. No GitHub Actions or release automation is configured here.

Source files use explicit Xcode target membership. When adding or moving Swift files, update the project references and Sources build phase as well. Keep app and test bundle identifiers, resource names, signing settings, and the package lockfile unchanged unless the task specifically requires changing them.

## Local verification

Requirements: macOS, Xcode with a Swift 6 compiler and an available iOS simulator, command-line tools selected for that Xcode, and Python 3. Dependencies are pinned in the tracked `Package.resolved`; initial installation may need network access.

```sh
xcrun simctl list devices available
./scripts/validate.sh SIMULATOR_UDID
```

Replace `SIMULATOR_UDID` with the exact identifier from the list. The script checks Xcode membership and whitespace, runs the complete simulator test target, then compiles Release for a generic iOS device without signing. It still attempts the Release build when tests fail, and returns a failure status if either check fails. It does not archive, upload, commit, push, deploy, or change package versions.

Use a fresh simulator with no signed-in app account. The normal app hosts these tests, so an existing simulator may retain a real session even though individual tests use in-memory repositories. Never use a device holding live planner data for this verification.

Every run gets its own output directory and prints the location of its logs and `.xcresult` bundles. An optional second argument selects the parent output directory. Set `NEWMONEY_DERIVED_DATA_PATH` and, if useful, `NEWMONEY_PACKAGE_CACHE_PATH` to reuse existing build/dependency caches; otherwise both are kept in the run directory. Do not share a writable DerivedData directory with a concurrent build.

For the fast structural check alone:

```sh
python3 scripts/audit_project.py
```

A successful local build is not evidence of live-device behavior, an uploaded TestFlight build, or completed App Store compliance. Report test failures and skipped external checks separately.

## Test reports and external workbooks

Ordinary simulations use in-memory repositories. Their JSON and Markdown reports go into a unique run under the test process's temporary directory, never a directory inferred from source-file depth. To export them elsewhere, pass the absolute `NEWMONEY_TEST_OUTPUT_DIRECTORY` to the test runner. This is opt-in because some scenario reports contain detailed fixture records.

The July 2027 simulation produces JSON and validates its recorded rows; it does not claim to generate an XLSX workbook or a mismatch report.

The January-April 2028 external workbook exporter and source workbooks are not included in this repository. The optional workbook test skips before doing any file writes unless the test runner receives both:

- `NEWMONEY_EXTERNAL_DEBT_RESULTS_DIRECTORY`: absolute directory containing `final_debt_full_app_sim_actual_jan_apr_2028.json`, `final_debt_full_app_sim_actual_jan_apr_2028.xlsx`, and `final_debt_full_app_sim_mismatch_report_jan_apr_2028.md`.
- `NEWMONEY_EXTERNAL_DEBT_EXPECTED_WORKBOOK`: absolute path to the expected workbook used by that exporter.

When configured, missing/unreadable files or incorrect result totals fail verification. This check reads supplied exporter results; it does not independently reproduce the external workbook calculation. The ordinary debt and in-process simulation tests remain part of every full run.

The additional Xcode schemes select fixture or repair workflows. Use them deliberately; never run a live-repair scheme as a smoke test. The normal validation script always selects `NewMoneyIPhone`.
