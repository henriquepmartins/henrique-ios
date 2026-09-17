# 001 — Fazer a cascata de entrada correr só na vertical

- **Status**: DONE
- **Commit**: b566166
- **Severity**: HIGH
- **Category**: Cohesion & tokens / Physicality & origin
- **Estimated scope**: 4 arquivos, diff pequeno

## Problem

A entrada em cascata usa um índice linear. Numa lista isso corre de cima para
baixo, que é o certo. Nas três telas em grade de duas colunas o mesmo índice
linear numera as peças na ordem de leitura, então a primeira coluna de uma
fileira entra antes da segunda e o olho lê uma varredura na diagonal, do canto
superior esquerdo para o canto inferior direito. O dono do app reclamou
exatamente disso: quer um fade de baixo para cima, sem varredura diagonal.

Os três lugares em grade:

```swift
// Packages/HenriqueKit/Sources/HenriqueUI/WeekScreen.swift:26 — atual
LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                         count: textSize.isAccessibilitySize ? 1 : 2), spacing: 6) {
  ForEach(Array(store.weekPlan.enumerated()), id: \.element.id) { index, item in
    WorkoutTile(
      ...)
      .staggeredEntrance(index: index, isReady: true)
  }
}
```

```swift
// Packages/HenriqueKit/Sources/HenriqueUI/StudySubjectsScreen.swift:45 — atual
LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
  ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
    NavigationLink(value: StudySubjectRoute(id: subject.id)) {
      StudySubjectCard(subject: subject)
    }
    .buttonStyle(StudyPressStyle())
    .staggeredEntrance(index: index, isReady: true)
  }
}
```

```swift
// Packages/HenriqueKit/Sources/HenriqueUI/MeasurementsScreen.swift:20 — atual
LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: textSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
  MeasurementMetric(title: "peso", ...)
    .staggeredEntrance(index: 0, isReady: true)
  MeasurementMetric(title: "gordura", ...)
    .staggeredEntrance(index: 1, isReady: true)
  MeasurementMetric(title: "cintura", ...)
    .staggeredEntrance(index: 2, isReady: true)
  MeasurementMetric(title: "massa magra", ...)
    .staggeredEntrance(index: 3, isReady: true)
}
```

Junto disso, o deslocamento de 10pt é mais do que um fade sutil pede. O pedido
é "leve, tranquilo".

## Target

A cascata só corre no eixo vertical. Duas peças lado a lado na mesma fileira
entram no mesmo instante, e a fileira de baixo entra depois da de cima. Quem
chama passa quantas colunas a grade tem, e o modificador divide o índice por
esse número para achar a fileira.

```swift
// Packages/HenriqueKit/Sources/HenriqueUI/Design.swift — alvo
extension View {
  /// Entrada em cascata da primeira montagem da lista. `isReady` é o momento em
  /// que os dados chegaram; o atraso para no sexto item para a última linha não
  /// esperar.
  ///
  /// `columns` é quantas colunas a grade que segura este item tem. A cascata só
  /// corre na vertical: duas peças lado a lado entram juntas, senão o olho lê
  /// uma varredura na diagonal em vez de um fade de baixo para cima.
  func staggeredEntrance(index: Int, columns: Int = 1, isReady: Bool) -> some View {
    modifier(StudyStaggeredEntrance(index: index / max(columns, 1), isReady: isReady))
  }
}
```

E o deslocamento fica menor:

```swift
// Packages/HenriqueKit/Sources/HenriqueUI/Design.swift — alvo
  /// O quanto um item sobe ao entrar.
  static let rise: CGFloat = 8
```

## Repo conventions to follow

- Todas as curvas do app saem do `enum Motion` em
  `Packages/HenriqueKit/Sources/HenriqueUI/Design.swift:168`. Não invente
  número solto numa tela.
- Toda animação passa por `@Environment(\.accessibilityReduceMotion)`. O
  modificador `StudyStaggeredEntrance` já faz isso em `Design.swift:216`, não
  mexa nessa parte.
