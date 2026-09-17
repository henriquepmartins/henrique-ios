# h&nrique

meu hub pessoal. é um app só para as áreas da minha vida que eu acompanho de
perto, e cada área tem as próprias telas.

hoje são duas:

- academia, com treino do dia, semana, progresso e medidas.
- estudos, com matérias, entregas, revisões e sessões de foco.

o app é nativo, em swiftui para ios 26 com liquid glass. ele fala com a mesma
api do app web, então os dados são os mesmos nos dois lugares.

## estrutura

- `App/` é o alvo do ios. só tem o ponto de entrada e a leitura da configuração.
- `Packages/HenriqueKit/Sources/HenriqueCore` tem os modelos e o cliente http,
  sem swiftui. os testes de contrato rodam aqui.
- `Packages/HenriqueKit/Sources/HenriqueUI` tem as telas e os stores.
- `Supporting/Info.plist` fica fora da pasta sincronizada do alvo. lá dentro, o
  xcode reclama de dois comandos gerando o mesmo `Info.plist`.
- `altstore/source.json` é a fonte do altstore. o `release.sh` atualiza a cada
  build publicado.

## rodar

```sh
./scripts/run.sh                 # compila, instala e abre no iPhone 17 Pro
./scripts/run.sh "iPhone Air"    # em outro aparelho
./scripts/build.sh               # só compila
./scripts/test.sh                # a suíte no macos
./scripts/test.sh ios            # a mesma suíte no simulador
```

o endereço da api vem de `HENRIQUE_API_BASE_URL` nas configurações de build. no
debug é `http://localhost:3000`. no release é o domínio de produção.

## publicar um build

na main, com tudo commitado e o `gh` logado:

```sh
./scripts/release.sh             # publica
./scripts/release.sh --dry-run   # compila e mostra o resultado, sem publicar
```

o script faz isto, nessa ordem:

1. para se a main tiver mudança não commitada, estiver atrás de `origin/main`
   ou se a tag do próximo build já existir.
2. soma 1 ao `CURRENT_PROJECT_VERSION` e gera o ipa com `scripts/package-ipa.sh`.
3. põe a versão nova no topo de `altstore/source.json`, com tamanho, sha-256 e
   os commits desde o build anterior.
4. cria o commit `release: build N` e a tag `build-N`.
5. sobe a tag, cria a release no github com o `Henrique.ipa` e só depois sobe a
   main. assim a fonte pública nunca aponta para um arquivo que ainda não existe.
6. chama `scripts/push-to-iphone.sh` para o build chegar no iphone na hora.

se algo falhar antes do commit, o projeto e o `source.json` voltam ao que eram.
o dry run escreve o resultado em `output/source.dry-run.json` e não commita, não
cria tag e não sobe nada.

## instalar no iphone

### pelo wi-fi, sem tocar no iphone

o mac instala sozinho o último build publicado quando acha o iphone na mesma
rede. ele também reinstala quando faltam menos de 72 horas para vencer a
assinatura de 7 dias da conta gratuita da apple.

uma vez só:

1. entre com a conta da apple no xcode, em Settings > Accounts.
2. ligue o iphone no mac por cabo, confie no computador e ative o Modo de
   Desenvolvedor em Ajustes > Privacidade e Segurança.
3. deixe o mac e o iphone na mesma rede wi-fi.

depois:

```sh
./scripts/install-autopush.sh              # liga ou recarrega o agente
./scripts/install-autopush.sh --uninstall  # desliga
./scripts/push-to-iphone.sh                # uma rodada na mão
./scripts/push-to-iphone.sh --force        # reinstala mesmo em dia
```

### iterar no código sem cabo

para subir o working tree em debug, ainda via wi-fi:

```sh
./scripts/run-iphone.sh
HENRIQUE_API_BASE_URL=http://192.168.1.10:3000 ./scripts/run-iphone.sh
```

a diferença é que o `push-to-iphone.sh` instala o último build publicado, da
tag `build-N`, e o `run-iphone.sh` instala o que está aberto no editor. no
aparelho físico `localhost` é o próprio iphone, então o padrão já usa o ip do
mac. suba o servidor ouvindo na rede e desbloqueie o iphone na mesma wi-fi. se
o túnel cair, confira CONNECT VIA NETWORK na janela Devices and Simulators do
xcode.

o agente do launchd roda o script a cada 15 minutos e quando a sessão do mac
começa. o log fica em `~/Library/Logs/henrique-autopush.log`. o script compila a
partir da tag `build-N`, nunca da cópia de trabalho, e guarda o app assinado em
`~/Library/Caches/henrique-ios/`. o udid do iphone e o time da conta ficam no
topo de `scripts/push-to-iphone.sh`.

