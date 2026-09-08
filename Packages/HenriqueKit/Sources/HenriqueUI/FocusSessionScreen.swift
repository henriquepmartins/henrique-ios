import HenriqueCore
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

// MARK: - Estado

/// Os quatro momentos do bloco. O tempo corrido sai sempre da diferença entre
/// dois instantes, nunca de uma contagem de ticks, então o app pode ficar
/// minutos no segundo plano sem o cronômetro atrasar.
private enum FocusSessionState {
  case idle(subjectId: String?, minutes: Int)
  case running(
    session: StudySession, subjectId: String?, minutes: Int, since: Date, before: TimeInterval)
  case paused(session: StudySession, subjectId: String?, minutes: Int, elapsed: TimeInterval)
  case done(subjectId: String?, minutes: Int, completed: Int)

  enum Phase: Hashable {
    case idle, timing, done
  }

  var phase: Phase {
    switch self {
    case .idle: .idle
    case .running, .paused: .timing
    case .done: .done
    }
  }

  var subjectId: String? {
    switch self {
    case .idle(let subjectId, _): subjectId
    case .running(_, let subjectId, _, _, _): subjectId
    case .paused(_, let subjectId, _, _): subjectId
    case .done(let subjectId, _, _): subjectId
    }
  }

  var minutes: Int {
    switch self {
    case .idle(_, let minutes): minutes
    case .running(_, _, let minutes, _, _): minutes
    case .paused(_, _, let minutes, _): minutes
    case .done(_, let minutes, _): minutes
    }
  }

  var session: StudySession? {
    switch self {
    case .running(let session, _, _, _, _), .paused(let session, _, _, _): session
    case .idle, .done: nil
    }
  }

  var isRunning: Bool {
    if case .running = self { return true }
    return false
  }

  var total: TimeInterval { Double(minutes) * 60 }

  func elapsed(at now: Date) -> TimeInterval {
    switch self {
    case .running(_, _, _, let since, let before): max(0, before + now.timeIntervalSince(since))
    case .paused(_, _, _, let elapsed): elapsed
    case .idle, .done: 0
    }
  }

  func remaining(at now: Date) -> TimeInterval { max(0, total - elapsed(at: now)) }

  func progress(at now: Date) -> Double {
    total == 0 ? 0 : min(1, elapsed(at: now) / total)
  }

  mutating func pick(subjectId: String?) {
    guard case .idle(_, let minutes) = self else { return }
    self = .idle(subjectId: subjectId, minutes: minutes)
  }

  mutating func block(minutes: Int) {
    guard case .idle(let subjectId, _) = self else { return }
    self = .idle(subjectId: subjectId, minutes: minutes)
  }

  mutating func started(_ session: StudySession, at now: Date) {
    guard case .idle(let subjectId, let minutes) = self else { return }
    self = .running(
      session: session, subjectId: subjectId, minutes: minutes, since: now, before: 0)
  }

  mutating func pause(at now: Date) {
    guard case .running(let session, let subjectId, let minutes, _, _) = self else { return }
    self = .paused(
      session: session, subjectId: subjectId, minutes: minutes, elapsed: elapsed(at: now))
  }

  mutating func resume(at now: Date) {
    guard case .paused(let session, let subjectId, let minutes, let elapsed) = self else { return }
    self = .running(
      session: session, subjectId: subjectId, minutes: minutes, since: now, before: elapsed)
  }

  mutating func finish(completed: Int) {
    switch self {
    case .running(_, let subjectId, let minutes, _, _),
      .paused(_, let subjectId, let minutes, _):
      self = .done(subjectId: subjectId, minutes: minutes, completed: completed)
    case .idle, .done:
      break
    }
  }
}

// MARK: - Tela

