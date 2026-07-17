#!/usr/bin/env bash
# Build, Developer ID–sign, package, notarize, and staple MacinTalk for Gatekeeper.
#
# App signing uses xcodebuild -exportArchive with method=developer-id
# (supports cloud-managed Developer ID certificates via -allowProvisioningUpdates).
# DMG signing uses a local Developer ID Application identity when available;
# unsigned DMGs are still accepted by Apple's notary service.
#
# The app and the DMG are notarized as two separate submissions, and both get a
# stapled ticket. The app must be stapled before create_dmg copies it in: a DMG
# ticket does not travel with the app when a user drags it to /Applications, so
# an app-less-ticket only passes Gatekeeper while the machine can reach Apple.
# Stapling the app is what makes a first launch work offline.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEAM_ID="${TEAM_ID:-R58UQ3LPDX}"
BUNDLE_ID="${BUNDLE_ID:-com.macintalk.app}"
NOTARY_PROFILE="${NOTARY_PROFILE:-macintalk-notary}"
VERSION="${VERSION:-1.0}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/MacinTalk.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/build/export}"
DMG_DIR="${DMG_DIR:-$ROOT/build/dmg}"
APP_PATH="$EXPORT_PATH/MacinTalk.app"
DMG_PATH="$DMG_DIR/MacinTalk-${VERSION}.dmg"
PLIST="$ROOT/ExportOptions.plist"
SKIP_ARCHIVE="${SKIP_ARCHIVE:-0}"
# Set to an existing submission UUID to skip upload and only wait/staple/verify.
NOTARY_SUBMISSION_ID="${NOTARY_SUBMISSION_ID:-}"
# Set to 1 to skip notarization (export + DMG only); useful while Apple queues first-time analysis.
SKIP_NOTARY="${SKIP_NOTARY:-0}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

# Returns empty string when no local identity exists (cloud signing may still work).
find_developer_id_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -v team="$TEAM_ID" '
        /Developer ID Application/ && index($0, "(" team ")") {
          match($0, /"[^"]+"/)
          print substr($0, RSTART + 1, RLENGTH - 2)
          exit
        }
      '
}

verify_app_developer_id() {
  local app="$1"
  local info codesign_out

  log "Verifying Developer ID signature on ${app}"
  codesign_out="$(codesign -dv --verbose=4 "$app" 2>&1)" || die "codesign verification failed for ${app}"

  printf '%s\n' "$codesign_out" | grep -q "Developer ID Application" \
    || die "App is not signed with Developer ID Application. Export output:
${codesign_out}"

  if ! printf '%s\n' "$codesign_out" | grep -qi 'Timestamp='; then
    die "App signature is missing a secure timestamp:
${codesign_out}"
  fi
  if printf '%s\n' "$codesign_out" | grep -qi 'Timestamp=none'; then
    die "App signature has Timestamp=none (secure timestamp required):
${codesign_out}"
  fi

  info="$(codesign -dvv "$app" 2>&1 || true)"
  printf '%s\n' "$info" | grep -q "TeamIdentifier=${TEAM_ID}" \
    || die "App TeamIdentifier is not ${TEAM_ID}:
${info}"

  codesign --verify --deep --strict --verbose=2 "$app"
  log "App signature OK"
}

create_dmg() {
  local app="$1"
  local dmg="$2"
  local stage

  rm -rf "$DMG_DIR"
  mkdir -p "$DMG_DIR"
  stage="$(mktemp -d "${TMPDIR:-/tmp}/macintalk-dmg.XXXXXX")"

  ditto "$app" "$stage/MacinTalk.app"
  ln -s /Applications "$stage/Applications"

  rm -f "$dmg"
  hdiutil create \
    -volname "MacinTalk" \
    -srcfolder "$stage" \
    -ov \
    -format UDZO \
    "$dmg"

  rm -rf "$stage"
}

