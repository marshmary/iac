#!/usr/bin/env bash
# az-container.sh — ensure a blob container exists on an Azurite-compatible
# endpoint (floci-az :4577) using nothing but curl + openssl.
#
# Why this exists: the azurerm provider only speaks the ARM resource plane,
# which no local emulator implements, so `azurerm_storage_container` cannot
# create the state container locally. The Blob data plane can — with SharedKey
# auth (2015-02-21 signature scheme), which is exactly what this script signs.
#
# Used by playground/up.sh and tests/t6-emulators.sh to seed the per-tier
# state containers (tfstate-01..04) before the first backend init.
#
# Usage: az-container.sh <base-url> <account> <key> <container>
#   base-url  e.g. http://localhost:4577   (no trailing slash)
#   account   devstoreaccount1 (floci-az / Azurite well-known account)
#   key       the matching well-known base64 account key
#   container 3-63 chars, lowercase alphanumerics + dash
#
# Exit 0 when the container exists afterwards (201 created / 409 already there).
set -euo pipefail

url="${1:?base url}"; acct="${2:?account}"; key="${3:?account key}"; ctr="${4:?container name}"

msver="2021-08-06"
d="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S GMT')"

# StringToSign (SharedKey, 2015-02-21): VERB + the 11 empty canonical header
# fields + canonicalized x-ms-* headers (sorted) + canonicalized resource
# (/account/container + query params sorted). No payload on a container PUT.
sts="$(printf 'PUT\n\n\n\n\n\n\n\n\n\n\n\nx-ms-date:%s\nx-ms-version:%s\n/%s/%s\nrestype:container' \
  "$d" "$msver" "$acct" "$ctr")"

# HMAC over the binary-decoded account key (hex form avoids null-byte issues
# on the openssl command line).
hexkey="$(printf '%s' "$key" | base64 -d | od -An -v -tx1 | tr -d ' \n')"
sig="$(printf '%s' "$sts" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$hexkey" -binary | base64 | tr -d '\n')"

body="$(mktemp)"
trap 'rm -f "$body"' EXIT
code="$(curl -s -o "$body" -w '%{http_code}' --max-time 10 -X PUT \
  -H "x-ms-date: $d" \
  -H "x-ms-version: $msver" \
  -H "Authorization: SharedKey $acct:$sig" \
  "$url/$acct/$ctr?restype=container")"

case "$code" in
  201) echo "container $ctr: created on $url" ;;
  409) echo "container $ctr: already exists on $url" ;;
  *)   echo "container $ctr: unexpected HTTP $code from $url:" >&2
       cat "$body" >&2
       exit 1 ;;
esac
