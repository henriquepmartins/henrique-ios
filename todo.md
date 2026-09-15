# Metas de consistência, streak no topo e menos texto

- [x] 1. `how` over the affected subsystem.
- [x] 2. `architect` for parallel design exploration.
  - architect skipped: a forma do dado segue a tabela `goal` que já existe e o topo tem referência visual pronta; o único fork (meta no servidor ou no aparelho) foi decidido pela evidência, porque presença não tem dado no payload.
- [x] 3. Write the throughput checkpoint as four todo items.
  - Blocking first steps. Inventário de texto e contrato do painel (`attendanceStreak`, `streakGoals`, `/api/v1/goal/set-streak`) antes do worker iOS.
  - Independent workstreams. Servidor no repo web e app iOS correm em paralelo; repos diferentes.
  - Shared mutable state. Servidor em worktree próprio do repo web. Metas, topo e corte de texto no iOS mexem nos mesmos arquivos, então um só worker.
  - Smallest safe decomposition. Dois workers: web e iOS. Migração e deploy do servidor esperam confirmação.
- [x] 4. Delegate code-writing to a subagent.
  - Servidor: 4 commits, migração 0009 aplicada em produção, deploy Ready em hnrq.vercel.app.
  - iOS: Academia (4 commits) e Estudos (1 commit) em worktrees, juntados no main; 73 testes passando.
- [x] 5. Verify on the matching surface.
  - scripts/verify-ui.sh passou (1 teste, 81 s) contra Postgres local e servidor real na 3001. Capturas em output/verify/20260915-174410: contador 3 apagado, sheet 3 treinos/3 completos, 4 aceso após série, meta presença 4/11, meta após reabrir, plano, estudos.
- [x] 6. Rebase into small, ordered commits; stack follow-ups.
  - skip: commits já pequenos em main (5 da feature + 828da96 harness; web df8e043).
- [ ] 7. If the design is contested, `interrogate` before shipping.
  - skip: design sem disputa; verificado ponta a ponta.
- [ ] 8. Run Opening a PR.
  - skip: o fluxo do projeto é commitar em main e publicar pelo release.sh.
- [x] 9. Rodar `scripts/release.sh` e instalar no iPhone pelo Wi-Fi.
  - build 6 publicado e instalado no iPhone às 17:47:52; assinatura até 2026-09-22.

## Decisões

- Streak de treinos corretos = sessão `completed` (todas as séries de trabalho marcadas). Presença = dia com pelo menos uma série de trabalho marcada.
- O streak zera quando a última sessão passa de 5 dias; hoje ele fica congelado até 28 dias.
- O topo mostra o streak de presença. Chama cinza sem treino hoje, colorida com treino.
- `motion-dev-animations` é para web; do SwiftUI aproveito só a regra de molas e movimento reduzido.

## Estado para retomar (2026-09-15)

Feito:
- Web `h&nrique` main `e905e9e`, já no GitHub: `calculateStreak` no domínio (zera após 5 dias sem teto de 28), `attendanceStreak`, `streakGoals`, rota `POST /api/v1/goal/set-streak`, migração 0009 aplicada em produção, deploy Ready em hnrq.vercel.app.
- iOS main `2fa3960`, sem push: 28be164 core, 8dcd250 contador no topo, 8d376eb metas em progresso, 6d06625 texto Academia, 2fa3960 texto Estudos. 73 testes passando no simulador "iPhone 17".
- Simulador pode estar com o build Debug apontando para 127.0.0.1:3999; reinstalar o Debug normal.

Próximo (opção 2 escolhida pelo usuário): ambiente de teste antes do release.

Mudança de plano (2026-09-15): o banco de produção está na org Neon da Vercel do time emvidros, fora do alcance do MCP e do neonctl. Troquei o branch Neon por Postgres local na porta 54329, porque o servidor usa `pg` e o dotenv não sobrescreve `DATABASE_URL` já definida. Design em scratchpad/test-env-design.md.
1. Branch Neon `dev` a partir de produção (MCP Neon). Nunca expor em preview.
2. Usuário de teste só no branch; senha fora do repo (Keychain ou ~/.config/henrique/test-credentials).
3. `.env.development.local` no repo web com o DATABASE_URL do branch; `localhost:3000` usa ele. `.env.local` de produção fica intocado. Conferir que o dev server lê o arquivo novo antes do de produção.
4. Script fixo no repo iOS que sobe o servidor, compila Debug, faz login com a credencial via XCUITest e grava PNGs. Reset do branch antes de cada rodada.
5. Com isso, verificar: contador aceso/apagado, sheet da sequência, cards de meta, editor presença salvando pelo servidor real, texto das abas treino/plano/estudos, animação do número subindo.
6. Depois: `scripts/release.sh` e instalação no iPhone pelo Wi-Fi. Atualizar memória driving-ui-without-credentials.

# Montagem de treino

- [x] 1. `how` over the affected subsystem.
- [x] 2. `architect` for parallel design exploration.
- [x] 3. Write the throughput checkpoint as four todo items.
  - Blocking first steps. Rastrear o array salvo e os controles existentes antes de implementar.
  - Independent workstreams. Revisão de interação e preparação do deploy podem ocorrer enquanto o worker altera a tela.
  - Shared mutable state. Worker em worktree exclusivo; integrar depois de encerrar a escrita.
  - Smallest safe decomposition. Um worker cuida da tela e dos testes associados, pois compartilham o mesmo fluxo.
