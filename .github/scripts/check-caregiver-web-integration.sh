#!/usr/bin/env bash
set -euo pipefail

APP_ROOT=${1:-$PWD}
MODE=${2:-allow-absent}
EXPECTED_PUSH_ID=medication-sync-push-v1
EXPECTED_PULL_ID=medication-sync-pull-v1

case "$MODE" in
  allow-absent|require-complete) ;;
  *) printf 'Unknown caregiver integration mode: %s\n' "$MODE" >&2; exit 1 ;;
esac

consumer_files=(
  lib/core/caregiver/appwrite_caregiver_sync_gateway.dart
  lib/core/caregiver/caregiver_snapshot.dart
  lib/core/caregiver/caregiver_snapshot_controller.dart
  lib/core/caregiver/caregiver_status_projection.dart
  lib/app/web/web_household_gate.dart
  lib/app/web/caregiver_shell.dart
  lib/app/web/web_routes.dart
  test/core/caregiver/appwrite_caregiver_sync_gateway_test.dart
)
prerequisite_files=(
  test/core/sync/domain_contracts_test.dart
)
required_markers=(
  'lib/core/cloud/cloud_configuration.dart|APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID'
  'lib/core/cloud/cloud_gateway_factory.dart|class WebCloudGateways'
  'lib/app/web/dosey_web_dependencies.dart|CaregiverSyncGateway caregiver'
  'lib/main_web.dart|caregiver: gateways.caregiver'
  "test/core/cloud/cloud_gateway_factory_test.dart|web gateway factory builds the Appwrite medication sync adapter"
)

present_consumer_indicators=()
missing_indicators=()
for path in "${consumer_files[@]}"; do
  if [ -f "$APP_ROOT/$path" ]; then
    present_consumer_indicators+=("$path")
  else
    missing_indicators+=("$path")
  fi
done
for path in "${prerequisite_files[@]}"; do
  if [ ! -f "$APP_ROOT/$path" ]; then
    missing_indicators+=("$path")
  fi
done
for specification in "${required_markers[@]}"; do
  IFS='|' read -r path marker <<< "$specification"
  if [ -f "$APP_ROOT/$path" ] && grep -Fq -- "$marker" "$APP_ROOT/$path"; then
    present_consumer_indicators+=("$path contains: $marker")
  else
    missing_indicators+=("$path contains: $marker")
  fi
done

if [ ${#present_consumer_indicators[@]} -eq 0 ]; then
  if [ "$MODE" = require-complete ]; then
    printf 'Caregiver web integration is required for staging and production builds.\n' >&2
    exit 1
  fi
  message='Caregiver web consumers are not present; skipping this pre-consumer integration gate.'
  printf '%s\n' "$message"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$message" >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 0
fi
if [ "${APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID:-}" != "$EXPECTED_PUSH_ID" ]; then
  printf 'APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID must be %s\n' "$EXPECTED_PUSH_ID" >&2
  exit 1
fi
if [ "${APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID:-}" != "$EXPECTED_PULL_ID" ]; then
  printf 'APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID must be %s\n' "$EXPECTED_PULL_ID" >&2
  exit 1
fi
if [ ${#missing_indicators[@]} -ne 0 ]; then
  printf 'Caregiver web integration is only partially present. Missing:\n' >&2
  printf '  %s\n' "${missing_indicators[@]}" >&2
  exit 1
fi

grep -R -Fq -- "$EXPECTED_PUSH_ID" "$APP_ROOT/build/web"
grep -R -Fq -- "$EXPECTED_PULL_ID" "$APP_ROOT/build/web"
for artifact in \
  index.html \
  auth.html \
  flutter_bootstrap.js \
  manifest.json \
  sign-in/index.html \
  household/index.html \
  app/today/index.html \
  app/medications/index.html \
  app/schedules/index.html \
  app/account/index.html; do
  test -s "$APP_ROOT/build/web/$artifact" || {
    printf 'Required caregiver web artifact is missing or empty: %s\n' "$artifact" >&2
    exit 1
  }
done

cd "$APP_ROOT"
flutter test \
  test/core/sync/domain_contracts_test.dart \
  test/core/caregiver \
  test/core/cloud/cloud_configuration_test.dart \
  test/core/cloud/cloud_gateway_factory_test.dart \
  test/app/web
