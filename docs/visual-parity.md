# Academia em SwiftUI

O React em `apps/web/src` é a referência de composição. Esta revisão recupera as cinco abas, o fundo `#faf9f7`, os cards sólidos, o amarelo `#e1f96c` do treino, o recorte do calendário, as pastas do plano e a grade de medidas.

| Antes | Depois | Motivo |
| --- | --- | --- |
| Hoje reunia resumo e treino | Hoje e treino têm destinos separados | Mesma organização do React |
| Vidro em todos os cards | Cards sólidos; vidro na navegação, menus e botões | Preservar as cores e a hierarquia do conteúdo |
| Exercícios sempre abertos e edição em sheet | Expansão por exercício, modo lista e campos na linha | Recuperar o fluxo de registrar séries |
| Plano em lista | Cards em duas colunas, criar, editar e iniciar | Layout novo, escolhido pelo usuário |
| Peso e chips | Grade de peso, gordura, cintura e massa magra | Mesmas métricas do React |
| Formulário fechava antes da resposta | Fecha após sucesso, mantém rascunho em erro | Evitar perder a edição |

A fonte é a fonte de sistema do iOS. `TabView`, `NavigationStack`, `Menu`, `Picker`, `TextField`, `Form`, sheets e Swift Charts usam as APIs nativas. O projeto exige iOS 26 e macOS 26. A barra tem quatro abas nomeadas mais a bolha de apps, que é uma `Tab` com papel `prominent` no iOS 27 e papel de busca no iOS 26. Os editores de medidas e meta abrem em sheets nativos, enquanto o React os mostra na página. O gráfico de volume voltou a usar área e linha.

O menu configurar oferece primeiros passos, cor e acesso ao plano. O assistente inclui medidas, treino, exercícios e meta, com opção de pular etapas e preservação de rascunhos por dia enquanto está aberto. Fechar o assistente descarta campos ainda não salvos. Estudos e a troca entre apps estão fora deste trabalho, conforme a escolha do usuário.

A tela de hoje tem o card de sequência, que abre um anel com a semana, os sete
dias e a comemoração de quem treinou hoje. O número é `currentStreak`, que o
servidor conta como treinos seguidos tolerando até cinco dias de intervalo, então
o rótulo fala em treinos e nunca em dias. A fita dos sete dias depende de
`sessionDates`, campo novo no painel; contra servidor que não manda o campo a fita
some e o resto continua.

A conclusão do assistente usa `POST /api/v1/onboarding/complete`. O repositório React recebeu a exposição HTTP do procedimento já existente no roteador mobile. Essa alteração precisa ser publicada junto do app para a conclusão funcionar em produção. Nenhum deploy foi feito.

## Verificação

- Compilação para iPhone 17 Pro Simulator passou.
- Suíte de contrato e calendário passou. O runner reporta 25 testes; quatro de integração ficam desativados sem credenciais e servidor de teste.
- Capturas das cinco abas em `screenshots/`.
- As capturas confirmam renderização e composição, sem afirmar igualdade pixel a pixel. O React observado estava em largura de 402 px e com dados diferentes dos do app nativo.
- O controle do Device Hub expirou por timeout. Toques, gesto de voltar, VoiceOver, teclado, texto ampliado e gravação autenticada ainda precisam de verificação interativa.

## Rodar

Abra `Henrique.xcodeproj`, escolha o esquema Henrique e execute. O app só mostra dados da conta; entre com sua sessão. Para abrir direto numa aba, rode com `--aba treino`. As abas aceitas são `hoje`, `semana`, `treino` e `progresso`; `semana` é o nome interno da aba plano. `--aba apps` não é aba, abre a lista de apps por cima da tela de hoje. Medidas saiu da barra e virou um cartão no fim de progresso, mas `--aba medidas` continua valendo e cai lá.

Sem sessão dá para capturar só a casca, com `--casca`. O app abre já dentro, sem servidor e sem conta, e as abas ficam vazias. Serve para conferir a barra e a bolha de apps, não o conteúdo.

Para conferir persistência, entre na conta e registre uma série, altere uma meta, salve um treino e registre uma medida. Reabra o app para conferir os resultados. Em falha de rede, os formulários devem continuar abertos com os valores digitados.

## Decisões

