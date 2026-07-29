#!/usr/bin/env bash

set -Eeuo pipefail

WEB_ORIGIN="${WEB_ORIGIN:-https://dosey.dev}"
WWW_ORIGIN="${WWW_ORIGIN:-https://www.dosey.dev}"
APPWRITE_ENDPOINT="${APPWRITE_ENDPOINT:-https://api.dosey.dev/v1}"
APPWRITE_PREFLIGHT_ORIGIN="https://dosey.dev"
RETRY_COUNT="${WEB_SMOKE_RETRIES:-3}"
RETRY_DELAY="${WEB_SMOKE_RETRY_DELAY_SECONDS:-5}"
CONNECT_TIMEOUT="${WEB_SMOKE_CONNECT_TIMEOUT_SECONDS:-5}"
REQUEST_TIMEOUT="${WEB_SMOKE_REQUEST_TIMEOUT_SECONDS:-10}"
CERTIFICATE_TIMEOUT="${WEB_SMOKE_CERTIFICATE_TIMEOUT_SECONDS:-15}"

expected_apex="${WEB_ORIGIN%/}/"
web_host="${WEB_ORIGIN#https://}"
web_host="${web_host%%/*}"
http_origin="http://${WEB_ORIGIN#https://}"

fail() {
  printf '%s\n' "$1" >&2
  return 1
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  "$@" &
  local command_pid=$!
  (
    sleep_pid=''
    trap '
      if [[ -n "$sleep_pid" ]]; then
        kill -TERM "$sleep_pid" 2>/dev/null || true
        wait "$sleep_pid" 2>/dev/null || true
      fi
      exit 0
    ' TERM
    sleep "$timeout_seconds" &
    sleep_pid=$!
    wait "$sleep_pid"
    kill -TERM "$command_pid" 2>/dev/null || true
  ) &
  local timer_pid=$!
  local command_status=0

  wait "$command_pid" || command_status=$?
  kill -TERM "$timer_pid" 2>/dev/null || true
  wait "$timer_pid" 2>/dev/null || true
  return "$command_status"
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
  if ! headers="$(curl --silent --show-error --output /dev/null --dump-header - \
    --connect-timeout "$CONNECT_TIMEOUT" --max-time "$REQUEST_TIMEOUT" \
    --max-redirs 0 "$http_origin")"; then
    printf 'HTTP apex request details: url=%s status=request_failed\n' "$http_origin" >&2
    return 1
  fi
  status="$(awk '/^HTTP\// { code = $2 } END { print code }' <<< "$headers")"
  if [[ "$status" != 301 && "$status" != 302 && "$status" != 307 && "$status" != 308 ]]; then
    printf 'HTTP apex request details: url=%s status=%s\n' \
      "$http_origin" "${status:-missing}" >&2
    return 1
  fi
  location="$(header_value "$headers" location)"
  if [[ "$location" != "$expected_apex" ]]; then
    printf 'HTTP apex request details: url=%s status=%s redirect=%s expected=%s\n' \
      "$http_origin" "$status" "${location:-missing}" "$expected_apex" >&2
    return 1
  fi
}

check_https_pages() {
  local path status url
  for path in / /auth.html /manifest.json /flutter_bootstrap.js; do
    url="${WEB_ORIGIN%/}${path}"
    if ! status="$(curl --silent --show-error --fail --output /dev/null \
      --write-out '%{http_code}' --proto '=https' --tlsv1.2 \
      --connect-timeout "$CONNECT_TIMEOUT" --max-time "$REQUEST_TIMEOUT" \
      --max-redirs 0 "$url")"; then
      printf 'HTTPS page request details: url=%s status=%s\n' \
        "$url" "${status:-request_failed}" >&2
      return 1
    fi
    if [[ "$status" != 200 ]]; then
      printf 'HTTPS page request details: url=%s status=%s\n' "$url" "$status" >&2
      return 1
    fi
  done
}

