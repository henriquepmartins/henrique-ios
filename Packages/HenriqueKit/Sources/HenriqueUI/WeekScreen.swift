import HenriqueCore
import SwiftUI

struct WeekScreen: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dynamicTypeSize) private var textSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var editor: PlanEditorDestination?
  var onStart: (Int) -> Void = { _ in }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Button("novo treino", systemImage: "plus") { editor = .new(weekdays: []) }
          .buttonStyle(.glassProminent)
          .controlSize(.large)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                 count: textSize.isAccessibilitySize ? 1 : 2), spacing: 6) {
          ForEach(Array(store.weekPlan.enumerated()), id: \.element.id) { index, item in
            WorkoutTile(
              item: item,
              onEdit: { editor = .existing(item) },
              onDelete: { store.deleteWorkout(workoutTemplateId: item.id) },
              onStart: { if let day = item.nextWeekday(from: store.selectedDate.weekday()) { onStart(day) } })
              .staggeredEntrance(index: index, isReady: true)
          }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .snappy, value: store.weekPlan.map(\.id))
      }
      .padding(16)
      .padding(.bottom, 32)
    }
    .background(Color.canvas)
    .refreshable { await store.load() }
    .sheet(item: $editor) { destination in
      WorkoutEditor(
        item: destination.item, weekdays: destination.weekdays,
        catalog: store.dashboard?.exerciseCatalog ?? [])
    }
  }


}

private enum PlanEditorDestination: Identifiable {
  case new(weekdays: Set<Int>)
  case existing(WeekPlanItem)
  var id: String { item?.id ?? "new" }
  var item: WeekPlanItem? {
    if case .existing(let item) = self { return item }
    return nil
  }
  var weekdays: Set<Int> {
    switch self {
    case .new(let weekdays): weekdays
    case .existing(let item): Set(item.weekdays)
    }
  }
}

private let planWeekdays = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"]
private let planWeekdaysShort = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]

/// "segunda e quinta". O locale fica preso no português porque o resto da tela
/// também é, e senão um aparelho em inglês lia "segunda and quinta".
private func spokenWeekdays(_ weekdays: [Int]) -> String {
  weekdays.map { planWeekdays[$0] }.formatted(.list(type: .and).locale(StudyFormat.locale))
}

private struct WorkoutTile: View {
  let item: WeekPlanItem
  let onEdit: () -> Void
  let onDelete: () -> Void
  let onStart: () -> Void
  @State private var confirmDelete = false

  /// A cor vem do dia e não da posição na grade. Pela posição, apagar um card
  /// repintava todos os que vinham depois.
  private var tone: WorkoutTone { .at(item.weekdays.first ?? 0) }
  private var nameFont: Font { .system(.headline, weight: .semibold) }
  /// O recuo do bloco colorido. Os três pontos leem o mesmo valor para cair na
  /// linha do nome.
  private let blockPad: CGFloat = 12
  /// A folga que leva a área de toque dos três pontos aos 44 pontos. Sai de
  /// novo do recuo de baixo, senão o glifo desce e desalinha do nome.
  private let menuTapPad: CGFloat = 10

  var body: some View {
    Button(action: item.weekdays.isEmpty ? onEdit : onStart) { face }
      .buttonStyle(StudyPressStyle())
      .accessibilityLabel(item.weekdays.isEmpty ? "editar \(item.name), sem dia" : "iniciar \(item.name), \(spokenWeekdays(item.weekdays))")
      // Menu dentro do label de um Button nunca chega a receber o dedo. Por isso
      // ele vem numa camada por cima, com área de toque só nos três pontos.
      .overlay(alignment: .bottomTrailing) { menuLayer }
  }

