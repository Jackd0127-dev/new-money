# New Money iPhone planner

Use the normal `NewMoneyIPhone` scheme in `NewMoneyIPhone/NewMoneyIPhone.xcodeproj`. Read [README.md](README.md) for repository layout and verification setup; load only the source and historical evidence relevant to the task. `docs/app-overhaul.md` records an earlier change and its limits, not current live-state proof or authorization to repeat the overhaul.

## Focused verification

- Prose: facts, links and diff only; no app suite.
- Cosmetics: inspect the affected screen/code and useful simulator or preview states. Do not introduce tests that mirror style values.
- Logic or interaction: select existing tests matching the changed behavior and exercise its outcome. For shared components include representative consumers; add regression coverage when it protects meaningful behavior.
- Finance calculations, persistence, migrations, sync/security and authorized releases retain applicable regression, integration and release checks. Use the full `scripts/validate.sh` for substantial shared financial/data-integrity changes or full validation; it runs the complete simulator suite and unsigned Release build, so it is not the default for every edit.

For focused XCTest runs, use the existing project's test identifiers with xcodebuild's `-only-testing:` selection and the normal scheme. Discover the actual test class/method in source before choosing it; do not invent identifiers. Reuse the pinned-dependency, unsigned-build and isolated output/cache options documented in `scripts/validate.sh`; that script itself has no focused-test argument. Run `python3 scripts/audit_project.py` when changing Xcode membership or project references.

Use a fresh simulator with no signed-in account or live planner data. These app-hosted tests may otherwise retain a real session. Never use a repair scheme as a smoke test. Do not share writable DerivedData with another build.

Reuse passing evidence for unchanged source/environment. Repeat or broaden only after relevant edits, failures or concrete unresolved concerns; stop when the requested outcome and applicable checks are complete. Report skipped external checks and unavailable inputs, not fabricated passes.

## Preserve app and data boundaries

Swift files have explicit Xcode target membership: update references and Sources membership when adding/moving them. Keep package versions, bundle identifiers, signing, resources and entitlements unchanged unless specifically scoped.

Authentication and access control require their own explicit scope. Do not touch accounts, sessions, live planner/cloud records or repair workflows for unrelated UI work. Financial calculations need sourced inputs and exact existing money semantics; do not infer missing historical allocations or silently recalculate live records. Preserve migrations, recovery backups and conflict handling when working in those areas.

A local test/build does not prove live cloud permissions, device behavior, TestFlight upload or App Store readiness. Inspect authoritative source or state the missing context; never infer success from old reports. No GitHub Actions, release automation, deployment or upload is implied by these instructions.