sign_dmg_if_possible() {
  local dmg="$1"
  local identity="$2"

  if [[ -z "$identity" ]]; then
    log "No local Developer ID identity for team ${TEAM_ID}; leaving DMG unsigned"
    log "(Apple notary accepts unsigned DMGs; the ticket covers the app inside.)"
    return 0
  fi

  log "Signing DMG with ${identity}"
  codesign \
    --force \
    --sign "$identity" \
    --timestamp \
    -i "${BUNDLE_ID}.dmg" \
    "$dmg"
  codesign --verify --verbose=2 "$dmg"
}

wait_for_notarization() {
  local submission_id="$1"
  local submit_out status
  local attempts=0
  local max_attempts="${NOTARY_MAX_ATTEMPTS:-60}"

  log "Waiting for notarization id=${submission_id}"
  status="In Progress"
  while (( attempts < max_attempts )); do
    submit_out="$(
      xcrun notarytool info "$submission_id" \
        --keychain-profile "$NOTARY_PROFILE" 2>&1
    )" || true
    status="$(printf '%s\n' "$submit_out" | awk '/status:/{print $2; exit}')"
    log "Notarization status=${status:-unknown} (attempt $((attempts + 1))/${max_attempts})"
    case "${status}" in
      Accepted|Invalid|Rejected) break ;;
    esac
    sleep 15
    attempts=$((attempts + 1))
  done

  if [[ "${status}" != "Accepted" ]]; then
    printf 'Notarization failed or still pending. Fetching log…\n' >&2
    xcrun notarytool log "$submission_id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    die "Notarization status was '${status:-unknown}', expected Accepted (id=${submission_id})"
  fi
}

submit_and_wait() {
  local path="$1"
  local submit_out submission_id

  log "Submitting ${path} for notarization (profile: ${NOTARY_PROFILE})"
  if ! submit_out="$(
    xcrun notarytool submit "$path" \
      --keychain-profile "$NOTARY_PROFILE" 2>&1
  )"; then
    printf '%s\n' "$submit_out" >&2
    die "notarytool submit failed for ${path}"
  fi

  printf '%s\n' "$submit_out"
  submission_id="$(printf '%s\n' "$submit_out" | awk '/id:/{print $2; exit}')"
  [[ -n "$submission_id" ]] || die "Could not parse notarization submission id for ${path}"

  wait_for_notarization "$submission_id"
}

# notarytool only accepts zip/pkg/dmg, so the bundle ships as a zip. The ticket
# is stapled to the original bundle, not the zip, which is then discarded.
notarize_and_staple_app() {
  local app="$1"
  local stage zip

  stage="$(mktemp -d "${TMPDIR:-/tmp}/macintalk-appzip.XXXXXX")"
  zip="$stage/MacinTalk.zip"

  log "Zipping app for notarization"
  ditto -c -k --keepParent "$app" "$zip"

  submit_and_wait "$zip"
  rm -rf "$stage"

  log "Stapling notarization ticket to app"
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
}

submit_and_staple() {
  local dmg="$1"

  if [[ -n "$NOTARY_SUBMISSION_ID" ]]; then
    log "Resuming existing notarization submission ${NOTARY_SUBMISSION_ID}"
    wait_for_notarization "$NOTARY_SUBMISSION_ID"
  else
    submit_and_wait "$dmg"
  fi

  log "Stapling notarization ticket to DMG"
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
}

final_assessments() {
  local app="$1"
  local dmg="$2"

  log "Final codesign / stapler / Gatekeeper checks"
  codesign --verify --deep --strict --verbose=2 "$app"
  xcrun stapler validate "$app" \
    || die "App has no stapled ticket; offline first launch would fail"
  xcrun stapler validate "$dmg"

  # App execute assessment (requires notarized Developer ID).
  spctl --assess --type execute --verbose=4 "$app" \
    || die "spctl execute assessment failed for app"

  # DMG open assessment: only meaningful when the DMG itself is signed.
  if codesign -dv "$dmg" >/dev/null 2>&1; then
    codesign --verify --verbose=2 "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose=4 "$dmg" \
      || die "spctl open assessment failed for DMG"
  else
    log "DMG is unsigned; skipping spctl open assessment (app notarization still applies)"
  fi

  log "Distributable ready: ${dmg}"
}

