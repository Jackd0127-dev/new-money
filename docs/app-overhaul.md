# App overhaul

Scope: the complete tracked iPhone app, its financial domain, storage, sync, automation, presentation, project membership, resources, and test tooling. Work is isolated on `codex/app-overhaul`, based on `0986c73`. No dependency upgrades, signing changes, live data operations, commits, uploads, or releases are part of this change.

## Financial correctness

- Money input rejects malformed signs, unsupported decimal syntax, and integer overflow. A failable parsing API is available; the original compatibility API returns zero for invalid input.
- Paycheck creation/editing rejects impossible dates and non-finite or out-of-range hours before mutation.
- Debt refunds conserve integer pennies across principal, interest, and fees. Hierarchical proportional rounding keeps every component monotonic as the refund changes.
- Partial debt payments consume only the remaining scheduled interest and fees. Payment reversal restores principal to debt and gross cash to recorded funding pots separately.
- Automatic debt payments record their exact pot contributions and debit exactly the cash accepted by the payment engine. New multi-pot payments support exact refund/deletion reversal.
- Manual Pay now payments retain an explicit funding-allocation link. Correcting the payment also corrects its funding amount, period, and debt references while leaving pre-existing pot cash intact. Legacy links are recovered only from unique matching records; ambiguous or damaged links block edits. Ordinary payments from existing pot funds retain their cash adjustment.
- Refunding or deleting a payment reopens its original scheduled occurrence. Refunded/deleted occurrences require an explicit subsequent payment; automation does not immediately spend their returned cash again.
- Reconciliation caps the sum of surviving linked payments at the occurrence budget, so refunding an overpayment does not falsely reopen an instalment still covered by the remaining cash. Evidenced legacy aggregate-only payments are retained.
- Older multi-pot payments did not record their split. No split is invented. Their cash reversal requires manual review, and financial edits are blocked until that provenance can be established. Note/date edits preserve an explicit unknown-split marker.
- Editing a recurring series preserves posted charge amounts and destinations. Explicit occurrence corrections reconcile the recorded pot balance.
- Calendar, quarterly, and card cycle generation recover the intended day after short months while preserving referenced historical cycle identities, repayment links, and locked statement dates.

APR and interest-estimation conventions are unchanged. These calculations remain planning estimates, not lender statements. No historical finance data has been silently recalculated in a live account.

## Persistence and recovery

- One save coordinator serializes writes, coalesces superseded pending revisions, retains failed writes for retry, and exposes pending/saved/failed state.
- Cloud export is a stable read. Sync waits until the current local revision is durable before exporting it.
- Current account data loads before the legacy snapshot. Corrupt current data fails closed rather than falling back and overwriting it. Invalid account identities are rejected; existing accounts are not truncated to the new-account creation limit.
- A temporary write failure during startup remains retryable; it is not classified as unreadable source data. Reload cannot replace newer unsaved changes with an older file.
- The first replacement of an existing planner JSON file saves its exact previous bytes alongside it with the `.before-overhaul-v1` extension. Existing backups are never overwritten by this mechanism.
- Account themes and unrelated collection metadata survive normalization. The app shows save/sync failures and offers retry.
- An explicit all-planner reset clears the selected theme and atomically saves the empty replacement collection without reattaching the previous theme.

The backup/recovery files intentionally remain local. This change does not add a user-facing arbitrary JSON import or recovery-archive browser.

## Sync

- Sync keeps per-user durable checkpoints and an outbox containing the exact pending payload, expected cloud revision, and operation ID.
- Cloud writes compare the original cloud payload fingerprint and server timestamp in a Firestore transaction. A changed remote copy produces a conflict instead of an unconditional overwrite.
- Conflicts preserve both copies in immutable local recovery files. The planner is gated until a choice is made; unknown/other-owner data is not exposed during an offline fallback.
- Sign-out and reset fence pending sync work. An interrupted acknowledgment can recover the already-committed operation without inventing a timestamp winner.
- A newer sign-out/reset supersedes older work still awaiting suspension or local saving. Generation checks and operation-owned gates prevent stale completion from reactivating sync or unlocking a newer action.
- Fixture sessions skip planner cloud/recovery access on startup, upload, retry, and conflict resolution, and explicitly reject cloud reset. Their status says that cloud sync is off. Authentication and account-management actions retain their existing behavior, so fixture mode is not a blanket backend sandbox.
- Existing cloud document paths and v2 shape are retained. Known-field updates retain unknown fields on matching records.

