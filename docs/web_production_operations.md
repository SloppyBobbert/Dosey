# Web Production Operations

## Service boundary

GitHub Pages hosts the Dosey web frontend. Appwrite provides authentication and
API services at `https://api.dosey.dev/v1`. The production frontend is served at
`https://dosey.dev`; `https://www.dosey.dev` must redirect to the apex URL.

Production deployment is manual. The `production` environment protects the
build with its configured gates, and the `github-pages` environment protects
the Pages deployment. The workflow accepts only a full SHA that equals the
current `origin/main` SHA. Do not deploy an arbitrary historical SHA.

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