  private var face: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .top) {
        sheet(inset: 24, opacity: 0.3)
        sheet(inset: 12, opacity: 0.52).padding(.top, 6)
        block.padding(.top, 13)
      }
      // Sem achatar antes, a sombra é aplicada em cada vinco e cai sobre o
      // bloco como uma faixa escura.
      .compositingGroup()
      .shadow(color: Color.ink.opacity(0.12), radius: 12, y: 6)
      footer
    }
  }

  private var footer: some View {
    Label(item.weekdays.isEmpty ? "sem dia" : "", systemImage: item.weekdays.isEmpty ? "pencil" : "play.fill")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Color.mutedInk)
      .padding(.vertical, 11)
  }

  private func sheet(inset: CGFloat, opacity: Double) -> some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(tone.top.opacity(opacity))
      .frame(height: 26)
      .padding(.horizontal, inset)
  }

  private var block: some View {
    Text(item.name)
      .font(nameFont)
      .tracking(-0.3)
      .foregroundStyle(tone.ink)
      .lineLimit(2)
      .padding(.trailing, 30)
      .frame(maxWidth: .infinity, minHeight: 88, alignment: .bottomLeading)
      .padding(blockPad)
      .background {
        ZStack {
          LinearGradient(colors: [tone.top, tone.bottom], startPoint: .top, endPoint: .bottom)
          WorkoutWave(closed: true).fill(.white.opacity(0.12))
          WorkoutWave().stroke(.white.opacity(0.45), lineWidth: 1.5)
        }
      }
      .clipShape(.rect(cornerRadius: 18))
  }

  private var menuLayer: some View {
    VStack(alignment: .trailing, spacing: 0) {
      Menu {
        Button("editar", systemImage: "pencil", action: onEdit)
        Button("apagar", systemImage: "trash", role: .destructive) { confirmDelete = true }
      } label: {
        // O espaço invisível no corpo do nome dá a altura da linha, então os
        // três pontos caem no meio dela em qualquer tamanho de texto.
        Text(verbatim: " ")
          .font(nameFont)
          .hidden()
          .frame(width: 44)
          .overlay {
            Image(systemName: "ellipsis")
              .font(.system(.body, weight: .semibold))
              .rotationEffect(.degrees(90))
              .foregroundStyle(tone.ink)
          }
          .padding(.vertical, menuTapPad)
          .contentShape(.rect)
      }
      .accessibilityLabel("editar \(item.name)")
      // Preso nos três pontos, o diálogo aponta para o card que vai sumir. Preso
      // na tela, ele abria no topo, longe do toque.
      .deleteWorkoutConfirmation(isPresented: $confirmDelete, name: item.name, onDelete: onDelete)
      .padding(.bottom, blockPad - menuTapPad)
      footer.hidden()
    }
    .padding(.trailing, 2)
  }
}

private struct WorkoutWave: Shape {
  /// Fechada vira a faixa clara da metade de baixo, aberta vira só o traço.
  var closed = false

  func path(in rect: CGRect) -> Path {
    let base = rect.minY + rect.height * 0.52
    let amp = rect.height * 0.085
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: base))
    path.addQuadCurve(to: CGPoint(x: rect.midX, y: base),
                      control: CGPoint(x: rect.minX + rect.width * 0.25, y: base - amp))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: base),
                      control: CGPoint(x: rect.midX + rect.width * 0.25, y: base + amp))
    if closed {
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.closeSubpath()
    }
    return path
  }
}