- [x] 4. Delegate code-writing to a subagent.
- [ ] 5. Verify on the matching surface.
- [ ] 6. Rebase into small, ordered commits; stack follow-ups.
  - skip: entrega local no iPhone, sem mudança de branch pública.
- [ ] 7. If the design is contested, `interrogate` before shipping.
  - skip: decidir pelo controle nativo se a verificação confirmar o gesto.
- [ ] 8. Run Opening a PR.
  - skip: o pedido é alterar o app local e instalar no iPhone.

## Decisões

O array ordenado [PlanExercise] continua sendo a fonte da ordem e dos valores. Apagar modifica apenas o rascunho até Salvar. O projeto é SwiftUI, portanto os exemplos Motion.dev não se aplicam como dependência. A auditoria improve-animations fica restrita à interação pedida, seguida da implementação já autorizada.

## Verificação

- Build Release arm64 para iPhone passou. IPA build 4 usa https://hnrq.vercel.app.
- Suíte no iOS Simulator passou com 70 testes em 9 suites.
- Revisão independente não encontrou bug material no diff.
- Teste no macOS encontrou timeout do compilador no ExercisePicker; a suíte foi executada no iOS.
- Instalação do build 4 iniciada pelo AltStore no iPhone conectado.

- devicectl confirmou app.henrique.academia.H2474S94U5 build 4 instalado e aberto no iPhone físico.
- No iPhone, Organizar mostrou duas linhas compactas e alças nativas. A lixeira removeu só o exercício escolhido. Cancelar descartou o rascunho de teste.
- Pendente a confirmação do arraste por toque. Duas tentativas via Espelhamento ativaram a linha, mas não alteraram a ordem. Não foi validada persistência de reordenação no servidor.

# Teclado, cargas, confirmação e treinos sem dia

- [x] 1. `how` over the affected subsystem.
- [x] 2. `architect` for parallel design exploration.
  - Ground, Sketch, Agree, Implement, Scrap.
  - Arena: Frame, Fan out, Cross-judge, Pick, Graft, Verify.
- [x] 3. Write the throughput checkpoint as four todo items.
  - Blocking first steps. Rastrear contrato do servidor, calendário e gravação de séries antes da implementação.
  - Independent workstreams. Investigar persistência enquanto preparo a verificação iOS. Implementação do servidor e iOS em worktrees separados.
  - Shared mutable state. Um dono por worktree. Testes integrados só depois de encerrar os writers.
  - Smallest safe decomposition. Um dono iOS para teclado, estado da série e plano; um dono backend para contratos e transações.
- [x] 4. Delegate code-writing to a subagent.
- [x] 5. Verify on the matching surface.
- [x] 6. Rebase into small, ordered commits; stack follow-ups.
- [ ] 7. If the design is contested, `interrogate` before shipping.
  - skip: design sem disputa; revisão independente do diff e testes ponta a ponta foram suficientes.
- [ ] 8. Run Opening a PR.
  - skip: o fluxo local publica em main pelo release.sh, sem PR.

O dado será treino com weekdays vazio ou preenchido e gravação pendente identificada por dia, treino e série. Model the Domain orienta essa escolha para separar agenda e existência do treino.

## Escolha de desenho

How confirmou que o editor salva só no check e o dashboard exclui treinos sem dia. Duas revisões independentes compararam overlay no store e estado local por linha. Escolhi overlay no store com identidade por data, template e série. A FIFO será do store, não por série, porque cada resposta substitui o mesmo dashboard. Essa escolha corrige a proposta de fila por chave da segunda revisão. Rejeitei manter os treinos sem dia ocultos, sugerido na primeira revisão, porque impediria reabrir os treinos futuros pedidos pelo usuário.

O teclado usará toolbar SwiftUI e foco, com adaptação da barra existente do editor de texto. Sem introspecção global UIKit. O servidor manterá weekdays vazio como treino salvo e sem agenda. O dia legado será null nesses itens. A série valendo e a prescrição do template serão atualizadas na mesma transação. Aquecimento não altera prescrição.

Worktrees exclusivos em /tmp/henrique-ios-workout-flows e /tmp/henrique-web-workout-flows. Parent mantém testes de UI no checkout original. Backend e iOS só serão integrados depois de encerrada a escrita de cada dono.

## Retomada e evidência

Baseline scripts/verify-ui.sh passou. O teste novo testZTreinoSemDia falhou no app original por ausência de keyboard.done, em output/verify/20260915-181058. A interrupção por limite deixou patches nos dois worktrees; retomados pelos mesmos donos.

Backend integrado localmente em 039d1c3. Testes reportados e revisados: 33 domínio, 19 API, 26 web; build passou. Script packages/api/scripts/verify-workout-flows.ts passou contra PostgreSQL isolado, inclusive rollback e concorrência. Revisão independente sem defeito material. O push para main passou, mas a Vercel bloqueou os deployments com TEAM_ACCESS_REQUIRED. Backend com weekdays vazio requer app atualizado; instalar o iOS antes de disponibilizar treinos sem dia em produção.

Verificação final. `testZCargaETeclado`, `testZTreinoSemDia` e `testZZTecladoEmEstudos` passaram no iPhone 17 Simulator. `scripts/test.sh` passou com 74 testes em 9 suites. As capturas estão em `output/verify/20260915-194307`, `output/verify/20260915-194134` e `output/verify/20260915-194600`.