Firebase security rules are not present in this repository, and these changes have not been exercised against a live signed-in account. Transaction/backup permissions still require staging verification before release. Older installed clients can still perform their existing unconditional writes; this client cannot guarantee multi-device conflict safety for writes made by those versions. Authentication providers, verification, account endpoint behavior, entitlements, and permission configuration were not changed.

Existing password-recovery and legal-link placeholders on the authentication screen remain outside the approved sync-only auth changes. Completing those flows needs explicit authentication/legal destination scope.

## Automation and performance

- Catch-up retains chronological day order and its existing bounded checkpoint behavior. Only the first replay day scans recurring history; subsequent replay days use the current cursor. Overdue debt funding remains eligible for later funding, and card statements are not incorrectly bounded by the recurring cursor.
- Settled statement cycles are filtered before expensive statement breakdown calculations.
- Foreground, significant-time-change, and day-boundary events refresh derived data. There is no continuous polling loop.
- Reminder updates are serialized, coalesced, account-scoped, diffed against existing requests, limited to 60, and cannot delete notifications outside their managed prefix.
- Calendar, history, and card-detail presentations reuse revision/date-keyed results. Per-row history scans and repeated whole-month calendar calculations are removed. Pot pulse animation and redundant blur work are removed.
- Calendar week rows render eagerly within their bounded month so the final week cannot disappear inside the swipe container. Calendar headings, totals, and History rows adapt to narrow widths and accessibility text sizes without splitting ordinary currency values across lines.
- Currency display uses Decimal formatting, preserving pennies at integer limits and avoiding a new NumberFormatter for every displayed amount. An optimized local microbenchmark of 10,000 synthetic values took 2.822 seconds with the old formatter and 0.411 seconds with the new one; output checksums matched and 500 ordinary values were compared individually. This isolated result is not an app-wide speedup claim.

No device-level CPU, energy, memory, or frame-rate improvement is claimed without Instruments measurements. The deterministic cache tests verify reuse and invalidation, not a fabricated speedup percentage.

## Structure and verification

Calendar, History, and Assistant code now live in their own feature folders. Finance tests are grouped into focused behavior extensions; simulation and artifact helpers are separate. Existing tests are retained. Reports use isolated temporary output, and unavailable external workbook inputs are explicit opt-in checks.

The suite retains the original 361 test methods and adds focused correctness, persistence, sync, scheduling, cache, and rendering checks. One existing simulation test was renamed to describe its actual JSON output; no original test was dropped. An existing stale colour assertion now matches the unchanged palette. Rendering checks exercise real fixture-backed screens at narrow width, large Dynamic Type, and a light theme, with screenshots saved as XCTest attachments. The harness uses matching palette and system colour-scheme settings and restores the previous preference afterward.

`scripts/audit_project.py` checks source membership, project references, shared schemes, and the pinned package lockfile. `scripts/validate.sh` runs the full simulator target and unsigned Release build without GitHub Actions or release operations.

## Validation results

- Full simulator suite: **442 passed, 1 skipped, 0 failed** (443 total), using the normal `NewMoneyIPhone` scheme on a newly created iPhone 17 Pro simulator with iOS 26.5 and no signed-in account. XCTest reported approximately 533 seconds of test execution. All five final Pay now funding-correction checks passed.
- The skipped test requires external January-April 2028 workbook files that were not supplied. In-process financial simulations remain included and passed.
- Twelve real-screen captures were reviewed: Plan, Calendar, History, and Assistant at 320-point width in Classic dark mode, 390-point width with accessibility3 text in Classic dark mode, and 390-point width in Warm Light. Calendar final weeks, headers, visible titles, amounts, and composer placement were checked. The final test run reproduced all twelve images byte-for-byte. This does not establish VoiceOver interaction, every below-fold state, or live-device behavior.
- Source membership audit: 67 app Swift files and 30 test Swift files, all registered exactly once. Whitespace checks pass. Dependency versions, build configurations, signing, entitlements, assets, and existing schemes are unchanged.
- Local evidence is saved under the ignored `outputs/verification` directory: test summary, test/build logs, source hashes, twelve screen captures, and the complete `tests.xcresult` and `release.xcresult` bundles.
- Unsigned device Release build: **passed** on the same source as the full test run. The standard App Intents metadata warning indicates that this app has no AppIntents framework dependency; no compiler errors were reported.

No passing build alone proves live authentication, cloud rules, notification delivery, or TestFlight readiness.