struct WorkoutEditor: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  #if os(iOS)
  @State private var editMode: EditMode = .inactive
  #endif
  @State private var name: String
  @State private var focus: String
  @State private var estimatedMinutes: Int
  @State private var exercises: [PlanExercise]
  @State private var isPickingExercise = false
  @State private var isSaving = false
  @State private var confirmDelete = false
  @State private var weekdays: Set<Int>
  /// O catálogo por id, montado uma vez. Cada tecla no nome roda o body de novo
  /// e cada linha de exercício lê daqui, então a busca não pode varrer a lista.
  @State private var exerciseInfo: [String: ExerciseCatalogItem]

  private let catalog: [ExerciseCatalogItem]
  private let workoutId: String?

  init(item: WeekPlanItem?, weekdays: Set<Int>, catalog: [ExerciseCatalogItem]) {
    workoutId = item?.id
    self.weekdays = weekdays
    self.catalog = catalog
    exerciseInfo = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    name = item?.name ?? ""
    focus = item?.focus ?? ""
    estimatedMinutes = item?.estimatedMinutes ?? 55
    exercises = item?.exercises ?? []
  }

  private var canSave: Bool {
    name.trimmingCharacters(in: .whitespaces).count >= 2
      && focus.trimmingCharacters(in: .whitespaces).count >= 2
      && !exercises.isEmpty && exercises.count <= 12 && (15...180).contains(estimatedMinutes)
      && exercises.allSatisfy { $0.repsMin <= $0.repsMax && $0.startingWeightKg >= 0 }
  }

  private var isOrganizing: Bool {
    #if os(iOS)
    editMode.isEditing
    #else
    false
    #endif
  }

  private var editAnimation: Animation? {
    reduceMotion ? nil : .spring(duration: 0.25, bounce: 0)
  }

  var body: some View {
    NavigationStack {
      Form {
        WorkoutDaysSection(selection: $weekdays, workoutId: workoutId)

        Section {
          TextField("nome", text: $name)
            .submitLabel(.done)
          TextField("foco", text: $focus)
            .submitLabel(.done)
          TextField("minutos", value: $estimatedMinutes, format: .number)
            .submitLabel(.done)
            .decimalInput()
        }

        Section {
          ForEach($exercises) { $exercise in
            let exerciseId = exercise.exerciseId
            let info = exerciseInfo[exerciseId]
            PlanExerciseRow(
              exercise: $exercise, name: info?.name ?? exercise.exerciseId,
              subtitle: info.map { "\($0.muscleGroup.lowercased()) · \($0.equipment.lowercased())" },
              imageUrl: info?.imageUrl, isOrganizing: isOrganizing,
              onRemove: {
                withAnimation(editAnimation) {
                  exercises.removeAll { $0.exerciseId == exerciseId }
                }
              })
              .deleteDisabled(isSaving)
              .moveDisabled(isSaving)
          }
          .onDelete { offsets in
            withAnimation(editAnimation) { exercises.remove(atOffsets: offsets) }
          }
          .onMove { offsets, destination in
            withAnimation(editAnimation) {
              exercises.move(fromOffsets: offsets, toOffset: destination)
            }
          }

          Button("adicionar", systemImage: "plus") {
            isPickingExercise = true
          }
          .disabled(exercises.count >= 12)
        } header: {
          HStack {
            Text("exercícios")
            Spacer()
            #if os(iOS)
            if !exercises.isEmpty || isOrganizing {
              Button(isOrganizing ? "ok" : "ordenar") {
                withAnimation(editAnimation) {
                  editMode = isOrganizing ? .inactive : .active
                }
              }
              .font(.subheadline.weight(.semibold))
              .textCase(nil)
              .frame(minHeight: 44)
              .buttonStyle(.borderless)
              .accessibilityHint(isOrganizing
                ? "Voltar aos ajustes dos exercícios"
                : "Mostrar alças para arrastar os exercícios")
            }
            #endif
          }
        }

        if workoutId != nil {
          Section {
            Button("apagar treino", systemImage: "trash", role: .destructive) {
              confirmDelete = true
            }
            .disabled(isSaving)
            .deleteWorkoutConfirmation(isPresented: $confirmDelete, name: name, onDelete: remove)
          }
        }
      }
      .keyboardDone()
      .disabled(isSaving)
      #if os(iOS)
      .environment(\.editMode, $editMode)
      #endif
      .transaction { transaction in
        if reduceMotion { transaction.disablesAnimations = true }
      }
      .navigationTitle(name.isEmpty ? "novo treino" : name)
      .toolbarTitleDisplayMode(.inline)
      .interactiveDismissDisabled(isSaving)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("cancelar") { dismiss() }.disabled(isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("salvar") { save() }.disabled(!canSave || isSaving)
        }
      }
      .sheet(isPresented: $isPickingExercise) {
        ExercisePicker(catalog: catalog, chosen: Set(exercises.map(\.exerciseId))) { item in
          let known = catalog.contains(where: { $0.id == item.id })
          exerciseInfo[item.id] = item
          exercises.append(
            PlanExercise(
              exerciseId: item.id, prepSets: 2, workSets: 2, repsMin: 8, repsMax: 12,
              workToFailure: true, startingWeightKg: 0, name: known ? nil : item.name,
              muscleGroup: known ? nil : item.muscleGroup,
              equipment: known ? nil : item.equipment,
              imageUrl: known ? nil : item.imageUrl))
        }
      }
    }
  }

  private func save() {
    let input = SaveWorkoutInput(
      date: store.selectedDate, workoutTemplateId: workoutId, weekdays: weekdays.sorted(),
      name: name.trimmingCharacters(in: .whitespaces),
      focus: focus.trimmingCharacters(in: .whitespaces), estimatedMinutes: estimatedMinutes,
      exercises: exercises)
    isSaving = true
    Task {
      let saved = await store.saveWorkout(input)
      isSaving = false
      if saved { dismiss() }
    }
  }

  private func remove() {
    guard let workoutId else { return }
    store.deleteWorkout(workoutTemplateId: workoutId)
    dismiss()
  }
}

