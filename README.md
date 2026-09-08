# Academia

O módulo Academia do life hub, nativo em SwiftUI para iOS 26, com Liquid Glass.
Fala com a mesma API do app web, então treino, séries, medidas e metas são os
mesmos dados nos dois lugares.

## Estrutura

- `App/` é o alvo do iOS. Só o ponto de entrada e a leitura da configuração.
- `Packages/HenriqueKit/Sources/HenriqueCore` tem os modelos e o cliente HTTP,
  sem SwiftUI. É onde os testes de contrato rodam.
- `Packages/HenriqueKit/Sources/HenriqueUI` tem as telas e o store observável.
- `Supporting/Info.plist` fica fora da pasta sincronizada do alvo porque o Xcode
  reclama de dois comandos produzindo o mesmo `Info.plist`.

## Rodar

```sh
./scripts/run.sh                 # compila, instala e abre no iPhone 17 Pro
./scripts/run.sh "iPhone Air"    # em outro aparelho
./scripts/build.sh               # só compila
./scripts/test.sh                # a suíte
```

O endereço da API vem de `HENRIQUE_API_BASE_URL` nas configurações de build:
`http://localhost:3000` no Debug e o domínio de produção no Release.

## Ver as telas sem servidor

Em Debug o app aceita dois argumentos de lançamento:

```sh
xcrun simctl launch "iPhone 17 Pro" app.henrique.academia --amostra
xcrun simctl launch "iPhone 17 Pro" app.henrique.academia --amostra --aba progresso
```

`--amostra` carrega `Sources/HenriqueCore/Resources/amostra.json` e desliga a
rede. `--aba` aceita `hoje`, `semana`, `progresso` e `medidas`.

## Testes

A suíte roda sem servidor. As de integração ficam desligadas até você apontar
um, e aí exercitam login, 401 sem sessão e gravação idempotente de série:

```sh
bun run dev   # no repo do web
HENRIQUE_TEST_BASE_URL=http://localhost:3000 \
HENRIQUE_TEST_USERNAME=henrique HENRIQUE_TEST_PASSWORD=... ./scripts/test.sh
```

## API

O app consome `/api/v1/*`, um `OpenAPIHandler` do oRPC montado no repo do web
sobre os mesmos procedimentos que o front usa. Os caminhos estão no enum `Route`
de `APIClient.swift` e nos `.route(...)` de `packages/api/src/router.ts`.

A sessão é o cookie do better-auth, guardado no chaveiro. O cliente desliga o
pote de cookies do sistema de propósito: sem isso, sair da conta não sairia,
porque o cookie continuaria sendo enviado por fora do chaveiro.

## Xcode

Os scripts apontam para `~/Downloads/Xcode-beta.app` por `DEVELOPER_DIR`. Depois
de `sudo xcode-select -s ~/Downloads/Xcode-beta.app` dá para tirar essa linha.
