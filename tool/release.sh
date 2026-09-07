#!/usr/bin/env bash
# Build the Play bundle for the version in pubspec.yaml and stage it on the
# Desktop, with a release-notes stub if there is none yet.
#
#   tool/release.sh
#
# Then upload the .aab in Play Console, roll out, and once the rollout is live
# run tool/release_settings.sh so installed copies are told about it.
set -euo pipefail
cd "$(dirname "$0")/.."

VER_LINE=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')   # e.g. 1.0.25+29
VERSION=${VER_LINE%+*}
BUILD=${VER_LINE#*+}

# build.gradle.kts falls back to the debug key when key.properties is missing,
# and Play rejects a debug-signed bundle after wasting a full build's time.
if [ ! -f android/key.properties ]; then
  echo "android/key.properties is missing — the bundle would be debug-signed. Aborting." >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "warning: the tree has uncommitted changes; the bundle will not match any commit." >&2
fi

echo "==> Building appbundle $VERSION (build $BUILD)"
flutter build appbundle --release
AAB=build/app/outputs/bundle/release/app-release.aab

# The bundle's manifest is protobuf, so the version string is checked as a
# string; bundletool gives the exact fields when it is installed.
if ! unzip -p "$AAB" base/manifest/AndroidManifest.xml | strings | grep -q "$VERSION"; then
  echo "The bundle manifest does not carry $VERSION — refusing to stage it." >&2
  exit 1
fi
if command -v bundletool >/dev/null 2>&1; then
  bundletool dump manifest --bundle "$AAB" | grep -E 'versionCode|versionName' || true
fi

OUT="$HOME/Desktop/mambandamarket-$VERSION-$BUILD.aab"
cp "$AAB" "$OUT"

NOTES="docs/release-notes-$VERSION.md"
if [ ! -f "$NOTES" ]; then
  cat > "$NOTES" <<EOF
# $VERSION (build $BUILD)

Play Console → "What's new". Each block is under Google's 500-character
limit. Paste per language.

## en-US

## fr-FR

## de-DE
EOF
  echo "==> Wrote a release-notes stub: $NOTES"
fi

cat <<EOF

==> Staged: $OUT

Next:
  1. Fill in $NOTES (each block under 500 characters).
  2. Play Console → Test and release → (track) → Create release → upload the .aab,
     paste the notes, roll out.
  3. Once the rollout is live:
       tool/release_settings.sh
     (points update.latest_build=$BUILD / latest_version=$VERSION at this build, so
      installed copies are prompted).
  4. git tag v$VERSION && git push --tags
EOF
