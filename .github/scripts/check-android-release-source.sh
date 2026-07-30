#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
WORKFLOW=${1:-"$ROOT_DIR/.github/workflows/android-release.yml"}

ruby - "$WORKFLOW" <<'RUBY'
require 'yaml'

workflow = YAML.load_file(ARGV.fetch(0))
jobs = workflow.fetch('jobs')
build = jobs.fetch('release-android')
publish = jobs.fetch('publish-release')

expected_build_output = '${{ steps.release.outputs.source_sha }}'
unless build.fetch('outputs').fetch('source_sha') == expected_build_output
  abort 'release-android must export the validated artifact source SHA'
end

release_step = build.fetch('steps').find { |step| step['id'] == 'release' }
abort 'release source validation step is missing' unless release_step
build_steps = build.fetch('steps')
build_checkout_index = build_steps.index { |step| step['name'] == 'Check out repository' }
release_index = build_steps.index(release_step)
abort 'release source validation must follow checkout' unless build_checkout_index && release_index && build_checkout_index < release_index
build_checkout = build_steps.fetch(build_checkout_index)
abort 'build checkout must use the workflow dispatch or pushed-tag SHA' if build_checkout.fetch('with', {}).key?('ref')

release_lines = release_step.fetch('run').lines.map(&:strip)
[
  'SOURCE_SHA=$(git rev-parse HEAD)',
  'if [ "$SOURCE_SHA" != "$GITHUB_SHA" ]; then',
  'echo "source_sha=$SOURCE_SHA" >> "$GITHUB_OUTPUT"',
].each do |required|
  abort "release source validation is missing: #{required}" unless release_lines.include?(required)
end

if release_lines.any? { |line| line.match?(/origin\/main|refs\/remotes\/origin\/main|refs\/heads\/main/) }
  abort 'manual Android release source must not follow or require moving main'
end

expected_publish_source = '${{ needs.release-android.outputs.source_sha }}'
expected_publish_tag = '${{ needs.release-android.outputs.tag }}'
publish_steps = publish.fetch('steps')
checkout_index = publish_steps.index { |step| step['name'] == 'Check out immutable release source' }
download_index = publish_steps.index { |step| step['name'] == 'Download signed release APKs' }
create_index = publish_steps.index { |step| step['name'] == 'Create immutable release tag' }
release_index = publish_steps.index { |step| step['name'] == 'Publish GitHub release' }
verify_index = publish_steps.index { |step| step['name'] == 'Verify published tag matches artifact source' }
indices = [checkout_index, download_index, create_index, release_index, verify_index]
abort 'publish source-policy steps are missing' if indices.any?(&:nil?)
unless indices == indices.sort && indices.uniq.length == indices.length
  abort 'release tag must be created before assets are published and verified afterward'
end

checkout = publish_steps.fetch(checkout_index)
create_tag = publish_steps.fetch(create_index)
release = publish_steps.fetch(release_index)
verify = publish_steps.fetch(verify_index)

abort 'publish checkout is not pinned to the artifact source' unless checkout.dig('with', 'ref') == expected_publish_source
abort 'immutable tag creation is not pinned to the artifact source' unless create_tag.dig('env', 'EXPECTED_SOURCE_SHA') == expected_publish_source
abort 'immutable tag creation does not use the validated tag' unless create_tag.dig('env', 'TAG') == expected_publish_tag
abort 'release tag name is not the validated tag' unless release.dig('with', 'tag_name') == expected_publish_tag
abort 'release target_commitish is not pinned to the artifact source' unless release.dig('with', 'target_commitish') == expected_publish_source
abort 'published tag verification is not pinned to the artifact source' unless verify.dig('env', 'EXPECTED_SOURCE_SHA') == expected_publish_source
abort 'published tag verification does not use the validated tag' unless verify.dig('env', 'TAG') == expected_publish_tag

create_lines = create_tag.fetch('run').lines.map(&:strip)
[
  'if ! gh api --method POST "repos/$GITHUB_REPOSITORY/git/refs" \\',
  '--raw-field "ref=refs/tags/$TAG" \\',
  '--raw-field "sha=$EXPECTED_SOURCE_SHA" >/dev/null 2>&1; then',
  'if [ "$TAG_SHA" != "$EXPECTED_SOURCE_SHA" ]; then',
].each do |required|
  abort "immutable tag creation is missing: #{required}" unless create_lines.include?(required)
end

# This complete, ordered data-flow assertion covers a dispatch from a
# non-default ref even if main advances: checkout defaults to GITHUB_SHA,
# validation exports that exact SHA, and checkout/tag creation/release all
# consume only that output. Any dependency on moving main is rejected above.
RUBY