public struct FocusSessionScreen: View {
  @Environment(EstudosStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @ScaledMetric(relativeTo: .title3) private var labelSize = 19.0
  @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 34.0
  @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 101.0
  @ScaledMetric(relativeTo: .body) private var rowSize = 16.0
  @ScaledMetric(relativeTo: .subheadline) private var metaSize = 14.0

  @State private var state = FocusSessionState.idle(subjectId: nil, minutes: 25)
  @State private var quickNote = ""
  @State private var noteSession: StudySession?
  @State private var busy = false
  @State private var savingNote = false
  @State private var noteSaved = false
  @State private var startFailed = false
  @State private var finishFailed = false
  @State private var noteFailed = false
  @State private var askLeave = false
  @State private var pendingSessionID: String?

  private let onReview: () -> Void

  public init(onReview: @escaping () -> Void) {
    self.onReview = onReview
  }

  public var body: some View {
    VStack(spacing: 0) {
      topBar
        .padding(.horizontal, 16)
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          stateSection
          if let banner = store.banner {
            metaLine(banner)
          }
          rule
          materialRow
          noteCard
          if noteFailed {
            noteRetry
          }
          rule
          reviewLink
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
      }
      .scrollDismissesKeyboard(.interactively)
    }
    .background(Color.studyBlack.ignoresSafeArea())
    .foregroundStyle(Color.studyCream)
    .tint(Color.studyCream)
    .preferredColorScheme(.dark)
    .task { await store.loadSubjects() }
    .onChange(of: state.isRunning, initial: true) { _, running in
      keepScreenAwake(running)
    }
    .onDisappear { keepScreenAwake(false) }
    .confirmationDialog(
      "há uma sessão ou anotação sem salvar.", isPresented: $askLeave, titleVisibility: .visible
    ) {
      Button("sair e descartar", role: .destructive) { dismiss() }
      Button("continuar no bloco", role: .cancel) {}
    }
  }

  // MARK: Barra de cima

  private var topBar: some View {
    HStack(spacing: 0) {
      Button(action: requestClose) {
        Image(systemName: "xmark")
          .font(.system(size: 20))
          .foregroundStyle(Color.studyCream)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(StudyPressStyle())
      .accessibilityLabel("sair do foco")
      Spacer(minLength: 8)
      StudyEyebrow(
        state.phase == .idle ? "antes de começar" : "bloco de \(state.minutes) min", cream: true)
      Spacer(minLength: 8)
      Color.clear.frame(width: 44, height: 44)
    }
  }

  // MARK: Estados

  @ViewBuilder private var stateSection: some View {
    Group {
      switch state.phase {
      case .idle: idleSection
      case .timing: timingSection
      case .done: doneSection
      }
    }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: state.phase)
  }

