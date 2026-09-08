#!/bin/bash
# Compila, instala e abre o app no simulador. Sem argumento usa o iPhone 17 Pro.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-$HOME/Downloads/Xcode-beta.app/Contents/Developer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:-iPhone 17 Pro}"
BUNDLE=app.henrique.academia

xcodebuild build \
  -scheme Henrique \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$ROOT/.derived" \
  -skipMacroValidation \
  | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE"
xcrun simctl install "$DEVICE" "$ROOT/.derived/Build/Products/Debug-iphonesimulator/Henrique.app"
xcrun simctl launch --console-pty "$DEVICE" "$BUNDLE" &
sleep 4
xcrun simctl io "$DEVICE" screenshot "$ROOT/.derived/tela.png"
echo "captura em $ROOT/.derived/tela.png"
