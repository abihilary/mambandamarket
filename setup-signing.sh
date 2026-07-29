#!/bin/bash
# One-shot Android release signing setup.
#
# Creates the upload keystore and writes android/key.properties so
# `flutter build apk --release` produces a properly signed build.
# You only choose a password; everything else is pre-filled.

set -euo pipefail

KEYSTORE="$HOME/mambandamarket-upload.jks"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROPS="$PROJECT_DIR/android/key.properties"

if [ -f "$KEYSTORE" ]; then
  echo "A keystore already exists at:"
  echo "  $KEYSTORE"
  echo
  echo "Nothing changed. Delete that file first if you want to start over"
  echo "(only safe if the app has never been published with it)."
  exit 1
fi

cat <<'INTRO'
────────────────────────────────────────────────────────
 Mambanda Market — app signing setup
────────────────────────────────────────────────────────

You are about to choose ONE password. It protects the key that
signs your app.

  · There is no existing password — you are inventing it now.
  · Write it down somewhere safe. You need it for every future
    release, and it cannot be recovered.
  · Nothing is shown as you type. That is normal.

INTRO

read -r -s -p "Choose a password: " PW1; echo
read -r -s -p "Type it again:     " PW2; echo
echo

if [ -z "$PW1" ]; then
  echo "✗ Password cannot be empty. Nothing was created — run the script again."
  exit 1
fi
if [ "${#PW1}" -lt 6 ]; then
  echo "✗ Password must be at least 6 characters. Nothing was created — run the script again."
  exit 1
fi
if [ "$PW1" != "$PW2" ]; then
  echo "✗ The two passwords do not match. Nothing was created — run the script again."
  exit 1
fi

echo "Creating keystore…"
keytool -genkeypair \
  -keystore "$KEYSTORE" \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Mambanda Market, OU=Mobile, O=Mambanda Market, L=Douala, ST=Littoral, C=CM" \
  -storepass "$PW1" -keypass "$PW1" >/dev/null 2>&1

# key.properties holds the password in plain text, so keep it owner-only.
# It is git-ignored.
umask 077
cat > "$PROPS" <<EOF
storeFile=$KEYSTORE
storePassword=$PW1
keyPassword=$PW1
keyAlias=upload
EOF
chmod 600 "$PROPS"

echo
echo "✓ Done."
echo "    keystore : $KEYSTORE"
echo "    config   : $PROPS"
echo
echo "⚠  Back up the .jks file (cloud drive, password manager, USB)."
echo "   If you lose it, you can never update the app in place again."
echo
