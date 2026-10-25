# Payment logic audit

25 October 2026. Local work on `codex/custom-bill-frequency`, based on remote `main` at `19ee3d4`, source version 1.0 (55). This includes the requested custom bill frequency and its follow-up audit. Nothing has been committed, pushed, merged or uploaded.

## Scope

Reviewed bill/subscription creation and series edits, occurrence adjustments, one-off spending/payment editing, refunds, pot/bank movements, card statement boundaries, direct-debit timing and saved-data compatibility. Two independent read-only reviews covered payments and statements. Existing debt, funding, accounting, persistence and recovery scenarios are included in full validation.

## Corrected behaviour

- Changing a series schedule or funding source starts tomorrow instead of replaying a new schedule into past dates. Already posted occurrences retain their amounts and funding sources; individual occurrence edits use those retained sources.
- A historical bill cannot be posted twice merely because its series switches between bank/pot and card.
- Refunds preserve a confirmed actual bill date, including a full refund that is later reduced or cleared.
- Editing partially refunded pot spending deducts its net cost, preserving the refunded cash.
- Reversing or rescheduling a refunded direct debit restores only cash not already refunded.
- Split-pot refunds allocate whole pennies from a conserved refund budget. New records retain the actual credited shares. Legacy refunds retain the old rounding treatment until explicitly edited; existing balances are not silently recalculated.
- A delayed direct debit does not hide subsequent statement cycles whose payments fall within the queried period.
- Deleting a bill series does not prevent refunding its retained spending record.
- Archived bill history cannot be erased by a date/amount editor that cannot reapply the charge. Refunds remain available.
- The dashboard uses the same bill editor as Bills, including custom frequencies. Generated spending uses the occurrence editor rather than directly changing a derived ledger entry.

## Verification

Nine additional regression tests cover the audit cases, including both payment-route directions, subsequent historical edits, full/partial refund transitions, legacy refund splits, odd pennies, and integer-limit allocation. The first six tests were run against the original implementation and failed, then passed with the fixes.

Full validation on a fresh iOS 27 simulator: **461 passed, one optional external-workbook test skipped, zero failures** (462 total). Unsigned Release build passed. Project membership, package-lock preservation and diff checks passed. The final 375-point shared bill editor screenshot was visually inspected.

Evidence: `/private/tmp/new-money-validation.QbxY43/tests.xcresult`, `/private/tmp/new-money-validation.QbxY43/release.xcresult`, and `/Users/jackd/.codex/visualizations/2026/10/25/01a172da-d5ed-7d91-9f92-29529f4b0eb8/payment-audit-editor.png`.

An intermediate full run detected a card funding-link regression in the initial correction; it was fixed before the final passing run. All nine new audit tests passed alongside the original scenarios.

## Limits

Local tests and unsigned builds do not prove physical-device behaviour, live bank/provider data, cloud permissions, or TestFlight/App Store readiness. The optional external workbook verification requires files not present in this repository. No live financial records, authentication code, account credentials, package versions, signing or release configuration were changed. The audit does not certify that every possible financial scenario is error-free.

## Authorised release preparation

Jack authorised commit, push, merge and a new TestFlight upload on 25 October 2026. App Store Connect lists this app as Muno Money (app 6787782053); build 55 was the latest uploaded build when checked. The release increments only the build number to 56. Signed archive, upload and Apple processing are verified separately from the local audit above.