  private var idleSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      label("foco", color: .studyMarigold)
      title("O que você vai estudar agora?")
      subjectPicker
        .padding(.top, 28)
      StudyWrap(spacing: 8, lineSpacing: 8) {
        ForEach([15, 25, 50], id: \.self) { minutes in
          FocusSessionCapsule(active: minutes == state.minutes) {
            state.block(minutes: minutes)
          } label: {
            Text("\(minutes) min")
          }
          .disabled(busy || startFailed)
        }
      }
      .padding(.top, 28)
      FocusSessionGradientButton(
        title: "começar o bloco", systemImage: "play.fill",
        action: { Task { await start() } })
        .disabled(busy)
        .padding(.top, 28)
      if startFailed {
        metaLine("o bloco não abriu no servidor. Tente de novo em um instante.")
          .padding(.top, 10)
      }
    }
    .transition(.opacity)
  }

  @ViewBuilder private var subjectPicker: some View {
    switch store.subjects {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, alignment: .leading)
    case .failed(let message):
      metaLine(message)
    case .ready(let list) where list.isEmpty:
      StudyEmptyState(
        icon: "book",
        title: "sem matérias para escolher",
        detail:
          "Nenhuma matéria chegou do portal ainda. Rode a sincronização em estudos e as suas disciplinas aparecem aqui para escolher.",
        cream: true)
    case .ready(let list):
      StudyWrap(spacing: 8, lineSpacing: 8) {
        ForEach(list) { item in
          FocusSessionCapsule(active: item.id == state.subjectId) {
            state.pick(subjectId: item.id == state.subjectId ? nil : item.id)
          } label: {
            HStack(spacing: 8) {
              StudyDot(color: item.color)
              Text(item.name)
            }
          }
          .disabled(busy || startFailed)
        }
      }
    }
  }

  private var timingSection: some View {
    FocusSessionTicker(running: state.isRunning) { now in
      timingReadout(now: now)
    }
    .transition(.opacity)
  }

  private func timingReadout(now: Date) -> some View {
    let remaining = state.remaining(at: now)
    return VStack(alignment: .leading, spacing: 0) {
      label(subjectName ?? "foco livre", color: .studyMarigold)
      title(isPaused ? "pausado" : "bloco de \(state.minutes) min")
      Text(StudyFormat.clock(remaining))
        .font(.system(size: timerSize, weight: .semibold).leading(.tight))
        .monospacedDigit()
        .tracking(-timerSize * 0.011)
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .padding(.top, 28)
        .accessibilityLabel("faltam \(StudyFormat.minutes(Int(remaining / 60)))")
      progressBar(fraction: state.progress(at: now))
        .padding(.top, 24)
      HStack(spacing: 12) {
        Text("\(StudyFormat.minutes(Int(state.elapsed(at: now) / 60))) feitos")
        Spacer(minLength: 0)
        Text("termina às \(StudyFormat.hour(now.addingTimeInterval(remaining)))")
      }
      .font(.system(size: metaSize))
      .monospacedDigit()
      .foregroundStyle(Color.studyCream50)
      .padding(.top, 10)
      StudyWrap(spacing: 8, lineSpacing: 8) {
        FocusSessionCapsule {
          if isPaused {
            state.resume(at: .now)
          } else {
            state.pause(at: .now)
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill").font(.system(size: 16))
            Text(isPaused ? "retomar" : "pausar")
          }
        }
        .disabled(busy)
        FocusSessionGradientButton(
          title: finishTitle, systemImage: "checkmark", action: { Task { await finish() } })
          .disabled(busy)
      }
      .padding(.top, 28)
      if finishFailed {
        metaLine("não deu para salvar o bloco. o tempo está pausado. tente concluir de novo.")
          .padding(.top, 10)
      }
    }
    .onChange(of: remaining == 0) { _, expired in
      guard expired, state.isRunning else { return }
      Task { await finish() }
    }
  }

  private var doneSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      label(subjectName ?? "foco livre", color: .studyMarigold)
      title("bloco concluído")
      Text(StudyFormat.minutes(completedMinutes))
        .font(.system(size: timerSize, weight: .semibold).leading(.tight))
        .monospacedDigit()
        .tracking(-timerSize * 0.011)
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .padding(.top, 28)
      Text(noteStatus)
        .font(.system(size: metaSize))
        .monospacedDigit()
        .foregroundStyle(Color.studyCream50)
        .padding(.top, 10)
      FocusSessionCapsule(action: { dismiss() }) {
        Text("voltar para estudos")
      }
      .padding(.top, 28)
    }
    .transition(.opacity)
  }

  // MARK: Peças de baixo

  private var rule: some View {
    Rectangle().fill(Color.studyCream25).frame(height: 1)
  }

  private var materialRow: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "doc.richtext")
        .font(.system(size: 20))
        .foregroundStyle(Color.studyCream50)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text("sem material aberto")
          .font(.system(size: rowSize))
          .foregroundStyle(Color.studyCream)
        Text("escolha um slide na matéria e a sessão abre na página onde você parou")
          .font(.system(size: metaSize))
          .foregroundStyle(Color.studyCream50)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
  }

  private var noteCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        StudyEyebrow("anotação rápida", cream: true)
        Spacer(minLength: 0)
        StudyPill(tone: .cream, text: subjectName ?? "sem matéria")
      }
      TextEditor(text: $quickNote)
        .font(.system(size: rowSize))
        .foregroundStyle(Color.studyCream)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 72)
        .overlay(alignment: .topLeading) {
          if quickNote.isEmpty {
            Text("O que ficou claro, o que ficou confuso, uma pergunta para a próxima aula.")
              .font(.system(size: rowSize))
              .foregroundStyle(Color.studyCream50)
              .padding(.top, 8)
              .padding(.leading, 5)
              .allowsHitTesting(false)
          }
        }
        .disabled(busy || savingNote || (state.phase == .done && noteSaved))
      HStack(spacing: 12) {
        Text("salva no app quando o bloco fecha")
        Spacer(minLength: 0)
        Image(systemName: "arrow.right").font(.system(size: 16))
      }
      .font(.system(size: metaSize))
      .foregroundStyle(Color.studyCream50)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.studyOffBlack, in: .rect(cornerRadius: StudyRadius.outer))
  }

  private var noteRetry: some View {
    VStack(alignment: .leading, spacing: 12) {
      metaLine("a anotação não foi salva. o texto continua aqui.")
      FocusSessionCapsule(action: { Task { await retryNote() } }) {
        Text("tentar salvar anotação")
      }
      .disabled(savingNote || noteSession == nil)
    }
  }

  private var reviewLink: some View {
    Button {
      dismiss()
      onReview()
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("depois daqui, os cartões do dia")
            .font(.system(size: rowSize))
            .foregroundStyle(Color.studyCream)
          Text("a fila de revisão fecha o ciclo da aula")
            .font(.system(size: metaSize))
            .foregroundStyle(Color.studyCream50)
        }
        .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
        Image(systemName: "arrow.right")
          .font(.system(size: 20))
          .foregroundStyle(Color.studyCream)
      }
      .frame(minHeight: 44)
      .contentShape(.rect)
    }
    .buttonStyle(StudyPressStyle())
  }

  // MARK: Fragmentos

  private func label(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: labelSize))
      .foregroundStyle(color)
      .lineLimit(1)
  }

  private func title(_ text: String) -> some View {
    Text(text)
      .font(.system(size: titleSize, weight: .semibold).leading(.tight))
      .tracking(-titleSize * 0.01)
      .foregroundStyle(Color.studyCream)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 6)
      .accessibilityAddTraits(.isHeader)
  }

  private func metaLine(_ text: String) -> some View {
    Text(text)
      .font(.system(size: metaSize))
      .foregroundStyle(Color.studyCream50)
      .fixedSize(horizontal: false, vertical: true)
  }

  /// A fração já chega contínua do relógio, então animar a largura só deixaria
  /// a barra atrás do número.
  private func progressBar(fraction: Double) -> some View {
    Rectangle()
      .fill(Color.studyCream25)
      .frame(height: 2)
      .overlay(alignment: .leading) {
        GeometryReader { proxy in
          focusSessionGreen
            .frame(width: proxy.size.width * fraction)
        }
      }
      .clipShape(.rect)
      .accessibilityHidden(true)
  }

  // MARK: Valores derivados

  private var isPaused: Bool { state.phase == .timing && !state.isRunning }

  private var subjectName: String? {
    guard let id = state.subjectId else { return nil }
    return store.subjects.value?.first { $0.id == id }?.name
  }

  private var completedMinutes: Int {
    guard case .done(_, _, let completed) = state else { return 0 }
    return completed
  }

  private var finishTitle: String {
    if busy { return "salvando bloco…" }
    return finishFailed ? "tentar concluir de novo" : "concluir bloco"
  }

  private var noteStatus: String {
    if savingNote { return "salvando anotação…" }
    if noteSaved { return "anotação salva no app" }
    return trimmedNote.isEmpty ? "sem anotação nesta sessão" : "anotação ainda não salva"
  }

  private var trimmedNote: String {
    quickNote.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var hasUnsavedNote: Bool { !trimmedNote.isEmpty && !noteSaved }

  // MARK: Ações

  private func requestClose() {
    if state.phase == .timing || hasUnsavedNote {
      askLeave = true
    } else {
      dismiss()
    }
  }

  private func start() async {
    guard case .idle = state, !busy else { return }
    busy = true
    startFailed = false
    // O servidor deduplica a sessão pelo id, então uma retentativa com o mesmo
    // id não deixa um bloco órfão aberto.
    let id = pendingSessionID ?? UUID().uuidString.lowercased()
    pendingSessionID = id
    do {
      let session = try await store.startSession(id: id, subjectId: state.subjectId)
      state.started(session, at: .now)
      pendingSessionID = nil
    } catch {
      startFailed = true
    }
    busy = false
  }

  private func finish() async {
    guard state.phase == .timing, !busy else { return }
    busy = true
    finishFailed = false
    state.pause(at: .now)
    guard let session = state.session else {
      busy = false
      return
    }
    let completed = min(state.minutes, Int((state.elapsed(at: .now) / 60).rounded()))
    do {
      let saved = try await store.finishSession(id: session.id, minutes: completed)
      noteSession = saved
      state.finish(completed: saved.completedMinutes)
      busy = false
      await saveQuickNote(saved)
    } catch {
      finishFailed = true
      busy = false
    }
  }

  private func retryNote() async {
    guard let session = noteSession else { return }
    await saveQuickNote(session)
  }

  private func saveQuickNote(_ session: StudySession) async {
    let text = trimmedNote
    guard !text.isEmpty, !savingNote else { return }
    savingNote = true
    noteFailed = false
    do {
      try await store.saveNote(
        SaveNoteInput(
          path: "notas/sessoes/\(session.startedAt.formatted(Self.noteDay))-\(session.id).md",
          title: "sessão de \(StudyFormat.weekdayLong(session.startedAt))",
          subjectId: session.subjectId,
          tags: ["sessão"],
          body: text))
      noteSaved = true
    } catch {
      noteFailed = true
    }
    savingNote = false
  }

  private func keepScreenAwake(_ awake: Bool) {
    #if canImport(UIKit)
      UIApplication.shared.isIdleTimerDisabled = awake
    #endif
  }

  /// O caminho da nota no web sai da fatia da string ISO, que é UTC. Trocar
  /// pelo fuso do aparelho daria outro arquivo para a mesma sessão.
  private static let noteDay = Date.ISO8601FormatStyle().year().month().day()
    .dateSeparator(.dash)
}

