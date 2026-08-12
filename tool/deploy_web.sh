#!/usr/bin/env bash
# Build the Flutter web app and publish it as a static site.
#
# The build happens here rather than on Vercel because Vercel has no Flutter
# toolchain — installing the SDK on every deploy would be slow and one more
# thing to break. What gets uploaded is exactly what was built and tested
# locally.
#
# Usage:  tool/deploy_web.sh [--preview]
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT=mambandamarket-app
TARGET=${1:-}

echo "==> Building web release"
flutter build web --release

# vercel.json lives in tool/ because build/web is regenerated every time.
cp tool/web_vercel.json build/web/vercel.json

echo "==> Deploying to $PROJECT"
cd build/web
if [ "$TARGET" = "--preview" ]; then
  npx vercel deploy --yes --project "$PROJECT"
else
  npx vercel deploy --prod --yes --project "$PROJECT"
fi