o iphone some da rede quando fica bloqueado por um tempo. nessa hora o script
anota que não achou o aparelho e tenta de novo na rodada seguinte. basta
desbloquear o iphone em casa pelo menos uma vez antes de a assinatura vencer.

### pelo altstore, como plano b

o altstore classic assina o app com a conta gratuita da apple por 7 dias e tenta
renovar em segundo plano. para renovar, ele precisa do altserver aberto no mac e
dos dois aparelhos na mesma rede.

1. instale o [altserver para macos](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
   e deixe aberto.
2. ligue o iphone no mac por cabo e confie no computador. no finder, selecione o
   iphone e ative "Mostrar este iPhone quando em Wi-Fi".
3. no menu do altserver, escolha "Install AltStore" e selecione o iphone. digite
   a conta da apple na própria janela do altserver.
4. no iphone, confie no desenvolvedor em Ajustes > Geral > VPN e Gerenciamento
   de Dispositivo e ative o Modo de Desenvolvedor em Ajustes > Privacidade e
   Segurança.
5. no altstore, abra "Sources", toque em "+" e cole o endereço abaixo. isso é
   feito uma vez só.
   `https://raw.githubusercontent.com/henriquepmartins/henrique-ios/main/altstore/source.json`
6. na página da fonte, instale o h&nrique. as atualizações aparecem em "My Apps".
7. ative a atualização em segundo plano do altstore. com o altserver aberto,
   confira se "Refresh All" renova a assinatura pelo wi-fi.

se o app entrou antes por um arquivo ipa, o altstore pode não reconhecer que ele
pertence à fonte. aí é só instalar uma vez pela fonte.

o próprio altstore ocupa uma das vagas de app da conta gratuita. os
[limites e a renovação](https://faq.altstore.io/altstore-classic/your-altstore)
estão no faq do altstore. se a assinatura vencer, renove pelo altstore com o
altserver aberto. não apague o app para renovar e use sempre a mesma conta da
apple.

`scripts/package-ipa.sh` gera sozinho o `output/Henrique.ipa`, sem assinatura. o
altstore assina na hora de instalar.

### sobre os dados

o que a api confirmou fica no servidor, então reinstalar ou renovar não apaga
nada. o que ainda não foi salvo pode se perder, e nenhum dos dois caminhos faz
backup do banco.

## ver as telas sem servidor

em debug, o app aceita estes argumentos de lançamento:

```sh
xcrun simctl launch "iPhone 17 Pro" app.henrique.academia --amostra
xcrun simctl launch "iPhone 17 Pro" app.henrique.academia --amostra --aba progresso
xcrun simctl launch "iPhone 17 Pro" app.henrique.academia --amostra --app estudos
```

`--amostra` carrega `Sources/HenriqueCore/Resources/amostra.json` e desliga a
rede. `--app` escolhe a área, `academia` ou `estudos`. `--aba` abre direto numa
aba. na academia vale `hoje`, `semana`, `treino` e `progresso`. em estudos vale
`hoje`, `materias`, `entregas` e `revisar`, e também `sessao` e `escrever`, que
abrem a sessão de foco e a folha de escrever.

## testes

a suíte roda sem servidor. os testes de integração ficam desligados até você
apontar um servidor. aí eles testam login, 401 sem sessão e gravação idempotente
de série:

```sh
bun run dev   # no repo do web
HENRIQUE_TEST_BASE_URL=http://localhost:3000 \
HENRIQUE_TEST_USERNAME=henrique HENRIQUE_TEST_PASSWORD=... ./scripts/test.sh ios
```

rode com `ios` sempre que a mudança mexer com rede. o macos não aplica o app
transport security, então uma chamada http sem tls que o iphone bloquearia passa
lá, e o erro só aparece com o app no aparelho.

## api

o app consome `/api/v1/*`, um `OpenAPIHandler` do orpc que o repo do web monta
sobre os mesmos procedimentos do front. os caminhos estão no enum `Route` de
`APIClient.swift` e nos `.route(...)` de `packages/api/src/router.ts`.

a sessão é o cookie do better-auth, guardado no chaveiro. o cliente desliga de
propósito o armazenamento de cookies do sistema. sem isso, sair da conta não
sairia de verdade, porque o sistema continuaria mandando o cookie por fora do
chaveiro.

## xcode

os scripts usam `DEVELOPER_DIR` quando ele está definido. sem ele, usam
`~/Downloads/Xcode-beta.app` se existir e, se não, o xcode do `xcode-select`.
