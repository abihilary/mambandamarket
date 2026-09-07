#!/usr/bin/env bash
# After a Play rollout is live: tell installed copies about the new build.
#
# Sets update.latest_build and update.latest_version in app_settings to the
# version in pubspec.yaml (or --build/--version), through the admin API — so
# the change is validated, stamped with who made it and written to the audit
# log, and no secret key ever has to sit on a laptop. Never touches
# update.mode, update.min_supported_build or update.blocks_at: those are
# decisions, not release bookkeeping.
#
#   tool/release_settings.sh [--dry-run] [--build N] [--version X.Y.Z] [--force]
#
# Needs curl and jq. Signs in with an admin email + password when
# MAMBANDA_ADMIN_JWT is not set; the password is read once and never stored.
set -euo pipefail
cd "$(dirname "$0")/.."

API=${MAMBANDA_API:-https://mambanda-api.blacksilvergroups.xyz}
SUPABASE_URL=${SUPABASE_URL:-https://vnmmqujmeoamuksgdoqd.supabase.co}
# Public key — the same one the app ships in lib/api/config.dart.
SUPABASE_KEY=${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_ImOqFcjPQ4I7uwlf5UHeOA_ykbjOkgz}

VER_LINE=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
VERSION=${VER_LINE%+*}
BUILD=${VER_LINE#*+}
DRY_RUN=0
FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --build) BUILD=$2; shift ;;
    --version) VERSION=$2; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v jq >/dev/null || { echo "jq is required (brew install jq)" >&2; exit 1; }

JWT=${MAMBANDA_ADMIN_JWT:-}
if [ -z "$JWT" ]; then
  read -rp "Admin email: " EMAIL
  read -rsp "Password: " PASSWORD; echo
  JWT=$(curl -fsS "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_KEY" -H "Content-Type: application/json" \
    -d "$(jq -n --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')" | jq -r '.access_token // empty')
  unset PASSWORD
  [ -n "$JWT" ] || { echo "Sign-in failed." >&2; exit 1; }
fi

CURRENT=$(curl -fsS "$API/admin/settings" -H "Authorization: Bearer $JWT")
CUR_BUILD=$(jq -r '.items[] | select(.key=="update.latest_build") | .value' <<<"$CURRENT")
CUR_VERSION=$(jq -r '.items[] | select(.key=="update.latest_version") | .value' <<<"$CURRENT")
MODE=$(jq -r '.items[] | select(.key=="update.mode") | .value' <<<"$CURRENT")

echo "update.latest_build:   ${CUR_BUILD:-?} -> $BUILD"
echo "update.latest_version: ${CUR_VERSION:-?} -> $VERSION"
echo "update.mode:           $MODE (unchanged)"

if [ "$FORCE" != 1 ] && [ -n "$CUR_BUILD" ] && [ "$CUR_BUILD" != null ] && [ "$BUILD" -lt "$CUR_BUILD" ]; then
  echo "Refusing to lower latest_build from $CUR_BUILD to $BUILD (use --force)." >&2
  exit 1
fi
if [ "$DRY_RUN" = 1 ]; then echo "(dry run — nothing written)"; exit 0; fi

patch() {
  curl -fsS -X PATCH "$API/admin/settings" \
    -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
    -d "{\"key\":\"$1\",\"value\":$2}" >/dev/null
}
patch update.latest_build "$BUILD"
patch update.latest_version "\"$VERSION\""
echo "==> app_settings updated."
if [ "$MODE" = off ]; then
  echo "note: update.mode is 'off', so nobody will be prompted until it is 'notify' or 'block' (Configuration in the admin panel)."
fi
