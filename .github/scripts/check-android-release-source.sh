#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
WORKFLOW=${1:-"$ROOT_DIR/.github/workflows/android-release.yml"}
MOBILE_WORKFLOW=${2:-"$ROOT_DIR/.github/workflows/mobile-ci.yml"}

ruby - "$WORKFLOW" "$MOBILE_WORKFLOW" <<'RUBY'
require 'yaml'
require 'shellwords'

workflow = YAML.load_file(ARGV.fetch(0))
mobile_workflow = YAML.load_file(ARGV.fetch(1))
jobs = workflow.fetch('jobs')
build = jobs.fetch('release-android')
publish = jobs.fetch('publish-release')
abort 'publish-release must have a 60-minute timeout' unless publish['timeout-minutes'] == 60

def find_step(job, name)
  job.fetch('steps').find { |step| step['name'] == name } ||
    abort("required Android policy step is missing: #{name}")
end

def assert_android_build(job:, name:, mode:, flavor:, capability:)
  step = find_step(job, name)
  tokens = Shellwords.shellsplit(step.fetch('run'))
  expected = [
    'dart', 'run', 'tool/appwrite_profile.dart', 'flutter',
    '--profile', 'config/appwrite/offline.json', '--flavor', flavor,
    '--', 'build', 'apk', mode,
  ]
  abort("#{name} must use the exact #{flavor}/#{capability} build contract") unless tokens == expected
end