check_www_redirect() {
  local status effective_url redirects
  local result
  if ! result="$(curl --silent --show-error --fail --proto '=https' --tlsv1.2 \
    --location --max-redirs 5 --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$REQUEST_TIMEOUT" --output /dev/null \
    --write-out '%{http_code} %{url_effective} %{num_redirects}' "$WWW_ORIGIN")"; then
    read -r status effective_url redirects <<< "$result"
    printf 'www request details: url=%s status=%s redirects=%s target=%s\n' \
      "$WWW_ORIGIN" "${status:-request_failed}" "${redirects:-missing}" \
      "${effective_url:-missing}" >&2
    return 1
  fi
  read -r status effective_url redirects <<< "$result"
  if [[ "$status" != 200 || "$redirects" -lt 1 || "$effective_url" != "$expected_apex" ]]; then
    printf 'www request details: url=%s status=%s redirects=%s target=%s expected=%s\n' \
      "$WWW_ORIGIN" "${status:-missing}" "${redirects:-missing}" \
      "${effective_url:-missing}" "$expected_apex" >&2
    return 1
  fi
}

check_certificate() {
  local certificate_details
  if ! certificate_details="$(
    run_with_timeout "$CERTIFICATE_TIMEOUT" openssl s_client \
      -connect "${web_host}:443" -servername "$web_host" \
      -verify_hostname "$web_host" -verify_return_error </dev/null 2>/dev/null |
      openssl x509 -noout -subject -enddate \
        -checkend $((14 * 24 * 60 * 60)) 2>&1
  )"; then
    certificate_details="${certificate_details//$'\n'/; }"
    printf 'HTTPS certificate details: host=%s observed=%s\n' \
      "$web_host" "${certificate_details:-unavailable_or_timeout}" >&2
    fail 'HTTPS certificate is not trusted or expires within 14 days'
  fi
}

check_appwrite_cors() {
  local headers status allow_origin allow_headers allow_methods url
  url="${APPWRITE_ENDPOINT%/}/account"
  if ! headers="$(curl --silent --show-error --output /dev/null --dump-header - \
    --request OPTIONS --proto '=https' --tlsv1.2 \
    --connect-timeout "$CONNECT_TIMEOUT" --max-time "$REQUEST_TIMEOUT" \
    --max-redirs 0 \
    --header "Origin: $APPWRITE_PREFLIGHT_ORIGIN" \
    --header 'Access-Control-Request-Method: POST' \
    --header 'Access-Control-Request-Headers: x-appwrite-project,content-type' \
    "$url")"; then
    printf 'Appwrite CORS details: url=%s status=request_failed\n' "$url" >&2
    fail 'Appwrite OPTIONS preflight failed'
  fi
  status="$(awk '/^HTTP\// { code = $2 } END { print code }' <<< "$headers")"
  if [[ ! "$status" =~ ^2[0-9][0-9]$ ]]; then
    printf 'Appwrite CORS details: url=%s status=%s\n' \
      "$url" "${status:-missing}" >&2
    fail 'Appwrite OPTIONS preflight did not return 2xx'
  fi
  allow_origin="$(header_value "$headers" access-control-allow-origin)"
  allow_headers="$(header_value "$headers" access-control-allow-headers | tr '[:upper:]' '[:lower:]')"
  allow_methods="$(header_value "$headers" access-control-allow-methods | tr '[:upper:]' '[:lower:]')"
  if [[ "$allow_origin" != "$APPWRITE_PREFLIGHT_ORIGIN" ]]; then
    printf 'Appwrite CORS details: url=%s origin=%s expected_origin=%s\n' \
      "$url" "${allow_origin:-missing}" "$APPWRITE_PREFLIGHT_ORIGIN" >&2
    return 1
  fi
  if [[ ",${allow_headers//[[:space:]]/}," != *",x-appwrite-project,"* ||
    ",${allow_headers//[[:space:]]/}," != *",content-type,"* ]]; then
    printf 'Appwrite CORS details: url=%s allow_headers=%s required=x-appwrite-project,content-type\n' \
      "$url" "${allow_headers:-missing}" >&2
    return 1
  fi
  if [[ ",${allow_methods//[[:space:]]/}," != *",post,"* ]]; then
    printf 'Appwrite CORS details: url=%s allow_methods=%s required=post\n' \
      "$url" "${allow_methods:-missing}" >&2
    return 1
  fi
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
