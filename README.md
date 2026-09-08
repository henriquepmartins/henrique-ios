# Academia

O módulo Academia do life hub, nativo em SwiftUI para iOS 26. Fala com a mesma
API do app web, então treino, séries, medidas e metas são os mesmos dados nos
dois lugares.

## Estrutura

- `App/` é o alvo do iOS. Só o ponto de entrada e a leitura do endereço da API.
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

## Xcode

Os scripts apontam para `~/Downloads/Xcode-beta.app` por `DEVELOPER_DIR`. Depois
de `sudo xcode-select -s ~/Downloads/Xcode-beta.app` dá para tirar essa linha.
