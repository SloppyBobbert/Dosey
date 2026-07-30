# Web Production Operations

## Service boundary

GitHub Pages hosts the Dosey web frontend. Appwrite provides authentication and
API services at `https://api.dosey.dev/v1`. The production frontend is served at
`https://dosey.dev`; `https://www.dosey.dev` must redirect to the apex URL.

Production deployment is manual. The `production` environment protects the
build with its configured gates, and the `github-pages` environment protects
the Pages deployment. The workflow accepts only a full SHA that equals the
current `origin/main` SHA. Do not deploy an arbitrary historical SHA.

## Shared release evidence

Qualify one immutable commit. Mobile CI, Web Preview CI, applicable Appwrite
Backend CI, signed Android artifacts, production deployment, and live
qualification notes must identify the same 40-character source SHA. Do not
combine evidence from different commits.

Web Preview CI builds both an auth-disabled preview and an auth-enabled preview.
The auth-enabled build uses non-secret, non-production placeholders for the
Appwrite project and household management Function IDs, plus the exact public
medication-sync IDs qualified for deployment. It does not need repository
secrets or contact Appwrite. Both artifacts must contain the required static
files and must not contain `.env` files. Before the caregiver consumer source set
lands, Web Preview CI records an explicit pre-consumer skip only when every
integration indicator is absent. Partial source/configuration presence fails.
Once the set is complete, CI verifies both exact values reached the compiled
artifact and runs focused tests proving the web factory creates and invokes the
real Appwrite adapter. Staging and production require both live Function IDs
before building; missing either ID is a gate failure. Mobile builds may omit both
IDs to keep sync honestly disabled, but the shared environment action rejects a
partial pair.
Configure the pair as the GitHub Actions repository or protected-environment
variables `APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID` and
`APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID`; these are public Function IDs, not
API keys or session credentials. Staging and production must set them to the
exact deployed IDs `medication-sync-push-v1` and `medication-sync-pull-v1`,
respectively; an unsuffixed, missing, or mismatched value is a gate failure.
The same staging and production builds require the public household management
IDs for create-robot, create-household-invitation,
accept-household-invitation, and remove-household-member. Pairing, claim, and
get-mounted-robot IDs are outside the caregiver web build boundary.

A staging deployment may be activated only by supplying both its deployment ID
and the successful upload-mode workflow run ID that created it. The activation
workflow requires a matching, unexpired gated-evidence artifact from the same
workflow revision. If `main` advances, upload a fresh staging deployment rather
than activating evidence from the older revision.

Changes under `backend/appwrite/` require Appwrite Backend CI evidence for
`npm ci`, `npm test`, `npm run typecheck`, and `npm run build`. Unit tests do not
replace live authorization qualification in an isolated Appwrite project.

Android Release reruns locked dependency resolution, Drift generation
verification, formatting, analysis, all Flutter tests, and the focused runtime
capability contract tests before reading signing secrets. Personal artifacts
must explicitly use `DOSEY_RUNTIME_CAPABILITY=hardware-assisted`; hardwareless
Robot MVP artifacts must explicitly use `DOSEY_RUNTIME_CAPABILITY=phone-only`.
Any separate Robot hardware bench artifact must explicitly use
`hardware-assisted` and must not replace or be labeled as the phone-only MVP
artifact. Treat missing or invalid capability values as a release-gate failure;
never rely on a default or fallback in a qualified build. Signing credentials
are scoped only to signing and build steps. The release workflow records the
source SHA and signer fingerprint and publishes a SHA-256 checksum file with the
Personal and Robot APKs. Compare those values with the qualification record
before installing or publishing the artifacts. A manual dispatch may select a
non-default ref, but the workflow pins the release tag to the exact built
`GITHUB_SHA` and verifies the published tag resolves to that artifact source;
an advance of `main` cannot retarget an in-flight release.

The generated Android `.env` contains public Appwrite configuration only. Never
add API keys, pairing HMAC secrets, session credentials, or other server secrets.
Current Android clients still use legacy Team-backed mounted restoration and do
not consume `APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID`; do not qualify or roll out
secure mounted access until a supported client passes that contract, and never
dual-write mounted accounts into Teams.

## Normal operation

- Run **Web Production Pages** manually with the current full `main` SHA.
- Confirm the build, `production` environment, Pages deployment, and post-deploy
  verification jobs pass.
- The scheduled **Web Production Smoke** workflow runs every six hours at 17
  minutes past the hour. Run it manually after an incident or when checking a
  suspected CDN, DNS, TLS, or CORS issue.
- The smoke check covers the apex redirect, required frontend files, the `www`
  redirect, certificate expiry, and the Appwrite OPTIONS CORS response.

## Incident triage

1. Open the latest production deployment and smoke-check summaries. Record the
   failing URL, status, redirect target, or CORS condition.
2. If only one static file fails, compare the deployed artifact and the selected
   current-main SHA. Allow for the checker retry window after a deployment.
3. Check DNS resolution and redirect behavior for both apex and `www` without
   changing records during the incident.
4. Check the certificate chain and expiry for `dosey.dev`.
5. Check Appwrite CORS for origin `https://dosey.dev`, the
   `x-appwrite-project` and `content-type` request headers, and the `POST`
   method. Keep Appwrite configuration changes separate from frontend rollback
   decisions.
6. If the issue is not explained by propagation, open the relevant workflow
   logs and the change that introduced it. Do not change staging while handling
   a production incident; staging remains independent.

## Safe rollback

Rollback by reverting the bad change through a pull request. After that revert
merges, read the new current `main` SHA and run **Web Production Pages** with
that exact 40-character SHA. The workflow rechecks that the checked-out commit
equals the current `origin/main`; this exact-main invariant must remain in
place. Do not deploy an arbitrary historical SHA or bypass the environment
gates.

If the failure is external to the frontend, keep the deployment unchanged and
escalate through the relevant GitHub Pages, DNS/TLS, or Appwrite owner. Do not
mutate cloud state as an emergency shortcut.

For Appwrite rollback, stop new claims or invitations if necessary, preserve
server-only records, and forward-deploy the prior secure Function implementation.
The legacy Team-writing claim path is not a rollback target. For Android, publish
a forward fix with a higher version and use the verified logical backup/restore
path; do not rely on APK or database downgrade.