O princípio Model the Domain manteve os dados no `AcademiaStore` e distinguiu hoje de treino no enum de abas. Prove It Works exigiu capturas do binário compilado; a captura descarta uma tela de abertura vazia antes de registrar evidência. As animações de entrada e contagens decorativas do React não foram reproduzidas a cada navegação. Expansões usam mola curta e respeitam Reduzir Movimento.

Referência de Liquid Glass: https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views

A última checagem `bun run check` passou com zero erros e dois avisos preexistentes em testes de estudos. A compilação e os testes Swift incluem o assistente. O assistente ainda não foi exercitado de ponta a ponta com uma sessão autenticada.

# Estudos em SwiftUI

O React em `apps/web/src/components/estudos` e o `estudos.css` são a referência. As cinco abas (hoje, matérias, cadernos, entregas, revisar), a sessão de foco e a folha de escrever chegaram ao app com o mesmo papel `#f6f5f4`, os cartões brancos com borda de 8%, as pílulas de estado, o herói com a matéria destacada em pêssego, a grade de matérias na cor de cada uma e a lousa preta da sessão.

| Antes | Depois | Motivo |
| --- | --- | --- |
| Botões em CSS (`.study-btn`) | `Button` com `.glassProminent` azul e `.glass` | Aspecto nativo, como na Academia |
| Trilha "estudos / aba" e menu de apps flutuante | Marca estática de duas linhas na barra; a troca de app mora na bolha de vidro à direita da barra de abas, que abre uma lista curta em vez de levar a uma tela | Mesma casca da Academia |
| Editor BlockNote na página do caderno | Título editável com autosave; blocos renderizados somente leitura | O JSON do BlockNote é preservado byte a byte e o corpo continua sendo editado no web |
| GSAP para cascata de entrada e virada do cartão | Cascata nativa de 35 ms por item na primeira montagem; virada em `rotation3DEffect` em duas metades | Mesmo tempo e curva do web, sem biblioteca |
| Arrasto do flashcard com Motion | `DragGesture` 1:1 com mola interpolating recebendo a velocidade do dedo | Regras de 80 pt e 500 pt/s iguais ao web |
| `window.confirm` e folha de ação própria | `confirmationDialog` nativo | Idioma do sistema |

Os dois apps dividem o mesmo `APIClient` e a mesma sessão. Sair de um derruba o outro. O seletor de app fica em `@AppStorage("henrique.app")` e a troca é um fade de 200 ms. A cor de destaque de Estudos é o azul `#0075de` do web, fixo, enquanto a Academia continua com o acento escolhido.

O contrato HTTP vive em `/api/v1/estudos/*` no repo web (`packages/api/src/router-estudos.ts`), exposto pelo `mobileRouter`. Essa alteração está só no working tree do repo web, sem commit e sem deploy, junto do commit anterior de `/api/v1` da Academia. Sem sessão, toda rota sob `/api/v1` devolve 401, então a prova de que as rotas existem foi feita com o `OpenAPIHandler` em processo.

## Verificação

- Compilação para iPhone 17 Simulator passou. `swift test` reporta 38 testes em 5 suítes, 13 novos de contrato dos estudos.
- Capturas das abas, da sessão de foco e da folha de escrever em `screenshots/estudos-*.png`, com `--app estudos --aba <aba>`; `sessao` e `escrever` abrem o cover e a folha direto. Cadernos saiu da barra e virou a seção caderno dentro da matéria, mas `--aba cadernos` continua valendo e cai em matérias.
- Nada foi exercitado com sessão real. Faltam conferir: autosave do título do caderno, criação de página (o empurrão para a página nova usa `navigationDestination(item:)`), nota salva ao concluir a sessão, 409 ao revisar um cartão já revisado em outro aparelho, a seção caderno dentro da matéria e o cartão de medidas em progresso.

## Decisões

Model the Domain pôs cada tela em um enum de estado (fila de revisão, sessão de foco, rascunho da nota) e o estado de cada aba em `Loadable`. Prove It Works exigiu as capturas do binário e derrubou uma aba "hoje" em branco causada por um `ViewBuilder` grande demais, que virou quatro views. A cascata de entrada roda uma vez por tela e não a cada troca de filtro, que é só crossfade de 120 ms. Reduzir Movimento troca escala e deslocamento por fades curtos em todos os controles.
