#!/bin/bash
# Compila, instala e abre o app no simulador. Sem argumento usa o iPhone 17 Pro.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-$HOME/Downloads/Xcode-beta.app/Contents/Developer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:-iPhone 17 Pro}"
BUNDLE=app.henrique.academia

# O build de Debug aponta para o servidor local. Sem ele no ar o app abre e
# falha no login, e a tela só diz que não falou com o servidor. Melhor avisar
# aqui, antes de instalar.
API="$(sed -n 's/.*HENRIQUE_API_BASE_URL = "\(.*\)";/\1/p' "$ROOT/Henrique.xcodeproj/project.pbxproj" | head -1)"
if [ -n "$API" ] && ! curl -sf -o /dev/null -m 3 "$API" 2>/dev/null; then
  echo "aviso: $API não respondeu. Rode 'bun run dev' no repo do web ou o login vai falhar."
fi

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
# Com 4s a captura pegava a tela ainda em branco do lançamento.
sleep 8
xcrun simctl io "$DEVICE" screenshot "$ROOT/.derived/tela.png"
echo "captura em $ROOT/.derived/tela.png"
