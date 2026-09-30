#!/bin/sh
set -eu

# Upload symbols for shipped device builds. Simulator/tests never upload symbols.
if [ "${PLATFORM_NAME:-}" != "iphoneos" ] || [ "${CONFIGURATION:-}" != "Release" ]; then
    exit 0
fi

firebase_package_root="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk"

# Unsigned verification builds validate the inputs without an outbound upload.
if [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ]; then
    exec "$firebase_package_root/Crashlytics/upload-symbols" --build-phase --validate
fi

exec "$firebase_package_root/Crashlytics/run"
