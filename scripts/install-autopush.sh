#!/bin/bash
# Registra no launchd um agente que roda scripts/push-to-iphone.sh a cada 15 minutos.
set -euo pipefail

LABEL='app.henrique.autopush'
SCRIPT="${SCRIPT:-/Users/henriquepereiramartins/code/personal/projects/henrique-ios/scripts/push-to-iphone.sh}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/henrique-autopush.log"
DOMAIN="gui/$(id -u)"

unload() {
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  for _ in {1..50}; do
    launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1 || return 0
    sleep 0.1
  done
  printf 'Erro: o launchd não descarregou %s.\n' "$LABEL" >&2
  exit 1
}

case "${1:-}" in
  '') ;;
  --uninstall)
    unload
    rm -f "$PLIST"
    printf 'Agente %s removido. O log continua em %s\n' "$LABEL" "$LOG"
    exit 0 ;;
  *) printf 'Uso: %s [--uninstall]\n' "$0" >&2; exit 2 ;;
esac

[[ -x "$SCRIPT" ]] || { printf 'Erro: %s não existe ou não é executável.\n' "$SCRIPT" >&2; exit 1; }

mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT</string>
  </array>
  <key>StartInterval</key>
  <integer>900</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG</string>
  <key>StandardErrorPath</key>
  <string>$LOG</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
    <key>DEVELOPER_DIR</key>
    <string>/Applications/Xcode.app/Contents/Developer</string>
  </dict>
</dict>
</plist>
EOF
plutil -lint -s "$PLIST"

unload
launchctl bootstrap "$DOMAIN" "$PLIST"
printf 'Agente %s carregado. Roda %s a cada 15 minutos.\nLog em %s\n' "$LABEL" "$SCRIPT" "$LOG"
