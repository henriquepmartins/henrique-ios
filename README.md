# h&nrique

App h&nrique, nativo em SwiftUI para iOS 26, com Liquid Glass.
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
./scripts/test.sh                # a suíte no macOS
./scripts/test.sh ios            # a mesma suíte dentro do simulador
```

O endereço da API vem de `HENRIQUE_API_BASE_URL` nas configurações de build:
`http://localhost:3000` no Debug e o domínio de produção no Release.

## Instalar o app nativo com AltStore

O iPhone precisa de iOS 26 ou superior. O AltStore Classic usa a conta gratuita
da Apple para assinar o app por 7 dias e tenta renovar a assinatura em segundo
plano. Deixe o AltServer aberto no Mac e os dois aparelhos na mesma rede Wi-Fi.
A renovação depende dessa conexão e da execução em segundo plano no iPhone.

Gere o arquivo de instalação no Mac com Xcode e o SDK do iOS 26:

```sh
./scripts/package-ipa.sh
```

O script compila o alvo `Henrique` em Release para arm64, confere o endereço
`https://hnrq.vercel.app` e gera `output/Henrique.ipa`. O arquivo sai sem
assinatura. O AltStore assina quando instala. O script aceita `DEVELOPER_DIR`
e usa `~/Downloads/Xcode-beta.app` se ele existir e a variável não estiver definida.
Cada execução substitui o IPA anterior depois de conferir o novo arquivo.

1. Instale o [AltServer para macOS](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
   e deixe-o aberto.
2. Conecte o iPhone ao Mac por cabo e confirme a confiança no computador.
   No Finder, selecione o iPhone e ative "Mostrar este iPhone quando em Wi-Fi".
3. No menu do AltServer, escolha "Install AltStore" e selecione o iPhone.
   Digite sua conta da Apple diretamente na janela do AltServer.
4. No iPhone, confie no desenvolvedor em Ajustes > Geral > VPN e Gerenciamento
   de Dispositivo. Ative o Modo de Desenvolvedor em Ajustes > Privacidade e Segurança.
5. Transfira `output/Henrique.ipa` para o app Arquivos do iPhone, por exemplo
   por AirDrop. No AltStore, abra "My Apps", toque em "+" e escolha o IPA.
6. Ative a atualização em segundo plano para o AltStore. Com o AltServer aberto,
   confira em "My Apps" se "Refresh All" renova a assinatura pela rede Wi-Fi.

O AltStore também ocupa uma das vagas da conta gratuita. Consulte os
[limites e a renovação do AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore).
Se a assinatura vencer, renove pelo AltStore e AltServer. Não apague o app para
renovar. Ao instalar uma atualização, use a mesma conta da Apple e o mesmo app.

Os registros que a API confirmou ficam no servidor. Renovar a assinatura não
substitui backup do banco, nem garante o envio de alterações que ainda não
foram salvas. O IPA não inclui um backup dos dados da conta.

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
HENRIQUE_TEST_USERNAME=henrique HENRIQUE_TEST_PASSWORD=... ./scripts/test.sh ios
```

Rode com `ios` sempre que a mudança tocar a rede. O macOS não aplica o App
Transport Security, então uma chamada em texto puro que o iPhone barraria passa
lá e o erro só aparece com o app na mão.

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