/// Os sete dias num toque cada, na ordem da semana do aparelho. O rodapé avisa
/// quando um dia marcado sai de outro treino, antes de salvar.
private struct WorkoutDaysSection: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dynamicTypeSize) private var textSize
  @Binding var selection: Set<Int>
  let workoutId: String?

  private var orderedWeekdays: [Int] {
    let first = Calendar.autoupdatingCurrent.firstWeekday - 1
    return (0..<7).map { (first + $0) % 7 }
  }

  var body: some View {
    let handoffs = WeekdayOwners(plan: store.weekPlan, excluding: workoutId).handoffs(to: selection)
    Section {
      // Nos tamanhos de acessibilidade sete círculos não cabem numa linha. Em
      // quatro colunas cada círculo cresce com o texto e a semana quebra em duas.
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 4),
                       count: textSize.isAccessibilitySize ? 4 : 7),
        spacing: 8
      ) {
        ForEach(orderedWeekdays, id: \.self) { day in
          WeekdayToggle(
            shortName: planWeekdaysShort[day], fullName: planWeekdays[day],
            isOn: selection.contains(day)
          ) {
            if selection.contains(day) { selection.remove(day) } else { selection.insert(day) }
          }
        }
      }
      .padding(.vertical, 4)
      .sensoryFeedback(.selection, trigger: selection)
    } header: {
      Text("dias")
    } footer: {
      if !handoffs.isEmpty {
        Text(handoffs.map(Self.note).joined(separator: " "))
      }
    }
  }

  private static func note(_ handoff: WeekdayHandoff) -> String {
    let days = spokenWeekdays(handoff.weekdays)
    let verb = handoff.weekdays.count == 1 ? "sai" : "saem"
    guard handoff.becomesUnscheduled else { return "\(days) \(verb) de \(handoff.workoutName)" }
    return "\(handoff.workoutName) continua sem dia"
  }
}

/// A troca de cor é imediata. Marcar dia é toque repetido, e esperar uma
/// animação a cada toque deixa a fileira lenta.
private struct WeekdayToggle: View {
  let shortName: String
  let fullName: String
  let isOn: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Circle()
        .fill(isOn ? Color.ink : Color.surfaceMuted)
        .overlay {
          Text(shortName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isOn ? .white : Color.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(4)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(.rect)
    }
    // Sem estilo próprio, o Form junta todos os botões da linha num toque só.
    .buttonStyle(.plain)
    .accessibilityLabel(fullName)
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }
}

private extension View {
  /// O treino leva junto as sessões e as séries registradas nele, então o
  /// diálogo diz o nome e o que se perde.
  func deleteWorkoutConfirmation(
    isPresented: Binding<Bool>, name: String, onDelete: @escaping () -> Void
  ) -> some View {
    confirmationDialog("apagar \(name)?", isPresented: isPresented, titleVisibility: .visible) {
      Button("apagar", role: .destructive, action: onDelete)
      Button("cancelar", role: .cancel) {}
    } message: {
      Text("as séries somem junto")
    }
  }
}

struct PlanExerciseRow: View {
  @Binding var exercise: PlanExercise
  let name: String
  let subtitle: String?
  let imageUrl: String?
  let isOrganizing: Bool
  let onRemove: (() -> Void)?

