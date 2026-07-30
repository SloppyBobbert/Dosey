#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
CHECKER="$ROOT_DIR/.github/scripts/check-caregiver-web-integration.sh"
EXPECTED_PUSH_ID=medication-sync-push-v1
EXPECTED_PULL_ID=medication-sync-pull-v1
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

run_checker() {
  APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID=$EXPECTED_PUSH_ID \
  APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID=$EXPECTED_PULL_ID \
    bash "$CHECKER" "$1" "${2:-allow-absent}"
}

run_checker_without_ids() {
  env -u APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID \
    -u APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID \
    bash "$CHECKER" "$1" "${2:-allow-absent}"
}

make_file() {
  mkdir -p "$(dirname -- "$1")"
  : > "$1"
}

make_consumer_set() {
  local root=$1
  local path
  for path in \
    lib/core/caregiver/appwrite_caregiver_sync_gateway.dart \
    lib/core/caregiver/caregiver_snapshot.dart \
    lib/core/caregiver/caregiver_snapshot_controller.dart \
    lib/core/caregiver/caregiver_status_projection.dart \
    lib/app/web/web_household_gate.dart \
    lib/app/web/caregiver_shell.dart \
    lib/app/web/web_routes.dart \
    test/core/caregiver/appwrite_caregiver_sync_gateway_test.dart; do
    make_file "$root/$path"
  done
  make_file "$root/lib/core/cloud/cloud_configuration.dart"
  printf '%s\n' APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID > "$root/lib/core/cloud/cloud_configuration.dart"
  make_file "$root/lib/core/cloud/cloud_gateway_factory.dart"
  printf '%s\n' 'class WebCloudGateways' > "$root/lib/core/cloud/cloud_gateway_factory.dart"
  make_file "$root/lib/app/web/dosey_web_dependencies.dart"
  printf '%s\n' 'CaregiverSyncGateway caregiver' > "$root/lib/app/web/dosey_web_dependencies.dart"
  make_file "$root/lib/main_web.dart"
  printf '%s\n' 'caregiver: gateways.caregiver' > "$root/lib/main_web.dart"
  make_file "$root/test/core/cloud/cloud_gateway_factory_test.dart"
  printf '%s\n' 'web gateway factory builds the Appwrite medication sync adapter' > "$root/test/core/cloud/cloud_gateway_factory_test.dart"
}

make_complete_artifact() {
  local root=$1
  local path
  for path in \
    index.html auth.html flutter_bootstrap.js manifest.json \
    sign-in/index.html household/index.html app/today/index.html \
    app/medications/index.html app/schedules/index.html app/account/index.html; do
    make_file "$root/build/web/$path"
    printf '%s\n' artifact > "$root/build/web/$path"
  done
  printf '%s\n%s\n' "$EXPECTED_PUSH_ID" "$EXPECTED_PULL_ID" > "$root/build/web/main.dart.js"
}

prerequisite_only="$TEMP_DIR/prerequisite-only"
make_file "$prerequisite_only/test/core/sync/domain_contracts_test.dart"
output=$(run_checker_without_ids "$prerequisite_only")
grep -Fq 'skipping this pre-consumer integration gate' <<< "$output"

partial="$TEMP_DIR/partial"
make_file "$partial/lib/core/caregiver/caregiver_snapshot.dart"
if run_checker_without_ids "$partial" > "$TEMP_DIR/partial-without-ids.out" 2>&1; then
  printf 'A started caregiver rollout must not skip medication sync ID validation.\n' >&2
  exit 1
fi
grep -Fq 'APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID must be' "$TEMP_DIR/partial-without-ids.out"
if run_checker "$partial" > "$TEMP_DIR/partial.out" 2>&1; then
  printf 'A partial caregiver consumer set must fail.\n' >&2
  exit 1
fi
grep -Fq 'only partially present' "$TEMP_DIR/partial.out"

missing_prerequisite="$TEMP_DIR/missing-prerequisite"
make_consumer_set "$missing_prerequisite"
make_complete_artifact "$missing_prerequisite"
if run_checker "$missing_prerequisite" > "$TEMP_DIR/missing-prerequisite.out" 2>&1; then
  printf 'A complete consumer set without the shared contract prerequisite must fail.\n' >&2
  exit 1
fi
grep -Fq 'test/core/sync/domain_contracts_test.dart' "$TEMP_DIR/missing-prerequisite.out"

complete="$TEMP_DIR/complete"
make_consumer_set "$complete"
make_file "$complete/test/core/sync/domain_contracts_test.dart"
make_complete_artifact "$complete"
mkdir -p "$TEMP_DIR/bin"
cat > "$TEMP_DIR/bin/flutter" <<'FAKE_FLUTTER'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FLUTTER_ARGUMENTS_FILE"
FAKE_FLUTTER
chmod +x "$TEMP_DIR/bin/flutter"
arguments_file="$TEMP_DIR/flutter-arguments"
PATH="$TEMP_DIR/bin:$PATH" FLUTTER_ARGUMENTS_FILE="$arguments_file" run_checker "$complete"
expected='test test/core/sync/domain_contracts_test.dart test/core/caregiver test/core/cloud/cloud_configuration_test.dart test/core/cloud/cloud_gateway_factory_test.dart test/app/web'
test "$(wc -l < "$arguments_file")" -eq 1
test "$(cat "$arguments_file")" = "$expected"

printf 'Caregiver web integration phased checks passed.\n'
