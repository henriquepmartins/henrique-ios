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

Os builds saem por uma fonte do AltStore guardada neste repo, em
`altstore/source.json`. Cada build publicado vira uma release no GitHub com o
`Henrique.ipa`, e o AltStore avisa no iPhone quando aparece um build novo.

1. Instale o [AltServer para macOS](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
   e deixe-o aberto.
2. Conecte o iPhone ao Mac por cabo e confirme a confiança no computador.
   No Finder, selecione o iPhone e ative "Mostrar este iPhone quando em Wi-Fi".
3. No menu do AltServer, escolha "Install AltStore" e selecione o iPhone.
   Digite sua conta da Apple diretamente na janela do AltServer.
4. No iPhone, confie no desenvolvedor em Ajustes > Geral > VPN e Gerenciamento
   de Dispositivo. Ative o Modo de Desenvolvedor em Ajustes > Privacidade e Segurança.
5. No AltStore, abra "Sources", toque em "+" e cole o endereço abaixo. Isso só
   se faz uma vez.
   `https://raw.githubusercontent.com/henriquepmartins/henrique-ios/main/altstore/source.json`
6. Na página da fonte, instale o h&nrique. As atualizações aparecem em "My Apps"
   e se instalam por lá.
7. Ative a atualização em segundo plano para o AltStore. Com o AltServer aberto,
   confira em "My Apps" se "Refresh All" renova a assinatura pela rede Wi-Fi.

Se o app foi instalado antes a partir de um arquivo IPA, o AltStore pode não
ligá-lo à fonte. Nesse caso, instale uma vez pela fonte. Os dados continuam na
conta, porque ficam no servidor.

O AltStore também ocupa uma das vagas da conta gratuita. Consulte os
[limites e a renovação do AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore).
Se a assinatura vencer, renove pelo AltStore e AltServer. Não apague o app para
renovar. Ao instalar uma atualização, use a mesma conta da Apple e o mesmo app.

Os registros que a API confirmou ficam no servidor. Renovar a assinatura não
substitui backup do banco, nem garante o envio de alterações que ainda não
foram salvas. O IPA não inclui um backup dos dados da conta.

### Publicar um build

No Mac, com Xcode, o SDK do iOS 26 e o `gh` autenticado, rode a partir da main:

```sh
./scripts/release.sh
```

O script para antes de mexer em qualquer coisa se a main tiver mudanças não
commitadas, estiver atrás de `origin/main` ou se a tag do próximo build já
existir. Depois ele soma 1 ao `CURRENT_PROJECT_VERSION`, gera o IPA com
`scripts/package-ipa.sh` e confere se o IPA saiu com esse número. Então
acrescenta a versão no topo de `altstore/source.json`, com tamanho, SHA-256 e os
assuntos dos commits desde o build anterior. Por fim, cria o commit
`release: build N` e a tag `build-N`, envia a tag, cria a release com o IPA e só
então envia a main. Assim a fonte pública nunca aponta para um arquivo que ainda
não existe. Se algo falhar antes do commit, o projeto e o `source.json` voltam ao
que eram.

Para conferir sem publicar:

```sh
./scripts/release.sh --dry-run
```

O dry run compila o build seguinte e escreve o `source.json` resultante em
`output/source.dry-run.json`, sem commit, tag, push nem release. O projeto
volta ao número anterior no fim. Fora da main ou com mudanças locais, ele só avisa.

`scripts/package-ipa.sh` continua gerando `output/Henrique.ipa` sozinho, sem
assinatura. O AltStore assina quando instala. O script aceita `DEVELOPER_DIR` e
usa `~/Downloads/Xcode-beta.app` se ele existir e a variável não estiver definida.

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