  init(
    exercise: Binding<PlanExercise>, name: String, subtitle: String? = nil,
    imageUrl: String? = nil, isOrganizing: Bool = false, onRemove: (() -> Void)? = nil
  ) {
    _exercise = exercise
    self.name = name
    self.subtitle = subtitle
    self.imageUrl = imageUrl
    self.isOrganizing = isOrganizing
    self.onRemove = onRemove
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        ExerciseThumb(imageUrl: imageUrl, size: 48)
        VStack(alignment: .leading, spacing: 3) {
          Text(name.lowercased()).font(.headline.weight(.semibold))
          if isOrganizing {
            Text("\(exercise.workSets) × \(exercise.repsMin)-\(exercise.repsMax)")
              .font(.caption).foregroundStyle(Color.mutedInk).monospacedDigit()
          } else if let subtitle {
            Text(subtitle).font(.caption).foregroundStyle(Color.mutedInk)
          }
        }
        Spacer(minLength: 0)
        if !isOrganizing, let onRemove {
          Button(role: .destructive, action: onRemove) {
            Image(systemName: "trash")
              .frame(width: 44, height: 44)
              .contentShape(.rect)
          }
          .buttonStyle(.borderless)
          .accessibilityLabel("Remover \(name) do treino")
        }
      }
      .padding(.top, isOrganizing ? 0 : 6)
      if !isOrganizing {
        Divider()
        ExerciseStepperRow(label: "aquecimento", value: $exercise.prepSets, range: 0...6)
        Divider()
        ExerciseStepperRow(label: "valendo", value: $exercise.workSets, range: 1...10)
        Divider()
        ExerciseStepperRow(label: "reps mín.", value: $exercise.repsMin, range: 1...50)
        Divider()
        ExerciseStepperRow(label: "reps máx.", value: $exercise.repsMax, range: 1...50)
        Divider()
        WeightStepper(weightKg: $exercise.startingWeightKg)
        Divider()
        Toggle("até a falha", isOn: $exercise.workToFailure)
          .font(.body)
          .frame(minHeight: 48)
      }
    }
    .padding(.vertical, 10)
  }
}

/// Um controle por linha, etiqueta de um lado e stepper do outro. Cada linha
/// tem 48 de altura para o dedo acertar sem mirar, e o número em tabular não
/// empurra o stepper quando vai de 9 para 10.
struct ExerciseStepperRow: View {
  let label: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    HStack(spacing: 12) {
      Text(label).font(.body)
      Spacer(minLength: 8)
      Text("\(value)").font(.body.weight(.semibold)).monospacedDigit()
        .frame(minWidth: 32, alignment: .trailing)
      Stepper("", value: $value, in: range)
        .labelsHidden()
        .accessibilityLabel(label)
    }
    .frame(minHeight: 48)
  }
}

/// A miniatura do exercício. Foto quando tem, halter quando não tem. O contorno
/// fino separa a foto do fundo sem virar borda dura.
struct ExerciseThumb: View {
  let imageUrl: String?
  let size: CGFloat
  private var radius: CGFloat { size * 0.32 }

  var body: some View {
    Group {
      if let imageUrl, let url = URL(string: imageUrl) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFill()
              .transition(.opacity)
          default:
            RoundedRectangle(cornerRadius: radius).fill(Color.surfaceMuted)
              .overlay { Image(systemName: "dumbbell").foregroundStyle(Color.mutedInk.opacity(0.5)) }
          }
        }
      } else {
        RoundedRectangle(cornerRadius: radius).fill(Color.surfaceMuted)
          .overlay { Image(systemName: "dumbbell").foregroundStyle(Color.mutedInk.opacity(0.6)) }
      }
    }
    .frame(width: size, height: size)
    .clipShape(.rect(cornerRadius: radius))
    .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.black.opacity(0.1)))
    .accessibilityHidden(true)
  }
}

