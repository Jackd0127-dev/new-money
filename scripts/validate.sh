#!/bin/bash
set -euo pipefail

usage() {
    printf 'Usage: %s SIMULATOR_UDID [OUTPUT_PARENT]\n' "${0##*/}"
    printf 'Runs the full simulator test suite and an unsigned Release build.\n'
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi
if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage >&2
    exit 2
fi
for tool in xcodebuild xcrun python3 git plutil; do
    command -v "$tool" >/dev/null || { printf 'Required tool not found: %s\n' "$tool" >&2; exit 2; }
done

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repository="$(cd -- "$script_directory/.." && pwd -P)"
project="$repository/NewMoneyIPhone/NewMoneyIPhone.xcodeproj"
lockfile="$project/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
simulator="$1"
output_parent="${2:-${TMPDIR:-/tmp}}"
mkdir -p -- "$output_parent"
output_parent="$(cd -- "$output_parent" && pwd -P)"
output="$(mktemp -d "$output_parent/new-money-validation.XXXXXX")"
derived_data="${NEWMONEY_DERIVED_DATA_PATH:-$output/DerivedData}"
package_cache="${NEWMONEY_PACKAGE_CACHE_PATH:-$derived_data/SourcePackages}"
cp -- "$lockfile" "$output/Package.resolved.before"

finish() {
    result=$?
    if ! cmp -s -- "$lockfile" "$output/Package.resolved.before"; then
        printf 'ERROR: Package.resolved changed during validation; inspect it before proceeding.\n' >&2
        result=1
    fi
    printf 'Validation outputs: %s\n' "$output"
    exit "$result"
}
trap finish EXIT

xcrun simctl list devices available -j > "$output/simulators.json"
python3 - "$simulator" "$output/simulators.json" <<'PY'
import json
import sys

devices = json.load(open(sys.argv[2]))["devices"]
matches = [device for runtime, group in devices.items() if ".iOS-" in runtime
           for device in group if device["udid"] == sys.argv[1] and device.get("isAvailable", False)]
if len(matches) != 1:
    raise SystemExit("Supply an exact available iOS simulator UDID from: xcrun simctl list devices available")
print("Simulator:", matches[0]["name"], matches[0]["udid"])
PY

python3 "$script_directory/audit_project.py"
git -C "$repository" diff --check

common=(
    -project "$project"
    -scheme NewMoneyIPhone
    -derivedDataPath "$derived_data"
    -clonedSourcePackagesDirPath "$package_cache"
    -disableAutomaticPackageResolution
    -onlyUsePackageVersionsFromResolvedFile
    -skipPackageUpdates
    CODE_SIGNING_ALLOWED=NO
)

test_status=0
xcodebuild "${common[@]}" test \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator" \
    -parallel-testing-enabled NO \
    -resultBundlePath "$output/tests.xcresult" 2>&1 | tee "$output/tests.log" || test_status=$?

release_status=0
xcodebuild "${common[@]}" build \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -resultBundlePath "$output/release.xcresult" 2>&1 | tee "$output/release.log" || release_status=$?

printf 'Test exit status: %s\nRelease build exit status: %s\n' "$test_status" "$release_status"
if [[ "$test_status" -ne 0 || "$release_status" -ne 0 ]]; then
    exit 1
fi