main() {
  local identity

  require_cmd xcodebuild
  require_cmd codesign
  require_cmd hdiutil
  require_cmd ditto
  require_cmd security
  require_cmd spctl

  [[ -f "$PLIST" ]] || die "Missing export options: $PLIST"

  # Staple-only resume: wait for an existing submission and staple the existing DMG.
  # This only staples the DMG. The app copy already sealed inside it cannot be
  # stapled after the fact, so the result is online-only; rerun with
  # FORCE_REBUILD=1 for a DMG whose app launches offline.
  if [[ -n "$NOTARY_SUBMISSION_ID" && -f "$DMG_PATH" && "${FORCE_REBUILD:-0}" != "1" ]]; then
    log "Staple-only mode for existing ${DMG_PATH}"
    wait_for_notarization "$NOTARY_SUBMISSION_ID"
    log "Stapling notarization ticket to DMG"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    log "WARNING: the app inside this DMG has no stapled ticket."
    log "         Gatekeeper will pass online but a first launch offline will fail."
    log "         Rerun with FORCE_REBUILD=1 to produce an offline-safe DMG."
    if [[ -d "$APP_PATH" ]]; then
      codesign --verify --deep --strict --verbose=2 "$APP_PATH"
      spctl --assess --type execute --verbose=4 "$APP_PATH" \
        || die "spctl execute assessment failed for app"
    else
      log "App export missing; DMG stapled. Re-export to run full Gatekeeper checks."
    fi
    exit 0
  fi

  identity="$(find_developer_id_identity || true)"
  if [[ -n "$identity" ]]; then
    log "Local Developer ID identity available: ${identity}"
  else
    log "No local Developer ID identity for ${TEAM_ID}; relying on Xcode cloud signing for the app"
  fi

  if [[ "$SKIP_ARCHIVE" != "1" ]]; then
    log "Archiving Release build"
    mkdir -p "$(dirname "$ARCHIVE_PATH")"
    xcodebuild \
      -scheme MacinTalk \
      -configuration Release \
      -destination 'generic/platform=macOS' \
      -archivePath "$ARCHIVE_PATH" \
      archive \
      DEVELOPMENT_TEAM="$TEAM_ID"
  else
    [[ -d "$ARCHIVE_PATH" ]] || die "Archive not found: $ARCHIVE_PATH (unset SKIP_ARCHIVE to create it)"
  fi

  log "Exporting Developer ID–signed app"
  rm -rf "$EXPORT_PATH"
  mkdir -p "$EXPORT_PATH"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$PLIST" \
    -allowProvisioningUpdates

  [[ -d "$APP_PATH" ]] || die "Export did not produce ${APP_PATH}"
  verify_app_developer_id "$APP_PATH"

  if [[ "$SKIP_NOTARY" != "1" ]]; then
    notarize_and_staple_app "$APP_PATH"
  else
    log "SKIP_NOTARY=1 — app left unstapled (offline first launch will fail)"
  fi

  log "Creating read-only DMG"
  create_dmg "$APP_PATH" "$DMG_PATH"
  sign_dmg_if_possible "$DMG_PATH" "$identity"

  if [[ "$SKIP_NOTARY" == "1" ]]; then
    log "SKIP_NOTARY=1 — package ready without waiting on Apple notary"
    log "Track submissions with: xcrun notarytool history --keychain-profile ${NOTARY_PROFILE}"
    log "When Accepted, finish with:"
    log "  NOTARY_SUBMISSION_ID=<id> ./scripts/export-app.sh"
    log "Distributable (pending notarization): ${DMG_PATH}"
    exit 0
  fi

  submit_and_staple "$DMG_PATH"
  final_assessments "$APP_PATH" "$DMG_PATH"
}

main "$@"