struct ExercisePicker: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var searchFocused: Bool
  @State private var search = ""
  @State private var muscle: String?
  @State private var remote: [ExerciseCatalogItem] = []
  @State private var remotePhase: RemotePhase = .idle
  @State private var lookup: Task<Void, Never>?

  let catalog: [ExerciseCatalogItem]
  let chosen: Set<String>
  let onPick: (ExerciseCatalogItem) -> Void
  @State private var wger = WgerClient()

  private enum RemotePhase: Equatable {
    case idle, loading, done, failed
  }

  private var library: [ExerciseCatalogItem] {
    ExerciseLibrary.merged(with: catalog)
  }

  private var local: [ExerciseCatalogItem] {
    ExerciseLibrary.search(search, muscle: muscle, in: library)
  }

  private var exactMatch: Bool {
    let folded = ExerciseLibrary.fold(search.trimmingCharacters(in: .whitespaces))
    guard !folded.isEmpty else { return false }
    return library.contains { ExerciseLibrary.fold($0.name) == folded }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
          Section {
            if local.isEmpty, remote.isEmpty, remotePhase != .loading, !search.isEmpty {
              ContentUnavailableView.search(text: search)
            } else {
              ForEach(Array(local.enumerated()), id: \.element.id) { index, item in
                ExercisePickerRow(
                  item: item, picked: chosen.contains(item.id),
                  action: { pick(item) }
                )
                .staggeredEntrance(index: index, isReady: true)
                Divider().padding(.leading, 76).opacity(0.6)
              }
              if !remote.isEmpty {
                HStack {
                  Text("wger").font(.caption).foregroundStyle(Color.mutedInk)
                  Spacer()
                  Text("em inglês").font(.caption2).foregroundStyle(Color.mutedInk.opacity(0.7))
                }
                .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 4)
                ForEach(Array(remote.enumerated()), id: \.element.id) { index, item in
                  ExercisePickerRow(
                    item: item, picked: chosen.contains(item.id),
                    action: { pick(item) }
                  )
                  .staggeredEntrance(index: index, isReady: remotePhase == .done)
                  Divider().padding(.leading, 76).opacity(0.6)
                }
                Text("fotos wger.de, CC-BY-SA")
                  .font(.caption2).foregroundStyle(Color.mutedInk.opacity(0.7))
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 16).padding(.vertical, 10)
              } else if remotePhase == .loading {
                ProgressView().controlSize(.small)
                  .frame(maxWidth: .infinity, alignment: .leading).padding(16)
              }
              if !search.trimmingCharacters(in: .whitespaces).isEmpty, !exactMatch {
                Button { createCustom() } label: {
                  HStack(spacing: 12) {
                    Circle().fill(Color.surfaceMuted).frame(width: 56, height: 56)
                      .overlay { Image(systemName: "plus").foregroundStyle(Color.mutedInk) }
                    VStack(alignment: .leading, spacing: 2) {
                      Text("criar \"\(search.trimmingCharacters(in: .whitespaces))\"")
                        .font(.body.weight(.medium)).foregroundStyle(Color.ink)
                      Text(muscle ?? "geral")
                        .font(.caption).foregroundStyle(Color.mutedInk)
                    }
                    Spacer(minLength: 0)
                  }
                  .padding(.horizontal, 16).padding(.vertical, 8)
                  .contentShape(.rect)
                }.buttonStyle(StudyPressStyle())
              }
            }
          } header: {
            VStack(spacing: 10) {
              HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                  .foregroundStyle(Color.mutedInk)
                  .padding(.leading, 2)
                TextField("buscar", text: $search)
                  .submitLabel(.done)
                  .focused($searchFocused)
                  #if os(iOS)
                  .textInputAutocapitalization(.never)
                  #endif
                  .autocorrectionDisabled()
                  .accessibilityLabel("Buscar exercício")
                if !search.isEmpty {
                  Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                      .foregroundStyle(Color.mutedInk)
                      .frame(width: 40, height: 40)
                      .contentShape(.rect)
                  }
                  .buttonStyle(.plain)
                  .accessibilityLabel("Limpar busca")
                }
              }
              .padding(.horizontal, 12).padding(.vertical, 6)
              .background(.white, in: .rect(cornerRadius: 18))
              .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.ink.opacity(0.08)))
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                  MuscleChip(title: "todos", selected: muscle == nil) { muscle = nil }
                  ForEach(ExerciseLibrary.muscleGroups, id: \.self) { group in
                    MuscleChip(title: group.lowercased(), selected: muscle == group) {
                      muscle = muscle == group ? nil : group
                    }
                  }
                }.padding(.horizontal, 16).padding(.vertical, 2)
              }
            }
            .padding(.top, 8).padding(.bottom, 6)
            .background(Color.canvas)
          }
        }
      }
      .background(Color.canvas)
      .navigationTitle("exercícios")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("fechar") { dismiss() }
        }
      }
      .keyboardDone()
      .onAppear { searchFocused = true }
      .onChange(of: search) { scheduleRemote() }
      .onChange(of: muscle) { scheduleRemote() }
    }
  }

  private func pick(_ item: ExerciseCatalogItem) {
    guard !chosen.contains(item.id) else { return }
    onPick(item)
    dismiss()
  }

  private func createCustom() {
    let name = search.trimmingCharacters(in: .whitespaces)
    guard name.count >= 2 else { return }
    let item = ExerciseCatalogItem(
      id: ExerciseLibrary.slug(name), name: name,
      muscleGroup: muscle ?? "Geral", equipment: "Livre", imageUrl: nil)
    guard !chosen.contains(item.id) else { return }
    onPick(item)
    dismiss()
  }

  private func scheduleRemote() {
    lookup?.cancel()
    remote = []
    remotePhase = .idle
    let term = search.trimmingCharacters(in: .whitespaces)
    let scope = library
    let client = wger
    let animated = !reduceMotion
    guard term.count >= 3, local.count < 8 else { return }
    remotePhase = .loading
    lookup = Task {
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }
      do {
        let found = try await client.search(term, excluding: scope)
        guard !Task.isCancelled else { return }
        withAnimation(animated ? .easeOut(duration: 0.2) : nil) {
          remote = found
          remotePhase = .done
        }
      } catch is CancellationError {
        return
      } catch {
        guard !Task.isCancelled else { return }
        remotePhase = .failed
      }
    }
  }
}

