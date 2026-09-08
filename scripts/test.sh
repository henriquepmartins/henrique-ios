#!/bin/bash
# Roda a suíte do pacote. As de integração ficam de fora até você apontar o
# servidor:
#
#     bun run dev            # no repo do web
#     HENRIQUE_TEST_BASE_URL=http://localhost:3000 \
#     HENRIQUE_TEST_USERNAME=henrique HENRIQUE_TEST_PASSWORD=... ./scripts/test.sh
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-$HOME/Downloads/Xcode-beta.app/Contents/Developer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT/Packages/HenriqueKit"
swift test "$@"
