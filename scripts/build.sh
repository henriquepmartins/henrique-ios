#!/bin/bash
# Compila o pacote para o simulador de iPhone. O DEVELOPER_DIR aponta para o
# Xcode beta enquanto ele não é o developer directory ativo do sistema; depois de
# `sudo xcode-select -s ~/Downloads/Xcode-beta.app` a linha vira redundante e
# pode sair.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-$HOME/Downloads/Xcode-beta.app/Contents/Developer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

xcodebuild build \
  -scheme Henrique-Package \
  -destination "$DESTINATION" \
  -derivedDataPath "$ROOT/.derived" \
  -skipMacroValidation \
  "$@" | grep -vE '^\s*$' | tail -40
