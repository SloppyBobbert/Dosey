#!/usr/bin/env bash

set -Eeuo pipefail

WEB_ORIGIN="${WEB_ORIGIN:-https://dosey.dev}"
WWW_ORIGIN="${WWW_ORIGIN:-https://www.dosey.dev}"
APPWRITE_ENDPOINT="${APPWRITE_ENDPOINT:-https://api.dosey.dev/v1}"
APPWRITE_PREFLIGHT_ORIGIN="https://dosey.dev"
RETRY_COUNT="${WEB_SMOKE_RETRIES:-6}"
RETRY_DELAY="${WEB_SMOKE_RETRY_DELAY_SECONDS:-10}"

expected_apex="${WEB_ORIGIN%/}/"
web_host="${WEB_ORIGIN#https://}"
web_host="${web_host%%/*}"
http_origin="http://${WEB_ORIGIN#https://}"

fail() {
  printf '%s\n' "$1" >&2
  return 1
}

header_value() {
  local headers="$1"
  local header_name="$2"
  awk -v name="$header_name" '
    BEGIN { IGNORECASE = 1 }
    tolower($0) ~ "^" tolower(name) ":" {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/\r$/, "")
      print
      exit
    }
  ' <<< "$headers"
}

check_http_redirect() {
  local headers status location
  headers="$(curl --silent --show-error --output /dev/null --dump-header - \
    --connect-timeout 10 --max-time 20 --max-redirs 0 "$http_origin")" || return 1
  status="$(awk '/^HTTP\// { code = $2 } END { print code }' <<< "$headers")"
  [[ "$status" == 301 || "$status" == 302 || "$status" == 307 || "$status" == 308 ]] || \
    return 1
  location="$(header_value "$headers" location)"
  [[ "$location" == "$expected_apex" ]] || return 1
}

check_https_pages() {
  local path status
  for path in / /auth.html /manifest.json /flutter_bootstrap.js; do
    status="$(curl --silent --show-error --fail --output /dev/null \
      --write-out '%{http_code}' --proto '=https' --tlsv1.2 \
      --connect-timeout 10 --max-time 20 --max-redirs 0 \
      "${WEB_ORIGIN%/}${path}")" || return 1
    [[ "$status" == 200 ]] || return 1
  done
}

check_www_redirect() {
  local effective_url redirects
  local result
  result="$(curl --silent --show-error --fail --proto '=https' --tlsv1.2 --location --max-redirs 5 \
    --connect-timeout 10 --max-time 20 --output /dev/null \
    --write-out '%{url_effective} %{num_redirects}' "$WWW_ORIGIN")" || return 1
  read -r effective_url redirects <<< "$result"
  [[ "$redirects" -ge 1 ]] || return 1
  [[ "$effective_url" == "$expected_apex" ]] || return 1
}

check_certificate() {
  openssl s_client -connect "${web_host}:443" -servername "$web_host" \
    -verify_hostname "$web_host" -verify_return_error </dev/null 2>/dev/null |
    openssl x509 -noout -checkend $((14 * 24 * 60 * 60)) >/dev/null ||
    fail 'HTTPS certificate is not trusted or expires within 14 days'
}

check_appwrite_cors() {
  local headers status allow_origin allow_headers allow_methods
  headers="$(curl --silent --show-error --output /dev/null --dump-header - \
    --request OPTIONS --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 20 \
    --max-redirs 0 \
    --header "Origin: $APPWRITE_PREFLIGHT_ORIGIN" \
    --header 'Access-Control-Request-Method: POST' \
    --header 'Access-Control-Request-Headers: x-appwrite-project,content-type' \
    "${APPWRITE_ENDPOINT%/}/account")" || fail 'Appwrite OPTIONS preflight failed'
  status="$(awk '/^HTTP\// { code = $2 } END { print code }' <<< "$headers")"
  [[ "$status" =~ ^2[0-9][0-9]$ ]] || fail 'Appwrite OPTIONS preflight did not return 2xx'
  allow_origin="$(header_value "$headers" access-control-allow-origin)"
  allow_headers="$(header_value "$headers" access-control-allow-headers | tr '[:upper:]' '[:lower:]')"
  allow_methods="$(header_value "$headers" access-control-allow-methods | tr '[:upper:]' '[:lower:]')"
  [[ "$allow_origin" == "$APPWRITE_PREFLIGHT_ORIGIN" ]] || return 1
  [[ ",${allow_headers//[[:space:]]/}," == *",x-appwrite-project,"* ]] || return 1
  [[ ",${allow_headers//[[:space:]]/}," == *",content-type,"* ]] || return 1
  [[ ",${allow_methods//[[:space:]]/}," == *",post,"* ]] || return 1
}

check_once() {
  check_http_redirect || { printf 'HTTP apex check failed\n' >&2; return 1; }
  check_https_pages || { printf 'HTTPS page check failed\n' >&2; return 1; }
  check_www_redirect || { printf 'www redirect check failed\n' >&2; return 1; }
  check_certificate || { printf 'certificate check failed\n' >&2; return 1; }
  check_appwrite_cors || { printf 'Appwrite CORS check failed\n' >&2; return 1; }
}

for ((attempt = 1; attempt <= RETRY_COUNT; attempt++)); do
  printf 'Production smoke check (%d/%d)\n' "$attempt" "$RETRY_COUNT"
  if check_once; then
    printf 'Production smoke check passed\n'
    exit 0
  fi
  if (( attempt < RETRY_COUNT )); then
    sleep "$RETRY_DELAY"
  fi
done

printf 'Production smoke check failed after %d attempts\n' "$RETRY_COUNT" >&2
exit 1
