#!/bin/bash
# Compila o working tree em Debug e instala no iPhone físico via Wi-Fi, sem cabo.
# Uso iterativo local. Para o build publicado vale scripts/push-to-iphone.sh.
#
# O Debug do simulador aponta para http://localhost:3000. No aparelho físico
# localhost é o próprio iPhone, e o IP do Mac só existe dentro de casa: o app
# sai pela porta com você e para de salvar série na academia. Então o padrão
# aqui é a Vercel, e o servidor do Mac entra por fora quando você quiser:
#
#   ./scripts/run-iphone.sh
#   HENRIQUE_API_BASE_URL=http://192.168.1.10:3000 ./scripts/run-iphone.sh
#
# Pré-requisitos, uma vez só:
# 1. iPhone ligado ao Mac por cabo, confiar no computador, Modo de Desenvolvedor.
# 2. No Xcode, janela Devices and Simulators, marcar CONNECT VIA NETWORK.
# 3. Mac e iPhone na mesma rede Wi-Fi. iPhone desbloqueado na hora de instalar.
set -euo pipefail

UDID="${UDID:-00008110-000A5DC23C02401E}"
TEAM="${TEAM:-H2474S94U5}"
BUNDLE_ID="app.henrique.academia.$TEAM"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="$ROOT/.derived/iphone"
APP="$DERIVED/Build/Products/Debug-iphoneos/Henrique.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BASE_URL="${HENRIQUE_API_BASE_URL:-https://hnrq.vercel.app}"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { log "Erro: $*"; exit 1; }

xcrun devicectl list devices --json-output "$TMP/devices.json" >/dev/null 2>&1 \
  || fail "devicectl não listou os aparelhos."
TUNNEL="$(jq -r --arg udid "$UDID" '.result.devices[] | select(.hardwareProperties.udid == $udid) | .connectionProperties.tunnelState' "$TMP/devices.json")"
[[ -n "$TUNNEL" && "$TUNNEL" != unavailable ]] \
  || fail "iPhone $UDID fora de alcance via Wi-Fi (tunnel: ${TUNNEL:-desconhecido}). Desbloqueie o iPhone na mesma rede e confira CONNECT VIA NETWORK no Xcode."

HOST="$(printf '%s' "$BASE_URL" | sed -E 's#^https?://([^:/]+).*#\1#')"
if ! curl -sf -o /dev/null -m 3 "$BASE_URL/api/health" 2>/dev/null \
  && ! curl -sf -o /dev/null -m 3 "$BASE_URL" 2>/dev/null; then
  log "aviso: $BASE_URL não respondeu. Suba o servidor antes, ou o login vai falhar."
fi
[[ "$HOST" == "localhost" || "$HOST" == "127.0.0.1" ]] \
  && fail "localhost no aparelho físico é o próprio iPhone. Use o IP do Mac, ex.: http://$(ipconfig getifaddr en0 2>/dev/null || echo '<ip-do-mac>'):3000."

log "Compilando Debug para o iPhone (api em $BASE_URL)."
mkdir -p "$DERIVED"
xcodebuild build \
  -project "$ROOT/Henrique.xcodeproj" \
  -scheme Henrique \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  HENRIQUE_API_BASE_URL="$BASE_URL" \
  > "$DERIVED/xcodebuild.log" 2>&1 \
  || { tail -30 "$DERIVED/xcodebuild.log"; fail "o xcodebuild falhou. Log em $DERIVED/xcodebuild.log"; }

log "Instalando no iPhone via Wi-Fi."
xcrun devicectl device install app --device "$UDID" "$APP" > "$TMP/install.log" 2>&1 \
  || { tail -20 "$TMP/install.log"; fail 'a instalação falhou.'; }

log "Abrindo o app."
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" > "$TMP/launch.log" 2>&1 \
  || { tail -20 "$TMP/launch.log"; fail 'instalou, mas não abriu.'; }
log "Pronto no iPhone."
