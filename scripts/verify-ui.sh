#!/bin/bash
# Sobe o banco e o servidor de teste, instala o app limpo no simulador e roda o
# fluxo de UI que tira as capturas. O servidor de teste fica na 3001 porque a 3000
# costuma ser o dev server ligado no banco de produção; o build daqui aponta para
# a 3001. ONLY=<teste> roda só aquele método do alvo Drive.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="${WEB:-/Users/henriquepereiramartins/code/personal/projects/h&nrique}"
DEVICE="${DEVICE:-iPhone 17}"
BUNDLE=app.henrique.academia
CREDENTIALS="$HOME/.config/henrique/test-credentials"
STAMP="$(date +%Y%m%d-%H%M%S)"
SHOTS="$ROOT/output/verify/$STAMP"
DERIVED="$ROOT/.derived/verify"
PORT="${DEV_LOCAL_PORT:-3001}"
export DEV_LOCAL_PORT="$PORT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-$HOME/Downloads/Xcode-beta.app/Contents/Developer}"
if [ ! -d "$DEVELOPER_DIR" ]; then unset DEVELOPER_DIR; fi

"$WEB/scripts/dev-local.sh" reset
"$WEB/scripts/dev-local.sh" up
# shellcheck disable=SC1090
source "$CREDENTIALS"
trap '"$WEB/scripts/dev-local.sh" down' EXIT

mkdir -p "$SHOTS"

# O app precisa da assinatura ad hoc do simulador: sem application-identifier
# o chaveiro recusa gravar a sessão (-34018) e o login cai em "sessão expirou".
xcodebuild build \
  -project "$ROOT/Henrique.xcodeproj" \
  -scheme Henrique \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  -skipMacroValidation \
  HENRIQUE_API_BASE_URL="http://localhost:$PORT" \
  | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE"
xcrun simctl uninstall "$DEVICE" "$BUNDLE" 2>/dev/null || true
# A sessão fica no chaveiro do simulador e sobrevive à desinstalação.
xcrun simctl keychain "$DEVICE" reset
xcrun simctl install "$DEVICE" "$DERIVED/Build/Products/Debug-iphonesimulator/Henrique.app"

(cd "$ROOT/UITests" && xcodegen generate --quiet)

ONLY_ARGS=()
if [ -n "${ONLY:-}" ]; then ONLY_ARGS=(-only-testing "Drive/FluxoDrive/$ONLY"); fi

# As TEST_RUNNER_* só chegam ao runner pelo ambiente do xcodebuild, não como
# build setting na linha de comando.
set +e
TEST_RUNNER_HENRIQUE_TEST_USERNAME="$HENRIQUE_TEST_USERNAME" \
TEST_RUNNER_HENRIQUE_TEST_PASSWORD="$HENRIQUE_TEST_PASSWORD" \
TEST_RUNNER_HENRIQUE_SHOTS="$SHOTS" \
xcodebuild test \
  -project "$ROOT/UITests/UIDrive.xcodeproj" \
  -scheme Drive \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED/uidrive" \
  -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  -collect-test-diagnostics never \
  ${ONLY_ARGS[@]+"${ONLY_ARGS[@]}"} \
  2>&1 | grep -E 'error:|failed|passed|Executed|TEST (SUCCEEDED|FAILED)|XCTAssert' | grep -v "HENRIQUE_TEST_PASSWORD"
STATUS=${PIPESTATUS[0]}
set -e

echo "capturas em $SHOTS"
ls "$SHOTS"
if [ "$STATUS" -eq 0 ]; then echo "resultado: passou"; else echo "resultado: falhou ($STATUS)"; fi
exit "$STATUS"
