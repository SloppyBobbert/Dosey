#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
CHECKER="$ROOT_DIR/.github/scripts/check-caregiver-web-integration.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

for path in \
  lib/core/cloud/cloud_configuration.dart \
  lib/core/cloud/cloud_gateway_factory.dart \
  test/core/cloud/cloud_configuration_test.dart \
  test/core/cloud/cloud_gateway_factory_test.dart; do
  mkdir -p "$TEMP_DIR/$(dirname -- "$path")"
done
printf '%s\n' CAREGIVER_SYNC_ENABLED > "$TEMP_DIR/lib/core/cloud/cloud_configuration.dart"
printf '%s\n' DisabledCaregiverSyncGateway > "$TEMP_DIR/lib/core/cloud/cloud_gateway_factory.dart"
printf '%s\n' 'caregiver sync defaults to disabled' > "$TEMP_DIR/test/core/cloud/cloud_configuration_test.dart"
printf '%s\n' 'IDs alone exist' > "$TEMP_DIR/test/core/cloud/cloud_gateway_factory_test.dart"
mkdir -p "$TEMP_DIR/bin"
printf '%s\n' '#!/usr/bin/env bash' > "$TEMP_DIR/bin/flutter"
printf '%s\n' 'printf "%s\\n" "$*" > "$FLUTTER_ARGUMENTS_FILE"' >> "$TEMP_DIR/bin/flutter"
chmod +x "$TEMP_DIR/bin/flutter"
PATH="$TEMP_DIR/bin:$PATH" FLUTTER_ARGUMENTS_FILE="$TEMP_DIR/flutter-arguments" \
  bash "$CHECKER" "$TEMP_DIR"
test "$(cat "$TEMP_DIR/flutter-arguments")" = 'test test/core/caregiver test/core/cloud/cloud_configuration_test.dart test/core/cloud/cloud_gateway_factory_test.dart'

for workflow in \
  web-preview.yml \
  web-staging.yml \
  web-production.yml \
  mobile-ci.yml \
  android-release.yml; do
  path="$ROOT_DIR/.github/workflows/$workflow"
  if grep -Eq -- 'APPWRITE_MEDICATION_SYNC_|medication-sync-(push|pull)-' "$path"; then
    printf '%s must not inject medication-sync Function IDs.\n' "$workflow" >&2
    exit 1
  fi

  build_count=0
  build_command=''
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -z "$build_command" ] && [[ "$line" == *'flutter build '* ]]; then
      build_command="$line"
    elif [ -n "$build_command" ]; then
      build_command+=" $line"
    fi

    if [ -n "$build_command" ] && [[ "$line" != *\\ ]]; then
      build_count=$((build_count + 1))
      if [[ "$build_command" != *'--dart-define=CAREGIVER_SYNC_ENABLED=false'* ]]; then
        printf '%s Flutter build must explicitly disable caregiver sync.\n' "$workflow" >&2
        exit 1
      fi
      build_command=''
    fi
  done < "$path"

  if [ "$build_count" -eq 0 ]; then
    printf '%s must contain a Flutter build command.\n' "$workflow" >&2
    exit 1
  fi
done

if grep -Eq -- 'APPWRITE_MEDICATION_SYNC_|medication-sync-(push|pull)-' \
  "$ROOT_DIR/.github/actions/prepare-appwrite-env/action.yml"; then
  printf 'Generated .env configuration must not include medication-sync Function IDs.\n' >&2
  exit 1
fi

printf 'Caregiver sync foundation checks passed.\n'