def assert_phased_runtime_gate(job)
  script = find_step(job, 'Verify runtime capability contracts').fetch('run')
  expected = <<~'SHELL'
    set -euo pipefail
    runtime_tests=(
      test/core/runtime/runtime_capability_test.dart
      test/core/runtime/runtime_bootstrap_test.dart
      test/core/runtime/local_runtime_capability_repository_test.dart
    )
    existing_tests=()
    missing_tests=()
    for test_path in "${runtime_tests[@]}"; do
      if [ -f "$test_path" ]; then
        existing_tests+=("$test_path")
      else
        missing_tests+=("$test_path")
      fi
    done
    if [ ${#existing_tests[@]} -eq 0 ]; then
      printf 'Runtime capability contract tests are not present; skipping this pre-runtime rollout gate.\n' | tee -a "$GITHUB_STEP_SUMMARY"
      exit 0
    fi
    if [ ${#missing_tests[@]} -ne 0 ]; then
      printf 'Runtime capability contract tests are only partially present. Missing:\n' >&2
      printf '  %s\n' "${missing_tests[@]}" >&2
      exit 1
    fi
    printf 'Runtime capability contract tests are complete and covered by the full Flutter test suite.\n' | tee -a "$GITHUB_STEP_SUMMARY"
  SHELL
  abort('runtime capability gate must match the phased rollout policy exactly') unless script.strip == expected.strip
end

def assert_artifact_check(job, name, command)
  step = find_step(job, name)
  abort("#{name} must run the public artifact verification") unless step.fetch('run').strip == command
end

assert_android_build(
  job: build,
  name: 'Build hardware-assisted Personal release APK',
  mode: '--release',
  flavor: 'personal',
  capability: 'hardware-assisted',
)
assert_android_build(
  job: build,
  name: 'Build phone-only Robot release APK',
  mode: '--release',
  flavor: 'robot',
  capability: 'phone-only',
)
assert_phased_runtime_gate(build)
assert_artifact_check(
  build,
  'Verify public Android configuration artifacts',
  'python3 ../../.github/scripts/verify_public_config_artifacts.py --android --build-type release',
)

mobile = mobile_workflow.fetch('jobs').fetch('flutter-mobile')
assert_android_build(
  job: mobile,
  name: 'Build hardware-assisted Personal debug APK',
  mode: '--debug',
  flavor: 'personal',
  capability: 'hardware-assisted',
)
assert_android_build(
  job: mobile,
  name: 'Build phone-only Robot debug APK',
  mode: '--debug',
  flavor: 'robot',
  capability: 'phone-only',
)
assert_phased_runtime_gate(mobile)
assert_artifact_check(
  mobile,
  'Verify public Android configuration artifacts',
  'python3 ../../.github/scripts/verify_public_config_artifacts.py --android',
)
expected_build_output = '${{ steps.release.outputs.source_sha }}'
unless build.fetch('outputs').fetch('source_sha') == expected_build_output
  abort 'release-android must export the validated artifact source SHA'
end

release_step = build.fetch('steps').find { |step| step['id'] == 'release' }
abort 'release source validation step is missing' unless release_step
build_steps = build.fetch('steps')
build_checkout_index = build_steps.index { |step| step['name'] == 'Check out repository' }
policy_index = build_steps.index { |step| step['name'] == 'Verify immutable release source policy' }
java_index = build_steps.index { |step| step['name'] == 'Set up Java 17' }
flutter_index = build_steps.index { |step| step['name'] == 'Set up Flutter' }
release_index = build_steps.index(release_step)
abort 'release source validation must follow checkout' unless build_checkout_index && release_index && build_checkout_index < release_index
unless policy_index && java_index && flutter_index && build_checkout_index < policy_index && policy_index < java_index && policy_index < flutter_index
  abort 'immutable source policy must run after checkout and before toolchain setup'
end
build_checkout = build_steps.fetch(build_checkout_index)
abort 'build checkout must use the workflow dispatch or pushed-tag SHA' if build_checkout.fetch('with', {}).key?('ref')

expected_release_validation = <<~'SHELL'
  set -euo pipefail
  PUBSPEC_VERSION=$(awk '/^version: / { print $2; exit }' pubspec.yaml)
  SOURCE_SHA=$(git rev-parse HEAD)
  if [ "$SOURCE_SHA" != "$GITHUB_SHA" ]; then
    echo "Checked-out source $SOURCE_SHA does not match workflow source $GITHUB_SHA." >&2
    exit 1
  fi
  if [ "$GITHUB_EVENT_NAME" = "push" ]; then
    TAG="${GITHUB_REF_NAME}"
    VERSION="${TAG#android-v}"
    TAG_SHA=$(git rev-list -n 1 "$TAG")
    if [ "$TAG_SHA" != "$SOURCE_SHA" ]; then
      echo "Pushed tag $TAG resolves to $TAG_SHA instead of built source $SOURCE_SHA." >&2
      exit 1
    fi
  else
    VERSION="$REQUESTED_VERSION"
    TAG="android-v$VERSION"
    EXISTING=$(git ls-remote --tags origin "refs/tags/$TAG^{}" | cut -f1)
    if [ -z "$EXISTING" ]; then
      EXISTING=$(git ls-remote --tags origin "refs/tags/$TAG" | cut -f1)
    fi
    if [ -n "$EXISTING" ] && [ "$EXISTING" != "$SOURCE_SHA" ]; then
      echo "Tag $TAG already points to another commit." >&2
      exit 1
    fi
  fi
  if [ "$VERSION" != "$PUBSPEC_VERSION" ]; then
    echo "Requested version $VERSION does not match pubspec version $PUBSPEC_VERSION." >&2
    exit 1
  fi
  echo "version=$VERSION" >> "$GITHUB_OUTPUT"
  echo "tag=$TAG" >> "$GITHUB_OUTPUT"
  echo "source_sha=$SOURCE_SHA" >> "$GITHUB_OUTPUT"
SHELL
unless release_step.fetch('run').strip == expected_release_validation.strip
  warn 'Expected release source validation:'
  warn expected_release_validation
  warn 'Actual release source validation:'
  warn release_step.fetch('run')
  abort 'release source validation must match the immutable GITHUB_SHA policy exactly'
end

expected_publish_source = '${{ needs.release-android.outputs.source_sha }}'
expected_publish_tag = '${{ needs.release-android.outputs.tag }}'
publish_steps = publish.fetch('steps')
checkout_index = publish_steps.index { |step| step['name'] == 'Check out immutable release source' }
download_index = publish_steps.index { |step| step['name'] == 'Download signed release APKs' }
checksum_index = publish_steps.index { |step| step['name'] == 'Verify artifact checksums' }
create_index = publish_steps.index { |step| step['name'] == 'Create immutable release tag' }
release_index = publish_steps.index { |step| step['name'] == 'Publish GitHub release' }
verify_index = publish_steps.index { |step| step['name'] == 'Verify published tag matches artifact source' }
indices = [checkout_index, download_index, checksum_index, create_index, release_index, verify_index]
abort 'publish source-policy steps are missing' if indices.any?(&:nil?)
unless indices == indices.sort && indices.uniq.length == indices.length
  abort 'release tag must be created before assets are published and verified afterward'
end

checkout = publish_steps.fetch(checkout_index)
checksum = publish_steps.fetch(checksum_index)
create_tag = publish_steps.fetch(create_index)
release = publish_steps.fetch(release_index)
verify = publish_steps.fetch(verify_index)

abort 'publish checkout is not pinned to the artifact source' unless checkout.dig('with', 'ref') == expected_publish_source
unless checksum['working-directory'] == 'release-artifacts' && checksum.fetch('run').strip == "set -euo pipefail\nsha256sum -c ./*-SHA256SUMS.txt"
  abort 'downloaded release artifacts must pass their published checksum manifest before tag creation'
end
abort 'immutable tag creation is not pinned to the artifact source' unless create_tag.dig('env', 'EXPECTED_SOURCE_SHA') == expected_publish_source
abort 'immutable tag creation does not use the validated tag' unless create_tag.dig('env', 'TAG') == expected_publish_tag
abort 'release tag name is not the validated tag' unless release.dig('with', 'tag_name') == expected_publish_tag
abort 'release target_commitish is not pinned to the artifact source' unless release.dig('with', 'target_commitish') == expected_publish_source
abort 'published tag verification is not pinned to the artifact source' unless verify.dig('env', 'EXPECTED_SOURCE_SHA') == expected_publish_source
abort 'published tag verification does not use the validated tag' unless verify.dig('env', 'TAG') == expected_publish_tag

create_lines = create_tag.fetch('run').lines.map(&:strip)
[
  'CREATE_LOG="$RUNNER_TEMP/create-tag.log"',
  'if ! gh api --method POST "repos/$GITHUB_REPOSITORY/git/refs" \\',
  '--raw-field "ref=refs/tags/$TAG" \\',
  '--raw-field "sha=$EXPECTED_SOURCE_SHA" >/dev/null 2>"$CREATE_LOG"; then',
  'cat "$CREATE_LOG" >&2',
  'if [ "$TAG_SHA" != "$EXPECTED_SOURCE_SHA" ]; then',
].each do |required|
  abort "immutable tag creation is missing: #{required}" unless create_lines.include?(required)
end

# These complete, ordered data-flow assertions cover a dispatch from a
# non-default ref even if main advances: checkout defaults to GITHUB_SHA,
# validation exports that exact SHA, and checkout/tag creation/release all
# consume only that output. They also fail closed if Personal and Robot builds
# lose their explicit role/capability pairing. Any dependency on moving main is
# rejected above.
RUBY