private struct MuscleChip: View {
  let title: String
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? .white : Color.ink)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(selected ? Color.ink : .white, in: .capsule)
        .overlay(Capsule().strokeBorder(selected ? .clear : Color.ink.opacity(0.1)))
        .contentShape(.capsule)
    }
    .buttonStyle(StudyPressStyle())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct ExercisePickerRow: View {  let item: ExerciseCatalogItem
  let picked: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        ExerciseThumb(imageUrl: item.imageUrl, size: 56)
        VStack(alignment: .leading, spacing: 3) {
          Text(item.name.lowercased())
            .font(.body.weight(.medium)).foregroundStyle(Color.ink)
            .lineLimit(2)
          Text("\(item.muscleGroup.lowercased()) · \(item.equipment.lowercased())")
            .font(.caption).foregroundStyle(Color.mutedInk)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        if picked {
          Text("no treino").font(.caption2.weight(.medium))
            .foregroundStyle(Color.mutedInk)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.surfaceMuted, in: .capsule)
            .accessibilityLabel("\(item.name) já está no treino")
        } else {
          Image(systemName: "plus.circle.fill")
            .font(.title2).foregroundStyle(Color.ink.opacity(0.75))
            .frame(width: 44, height: 44)
            .contentShape(.rect)
            .accessibilityLabel("Adicionar \(item.name)")
        }
      }
      .padding(.horizontal, 16).padding(.vertical, 8)
      .contentShape(.rect)
      .opacity(picked ? 0.55 : 1)
    }
    .buttonStyle(StudyPressStyle())
    .disabled(picked)
  }
}

#if DEBUG
  #Preview("Seletor de exercícios") {
    ExercisePicker(
      catalog: [
        ExerciseCatalogItem(
          id: "supino-reto-barra", name: "Supino reto com barra", muscleGroup: "Peito",
          equipment: "Barra",
          imageUrl:
            "https://wger.de/media/exercise-images/192/Bench-press-1.png.400x400_q85.png"),
        ExerciseCatalogItem(
          id: "puxada-fechada", name: "Puxada alta pegada fechada", muscleGroup: "Costas",
          equipment: "Cabo",
          imageUrl:
            "https://wger.de/media/exercise-images/158/0d51a0f2-622f-434b-beb8-1a003c54712a.png.400x400_q85.jpg"
        ),
        ExerciseCatalogItem(
          id: "panturrilha-em-pe", name: "Panturrilha em pé", muscleGroup: "Panturrilha",
          equipment: "Peso corporal",
          imageUrl:
            "https://wger.de/media/exercise-images/622/9a429bd0-afd3-4ad0-8043-e9beec901c81.jpeg.400x400_q85.jpg"
        ),
      ],
      chosen: ["supino-reto-barra"]
    ) { _ in }
  }

  #Preview("Linha do exercício") {
    PlanExercisePreview()
  }

  private struct PlanExercisePreview: View {
    @State private var exercise = PlanExercise(
      exerciseId: "panturrilha-em-pe", prepSets: 2, workSets: 2, repsMin: 8, repsMax: 12,
      workToFailure: true, startingWeightKg: 0)

    var body: some View {
      Form {
        PlanExerciseRow(
          exercise: $exercise, name: "Panturrilha em pé",
          subtitle: "panturrilha · peso corporal",
          imageUrl:
            "https://wger.de/media/exercise-images/622/9a429bd0-afd3-4ad0-8043-e9beec901c81.jpeg.400x400_q85.jpg"
        )
      }
    }
  }
#endif
