#!/bin/bash
# Roda a suíte com a toolchain das Command Line Tools, sem Xcode.
#
# Duas coisas faltam nesse ambiente e o script repõe as duas. O SwiftPM não
# procura o plugin de macros do Swift Testing, então o caminho vai explícito. E
# o binário de teste procura Testing.framework e lib_TestingInterop.dylib pelo
# @rpath, que o SIP impede de redirecionar por DYLD_FRAMEWORK_PATH, então os
# dois entram por link simbólico em caminhos que o dyld já tenta.
#
# Com o Xcode instalado nada disso é necessário: use `swift test`.
set -euo pipefail

DEVELOPER=/Library/Developer/CommandLineTools
PLUGINS="$DEVELOPER/usr/lib/swift/host/plugins/testing"
FRAMEWORKS="$DEVELOPER/Library/Developer/Frameworks"
INTEROP="$DEVELOPER/Library/Developer/usr/lib/lib_TestingInterop.dylib"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCTS="$ROOT/.build/out/Products/Debug"

swift build --build-tests -Xswiftc -plugin-path -Xswiftc "$PLUGINS"

mkdir -p "$PRODUCTS/PackageFrameworks"
for framework in "$FRAMEWORKS"/*.framework; do
  ln -sfn "$framework" "$PRODUCTS/PackageFrameworks/$(basename "$framework")"
done
ln -sfn "$INTEROP" "$PRODUCTS/lib_TestingInterop.dylib"

swift test --skip-build -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
