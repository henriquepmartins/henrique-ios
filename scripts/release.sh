#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO='henriquepmartins/henrique-ios'
PBXPROJ="$ROOT/Henrique.xcodeproj/project.pbxproj"
SOURCE="$ROOT/altstore/source.json"
IPA="$ROOT/output/Henrique.ipa"
SOURCE_URL="https://raw.githubusercontent.com/$REPO/main/altstore/source.json"

DRY_RUN=0
case "${1:-}" in
  '') ;;
  --dry-run) DRY_RUN=1 ;;
  *) printf 'Uso: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

fail() { printf 'Erro: %s\n' "$1" >&2; exit 1; }
warn() { printf 'Aviso: %s\n' "$1" >&2; }
# O dry run não commita nem publica, então estas condições só avisam.
check() { if [[ "$DRY_RUN" == 1 ]]; then warn "$1"; else fail "$1"; fi; }

cd "$ROOT"

[[ "$(git branch --show-current)" == main ]] || check 'o release sai só da branch main.'
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || check 'há mudanças não commitadas em arquivos rastreados.'
git fetch --quiet --tags origin
git merge-base --is-ancestor origin/main HEAD || fail 'o HEAD está atrás de origin/main ou divergiu. Rode git pull antes.'
if ! command -v gh >/dev/null; then
  check 'o gh não está instalado.'
elif ! gh auth status >/dev/null 2>&1; then
  check 'o gh não está autenticado. Rode gh auth login.'
fi

if grep -q 'CODE_SIGN_ENTITLEMENTS' "$PBXPROJ"; then
  fail 'o projeto define CODE_SIGN_ENTITLEMENTS. O source.json declara appPermissions.entitlements vazio, e o AltStore recusa a instalação se não bater com o app. Preencha a lista e ajuste este script.'
fi

only_value() {
  local values
  values="$(grep -o "$1 = [^;]*;" "$PBXPROJ" | sed "s/^$1 = //; s/;\$//" | sort -u)"
  [[ -n "$values" && "$(printf '%s\n' "$values" | wc -l)" -eq 1 ]] || fail "$1 não tem um valor único no projeto."
  printf '%s' "$values"
}
CURRENT="$(only_value CURRENT_PROJECT_VERSION)"
MARKETING="$(only_value MARKETING_VERSION)"
[[ "$CURRENT" =~ ^[0-9]+$ ]] || fail "CURRENT_PROJECT_VERSION não é um número: $CURRENT"
BUILD=$((CURRENT + 1))
TAG="build-$BUILD"
NEWEST="$(jq -r '.apps[0].versions[0].buildVersion // "0"' "$SOURCE")"
(( BUILD > NEWEST )) || fail "o build $BUILD não é maior que o último publicado no source.json ($NEWEST)."

if [[ -n "$(git log --format=%s --grep='^release: build ' origin/main..HEAD)" ]]; then
  fail "há um commit de release que não chegou a origin/main. Uma execução anterior parou no meio. Confira a tag com git ls-remote --tags origin, a release com gh release list e termine com git push origin main."
fi
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || [[ -n "$(git ls-remote --tags origin "refs/tags/$TAG")" ]]; then
  fail "a tag $TAG já existe. Não vou gerar outro build por cima dela."
fi
if command -v gh >/dev/null && gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  fail "a release $TAG já existe no GitHub. Não vou gerar outro build por cima dela."
fi

BACKUP="$(mktemp -d)"
cp "$PBXPROJ" "$BACKUP/project.pbxproj"
cp "$SOURCE" "$BACKUP/source.json"
COMMITTED=0
restore() {
  if [[ "$COMMITTED" == 0 ]]; then
    cp "$BACKUP/project.pbxproj" "$PBXPROJ"
    cp "$BACKUP/source.json" "$SOURCE"
  fi
  rm -rf "$BACKUP"
}
trap restore EXIT

sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT;/CURRENT_PROJECT_VERSION = $BUILD;/" "$PBXPROJ"
[[ "$(only_value CURRENT_PROJECT_VERSION)" == "$BUILD" ]] || fail 'não consegui gravar o novo build no projeto.'

"$ROOT/scripts/package-ipa.sh"

PLIST="$BACKUP/Info.plist"
unzip -p "$IPA" Payload/Henrique.app/Info.plist > "$PLIST"
IPA_BUILD="$(plutil -extract CFBundleVersion raw -o - "$PLIST")"
[[ "$IPA_BUILD" == "$BUILD" ]] || fail "o IPA saiu com CFBundleVersion $IPA_BUILD, esperado $BUILD."
PRIVACY="$(plutil -convert json -o - "$PLIST" | jq '[to_entries[] | select(.key | endswith("UsageDescription"))
  | {name: (.key | sub("^NS"; "") | sub("UsageDescription$"; "")), usageDescription: .value}]')"
MIN_IOS="$(plutil -extract MinimumOSVersion raw -o - "$PLIST")"

PREVIOUS="build-$CURRENT"
if git rev-parse -q --verify "refs/tags/$PREVIOUS" >/dev/null; then
  NOTES="$(git log --format='• %s' --invert-grep --grep='^release: ' "$PREVIOUS..HEAD")"
  [[ -n "$NOTES" ]] || NOTES='Sem mudanças no código desde o build anterior.'
else
  NOTES='Primeiro build publicado pela fonte do AltStore.'
fi

DATE="$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"
TARGET="$SOURCE"
if [[ "$DRY_RUN" == 1 ]]; then
  TARGET="$ROOT/output/source.dry-run.json"
fi
jq \
  --arg version "$MARKETING" \
  --arg build "$BUILD" \
  --arg date "$DATE" \
  --arg notes "$NOTES" \
  --arg url "https://github.com/$REPO/releases/download/$TAG/Henrique.ipa" \
  --argjson size "$(stat -f%z "$IPA")" \
  --arg sha256 "$(shasum -a 256 "$IPA" | cut -d' ' -f1)" \
  --arg minOS "$MIN_IOS" \
  --argjson privacy "$PRIVACY" \
  '.apps[0].appPermissions.privacy = $privacy
  | .apps[0].versions = [{version: $version, buildVersion: $build, date: $date, localizedDescription: $notes,
      downloadURL: $url, size: $size, sha256: $sha256, minOSVersion: $minOS}] + .apps[0].versions' \
  "$BACKUP/source.json" > "$BACKUP/source.next.json"
mv "$BACKUP/source.next.json" "$TARGET"

if [[ "$DRY_RUN" == 1 ]]; then
  printf '\nDry run do build %s. Nada foi commitado nem publicado, e o projeto volta ao build %s.\n' "$BUILD" "$CURRENT"
  printf 'source.json resultante em %s\n\n' "$TARGET"
  cat "$TARGET"
  exit 0
fi

git add "$PBXPROJ" "$SOURCE"
git commit --quiet -m "release: build $BUILD"
COMMITTED=1
git tag "$TAG"

git push origin "refs/tags/$TAG"
gh release create "$TAG" "$IPA" --repo "$REPO" --verify-tag \
  --title "h&nrique $MARKETING ($BUILD)" --notes "$NOTES"
git push origin main

"$ROOT/scripts/push-to-iphone.sh" || warn 'não consegui instalar o build no iPhone. Se o agente do launchd estiver instalado, ele tenta de novo em até 15 minutos.'

printf '\nBuild %s publicado.\nFonte do AltStore %s\nRelease https://github.com/%s/releases/tag/%s\n' \
  "$BUILD" "$SOURCE_URL" "$REPO" "$TAG"
