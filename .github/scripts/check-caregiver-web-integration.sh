#!/usr/bin/env bash
set -euo pipefail

APP_ROOT=${1:-$PWD}
required_markers=(
  'lib/core/cloud/cloud_configuration.dart|CAREGIVER_SYNC_ENABLED'
  'lib/core/cloud/cloud_gateway_factory.dart|DisabledCaregiverSyncGateway'
  'test/core/cloud/cloud_configuration_test.dart|caregiver sync defaults to disabled'
  'test/core/cloud/cloud_gateway_factory_test.dart|IDs alone exist'
)

missing_indicators=()
for specification in "${required_markers[@]}"; do
  IFS='|' read -r path marker <<< "$specification"
  if [ -f "$APP_ROOT/$path" ] && grep -Fq -- "$marker" "$APP_ROOT/$path"; then
    :
  else
    missing_indicators+=("$path contains: $marker")
  fi
done

if [ ${#missing_indicators[@]} -ne 0 ]; then
  printf 'Caregiver sync foundation is incomplete. Missing:\n' >&2
  printf '  %s\n' "${missing_indicators[@]}" >&2
  exit 1
fi

cd "$APP_ROOT"
flutter test \
  test/core/caregiver \
  test/core/cloud/cloud_configuration_test.dart \
  test/core/cloud/cloud_gateway_factory_test.dart