// MARK: - Peças

private let focusSessionGreen = LinearGradient(
  colors: [.studyGreen, .studyLightGreen], startPoint: .topLeading, endPoint: .bottomTrailing)

/// O tick só existe enquanto o bloco corre. Parado, o tempo já está guardado no
/// estado e redesenhar quatro vezes por segundo não mudaria nada na tela.
private struct FocusSessionTicker<Content: View>: View {
  let running: Bool
  @ViewBuilder let content: (Date) -> Content

  var body: some View {
    if running {
      TimelineView(.periodic(from: .now, by: 0.25)) { context in
        content(context.date)
      }
    } else {
      content(.now)
    }
  }
}

private struct FocusSessionCapsule<Label: View>: View {
  var active = false
  let action: () -> Void
  @ViewBuilder let label: Label

  var body: some View {
    Button(action: action) {
      label
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(active ? Color.studyBlack : Color.studyCream)
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .frame(minHeight: 44)
        .background(active ? Color.studyCream : .clear, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.studyCream))
        .contentShape(.capsule)
    }
    .buttonStyle(StudyPressStyle())
    .accessibilityAddTraits(active ? .isSelected : [])
  }
}

private struct FocusSessionGradientButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: systemImage).font(.system(size: 16))
        Text(title)
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color.studyCream)
      .padding(.vertical, 10)
      .padding(.horizontal, 20)
      .frame(minHeight: 44)
      .overlay(Capsule().strokeBorder(focusSessionGreen, lineWidth: 1.5))
      .contentShape(.capsule)
    }
    .buttonStyle(StudyPressStyle())
  }
}