- Comentário só para o porquê que o código não mostra, em português, sem
  travessão. Exemplar: `Design.swift:182`.

## Steps

1. Em `Packages/HenriqueKit/Sources/HenriqueUI/Design.swift`, troque
   `static let rise: CGFloat = 10` por `static let rise: CGFloat = 8`.
2. No mesmo arquivo, na `extension View` que declara `staggeredEntrance`
   (linha 211), acrescente o parâmetro `columns: Int = 1` entre `index` e
   `isReady`, e passe `index / max(columns, 1)` para o `StudyStaggeredEntrance`.
   Acrescente ao doc comment a frase que explica por que a cascata só corre na
   vertical. Não mexa no `StudyStaggeredEntrance` em si.
3. Em `Packages/HenriqueKit/Sources/HenriqueUI/WeekScreen.swift:38`, troque
   `.staggeredEntrance(index: index, isReady: true)` por
   `.staggeredEntrance(index: index, columns: textSize.isAccessibilitySize ? 1 : 2, isReady: true)`.
   É a mesma expressão que a grade usa em `count:` na linha 27.
4. Em `Packages/HenriqueKit/Sources/HenriqueUI/StudySubjectsScreen.swift:51`,
   troque `.staggeredEntrance(index: index, isReady: true)` por
   `.staggeredEntrance(index: index, columns: 2, isReady: true)`. Essa grade tem
   duas colunas fixas.
5. Em `Packages/HenriqueKit/Sources/HenriqueUI/MeasurementsScreen.swift`, os
   quatro `MeasurementMetric` viram
   `columns: textSize.isAccessibilitySize ? 1 : 2` mantendo os índices 0, 1, 2 e
   3. Como com duas colunas isso passa a ser fileira 0, 0, 1 e 1, os dois
   cartões que vêm depois da grade precisam continuar na sequência: o cartão do
   peso (linha 38) vai de `index: 4` para `index: 2` e o do histórico (linha 46)
   vai de `index: 5` para `index: 3`. Sem `columns` nesses dois, que estão numa
   `VStack`.
6. Nenhum outro `staggeredEntrance` muda. Os demais estão em listas verticais e
   o padrão `columns: 1` já dá o comportamento de hoje.

## Boundaries

- NÃO mexa em `firstEntrance` nem em `springEntrance`.
- NÃO mexa em `AttendanceMap.swift`, `PlanCalendarCard.swift` nem em
  `StudyAssignmentsCalendarCard.swift`. Essas três telas acabaram de ser
  ajustadas no commit anterior e estão fora do escopo.
- NÃO mude estrutura de view, layout, espaçamento nem cor. Só o que está
  descrito acima.
- NÃO mexa nas durações de `Motion.entrance`, `Motion.grow`, `Motion.tap`,
  `Motion.crossfade` nem no passo de `Motion.delay`. Só `rise` muda.
- NÃO adicione dependência.
- Se algum trecho não bater com o que está no arquivo, pare e reporte em vez de
  improvisar.

## Verification

- **Mecânica**:
  `xcodebuild -scheme Henrique -destination 'platform=iOS Simulator,name=iPhone 17' build`
  precisa terminar em `** BUILD SUCCEEDED **`.
- **Feel check**: `ONLY=testPastaDeTreino bash scripts/verify-ui.sh` precisa
  passar. Gravando o simulador com
  `xcrun simctl io booted recordVideo --codec h264 saida.mov` e extraindo os
  quadros com `ffmpeg -vf fps=30`, ao abrir a aba "plano":
  - os dois treinos da mesma fileira começam a aparecer no mesmo quadro
  - nenhuma peça da segunda coluna entra antes da peça ao lado dela
  - o movimento de cada peça é só para cima, nunca de lado
  - com "Reduzir movimento" ligado nas Acessibilidade do simulador, nada desliza
    e só a opacidade muda
- **Done when**: o build passa, o teste de UI passa, e nos quadros extraídos a
  cascata desce fileira por fileira em vez de varrer na diagonal.
