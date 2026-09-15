#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${DEVELOPER_DIR:-}" && -d "$HOME/Downloads/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer"
fi

DERIVED="$ROOT/.derived/iphone-release"
OUTPUT="$ROOT/output"
mkdir -p "$OUTPUT"
STAGING="$(mktemp -d "$OUTPUT/.package-ipa.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

# O AltStore assina o IPA durante a instalação no iPhone.
xcodebuild build \
  -project "$ROOT/Henrique.xcodeproj" \
  -scheme Henrique \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO

APP="$DERIVED/Build/Products/Release-iphoneos/Henrique.app"
PLIST="$APP/Info.plist"
API_URL="$(/usr/libexec/PlistBuddy -c 'Print :HenriqueAPIBaseURL' "$PLIST")"
MIN_IOS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST")"
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
ARCHITECTURES="$(lipo -archs "$APP/$EXECUTABLE")"

if [[ "$API_URL" != 'https://hnrq.vercel.app' || "$MIN_IOS" != '26.0' || "$ARCHITECTURES" != 'arm64' ]]; then
  printf 'O build não corresponde à configuração esperada. API=%s iOS=%s arquitetura=%s\n' "$API_URL" "$MIN_IOS" "$ARCHITECTURES" >&2
  exit 1
fi

mkdir "$STAGING/Payload"
ditto "$APP" "$STAGING/Payload/Henrique.app"
ditto -c -k --norsrc --keepParent "$STAGING/Payload" "$STAGING/Henrique.ipa"
unzip -tq "$STAGING/Henrique.ipa"
mv -f "$STAGING/Henrique.ipa" "$OUTPUT/Henrique.ipa"
printf '\nIPA gerado em %s\nAPI %s\niOS mínimo %s\nArquitetura %s\n' "$OUTPUT/Henrique.ipa" "$API_URL" "$MIN_IOS" "$ARCHITECTURES"
