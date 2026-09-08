#!/bin/bash
# Roda a suíte do pacote. Por padrão no macOS, que é rápido. Com `ios` roda no
# simulador, que é onde o App Transport Security vale e onde uma chamada em
# texto puro pode ser barrada sem o macOS reclamar.
#
#     ./scripts/test.sh
#     ./scripts/test.sh ios
#
# As de integração ficam de fora até você apontar o servidor:
#
#     bun run dev            # no repo do web
#     HENRIQUE_TEST_BASE_URL=http://localhost:3000 \
#     HENRIQUE_TEST_USERNAME=henrique HENRIQUE_TEST_PASSWORD=... ./scripts/test.sh ios
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-$HOME/Downloads/Xcode-beta.app/Contents/Developer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/Packages/HenriqueKit"

if [ "${1:-}" != "ios" ]; then
  swift test "$@"
  exit
fi
shift

DEVICE="${1:-iPhone 17 Pro}"

# O xcodebuild não repassa o ambiente para o processo de teste dentro do
# simulador. O prefixo TEST_RUNNER_ é como ele encaminha cada variável.
for name in HENRIQUE_TEST_BASE_URL HENRIQUE_TEST_USERNAME HENRIQUE_TEST_PASSWORD; do
  value="${!name:-}"
  [ -n "$value" ] && export "TEST_RUNNER_$name=$value"
done

xcodebuild test \
  -scheme Henrique-Package \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$ROOT/.derived" \
  | grep -E '✔|✘|✗|➜ (Suite|Test)|Test run with|error:|TEST (SUCCEEDED|FAILED)'
