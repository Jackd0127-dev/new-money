# Native crash reporting

New Money links FirebaseCrashlytics from the existing pinned Firebase package.
The SDK starts through the existing Firebase configuration; the sign-in,
APNs callbacks, sessions, planner sync and financial calculations are unchanged.
Firebase Analytics is not added. No account ID, email, balance, transaction,
planner record or custom diagnostic value is added to a report.

Crashlytics collects its standard technical crash and session diagnostics in
the existing `new-money-14d2a` Firebase project for the existing native app.
Collection becomes effective only in builds containing this change. A source
merge does not update already installed apps or prove Firebase delivery.

The final build phase runs Firebase's symbol uploader for Release device
builds. It uses the built Firebase configuration and generated dSYMs; simulator
and test builds skip symbol upload. Unsigned Release verification builds validate
the inputs without uploading. The phase preserves Xcode script sandboxing
and declares the SDK, configuration, binary and symbol inputs. Use Xcode's
default SourcePackages directory within DerivedData for release builds.

Before a native release, verify a deliberate crash on a fresh test installation,
restart with the debugger detached, and confirm the Firebase issue and readable
stack. Review App Store privacy declarations for the added diagnostics.
Synthetic events must remain separate from real installed-user statistics.

Dashboard crash/session totals require exported tables, schema verification and
an approved bounded reader. This SDK integration does not create BigQuery
datasets, grant access, enable billing or claim dashboard analytics are live.
On 30 September 2026, the local network's DNS filtering prevented the Curate
test installation from reaching Firebase crash/logging endpoints. Resolve that
test-network prerequisite before claiming a New Money delivery test passed.

Setup follows the [Firebase Apple guide](https://firebase.google.com/docs/crashlytics/ios/get-started)
and [symbol upload guidance](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports).

## Verification, 30 September 2026

Project membership and shell syntax checks passed. The 35 existing AuthSyncTests
and SessionSyncRecoveryTests passed on a fresh iOS 26.5 simulator. A locally
signed Debug build launched with Crashlytics 12.15.0 and logged a Session Start
event. The unsigned Release device build passed, including Firebase's symbol
input validation. Simulator/Debug skip, signed Release upload delegation and
unsigned Release validation branches were exercised with a disposable local
SDK stand-in. This does not verify a real symbol upload.

Existing app lifecycle, auth and sync files and Package.resolved retained their
baseline hashes. No financial calculation, data migration, live-account operation
or remote permission/billing change was made. Firebase delivery, readable cloud
crashes, native distribution and dashboard export totals remain unverified.
