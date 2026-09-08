import HenriqueCore
import SwiftUI

/// O bloco de foco é de 50 minutos porque é o que o cronômetro da sessão conta.
/// Mudar aqui sem mudar lá faz a promessa da home mentir.
private let blocoMinutos = 50

public struct StudyTodayScreen: View {
  @Environment(EstudosStore.self) private var store
  let onSession: () -> Void
  let onAssignments: () -> Void
  let onReview: () -> Void

  public init(
    onSession: @escaping () -> Void, onAssignments: @escaping () -> Void,
    onReview: @escaping () -> Void
  ) {
    self.onSession = onSession
    self.onAssignments = onAssignments
    self.onReview = onReview
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        switch store.overview {
        case .idle, .loading:
          StudyLoadingState(phase: "carregando o dia").transition(.opacity)
        case .failed(let message):
          StudyFailedState(message: message) { Task { await store.loadOverview(force: true) } }
            .transition(.opacity)
        case .ready(let overview):
          VStack(alignment: .leading, spacing: 20) {
            StudyHeading(
              eyebrow: StudyFormat.weekdayLong(overview.date.date(in: StudyFormat.calendar)),
              title: saudacao())
            StudyTodayHero(overview: overview, onSession: onSession, onAssignments: onAssignments)
            StudyTodayMetrics(overview: overview)
            StudyTodayPending(overview: overview, onAssignments: onAssignments)
            StudyTodayContinue(overview: overview, onSession: onSession, onReview: onReview)
          }
          .transition(.opacity)
        }
      }
      .animation(.easeOut(duration: 0.25), value: store.overview.phase)
      .padding(.horizontal, 16)
      .padding(.bottom, 32)
    }
    .studyPage()
    .task { await store.loadOverview() }
    .refreshable { await store.loadOverview(force: true) }
  }
}

/// A saudação é o único texto em caixa alta da tela, como no web.
private func saudacao(now: Date = Date()) -> String {
  let hour = StudyFormat.calendar.component(.hour, from: now)
  if hour < 12 { return "Bom dia, Henrique." }
  if hour < 18 { return "Boa tarde, Henrique." }
  return "Boa noite, Henrique."
}

private func contagem(_ total: Int, _ singular: String, _ plural: String) -> String {
  "\(total) \(total == 1 ? singular : plural)"
}

// MARK: - Herói

struct StudyTodayHero: View {
  let overview: StudyOverview
  let onSession: () -> Void
  let onAssignments: () -> Void

  var body: some View {
    let focus = StudyFocus(overview: overview)
    StudyCard {
      VStack(alignment: .leading, spacing: 12) {
        StudyWrap {
          if let subject = focus.subject {
            StudyPill(color: subject.color, text: subject.name)
          }
          StudyPill(tone: .outline, systemImage: "clock", text: StudyFormat.minutes(blocoMinutos))
        }
        StudyHeroTitle(words: focus.heroWords)
        Text(focus.line(now: overview.date.date(in: StudyFormat.calendar)))
          .font(.subheadline)
          .foregroundStyle(Color.studyGraphite)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 8) {
          Button("começar sessão", systemImage: "play.fill", action: onSession)
            .buttonStyle(.glassProminent)
            .tint(.studyBlue)
          Button("ver a semana", action: onAssignments)
            .buttonStyle(.glass)
        }
        .font(.subheadline)
        .padding(.top, 4)
      }
    }
  }
}

struct StudyTodayMetrics: View {
  let overview: StudyOverview

  var body: some View {
    HStack(spacing: 8) {
      StudyMetric(
        value: StudyFormat.minutes(overview.weekMinutes), caption: "de estudo nesta semana")
      StudyMetric(
        value: "\(overview.dueSoon.count { $0.status == .done })/\(overview.dueSoon.count)",
        caption: "entregas feitas")
      StudyMetric(value: "\(overview.reviewCount)", caption: "cartões para revisar")
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

// MARK: - Pendências

struct StudyTodayPending: View {
  @Environment(EstudosStore.self) private var store
  let overview: StudyOverview
  let onAssignments: () -> Void

  var body: some View {
    let now = overview.date.date(in: StudyFormat.calendar)
    VStack(alignment: .leading, spacing: 0) {
      StudySectionHeading(title: "pendências", action: ("ver todas", onAssignments))
      VStack(spacing: 8) {
        if let sync = overview.lastSync {
          StudyCallout(
            icon: "arrow.triangle.2.circlepath", tone: .sky,
            title: "portal sincronizado \(StudyFormat.relative(sync.completedAt, now: Date()))",
            detail: syncDetail(sync))
        }
        if overview.dueSoon.isEmpty {
          StudyEmptyState(
            icon: "calendar", title: "nada no radar",
            detail:
              "o portal sincroniza sozinho a cada 15 minutos. o que ele achar de prazo aparece aqui, com a matéria e a hora exata do envio.")
        } else {
          ForEach(Array(overview.dueSoon.enumerated()), id: \.element.id) { index, item in
            StudyTaskCard(assignment: item, now: now) { next in
              Task { await store.setStatus(of: item, to: next) }
            }
            .staggeredEntrance(index: index, isReady: true)
          }
        }
      }
    }
  }

  private func syncDetail(_ sync: SyncLog) -> String {
    let created = contagem(sync.createdCount, "entrega nova", "entregas novas")
    return "\(created) · \(contagem(sync.existingCount, "já conhecida", "já conhecidas"))"
  }
}

// MARK: - Continuar

struct StudyTodayContinue: View {
  let overview: StudyOverview
  let onSession: () -> Void
  let onReview: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StudySectionHeading(title: "continuar")
      if overview.reviewCount == 0, overview.lastSession == nil {
        StudyEmptyState(
          icon: "rectangle.on.rectangle", title: "nada em andamento",
          detail:
            "quando você fechar uma sessão de foco ou revisar um cartão, o ponto onde parou fica guardado aqui para retomar no dia seguinte.")
      } else {
        StudyDbList {
          if overview.reviewCount > 0 {
            StudyDbRow(
              icon: "rectangle.on.rectangle",
              title: contagem(overview.reviewCount, "cartão vence hoje", "cartões vencem hoje"),
              detail: "fila de revisão, na ordem do que vence antes",
              end: { StudyPill(tone: .coral, text: "hoje") },
              action: onReview)
          }
          if let session = overview.lastSession {
            StudyDbRow(
              icon: "timer", title: "retomar de onde parou", detail: sessionDetail(session),
              action: onSession)
          }
        }
      }
    }
  }

  private func sessionDetail(_ session: StudySession) -> String {
    let minutes = StudyFormat.minutes(session.completedMinutes)
    return "\(minutes) · \(StudyFormat.relative(session.startedAt, now: Date()))"
  }
}

// MARK: - Foco do dia

/// Quem manda no herói. A matéria sai da entrega pendente mais próxima; sem
/// entrega, da última sessão; sem sessão, da primeira matéria da lista.
struct StudyFocus {
  struct Subject {
    let name: String
    let color: String?
  }

  let subject: Subject?
  let assignment: StudyAssignment?
  private let lastSession: StudySession?

  init(overview: StudyOverview) {
    assignment = overview.dueSoon.first { $0.status != .done }
    lastSession = overview.lastSession
    if let withSubject = overview.dueSoon.first(where: {
      $0.status != .done && $0.subjectName != nil
    }), let name = withSubject.subjectName {
      subject = Subject(name: name, color: withSubject.subjectColor)
    } else if let first = overview.subjects.first(where: {
      $0.id == overview.lastSession?.subjectId
    }) ?? overview.subjects.first {
      subject = Subject(name: first.name, color: first.color)
    } else {
      subject = nil
    }
  }

  func line(now: Date) -> String {
    if let assignment {
      return "\(assignment.title) vence \(StudyFormat.due(assignment.dueAt, now: now))."
    }
    if let lastSession {
      // O prazo se mede em dias, e "há 3 h" se mede no relógio. O meio-dia da
      // data do overview serve ao primeiro e faria a tarde inteira virar "agora".
      let when = StudyFormat.relative(lastSession.startedAt, now: Date())
      let clock = StudyFormat.minutes(lastSession.completedMinutes)
      return "Sua última sessão foi \(when), com \(clock) no relógio."
    }
    return
      "Nada marcado para hoje. Um bloco de \(StudyFormat.minutes(blocoMinutos)) já dá para abrir os slides e sair com uma nota escrita."
  }

  /// O destaque cobre a primeira palavra da matéria, então a frase é montada
  /// palavra por palavra para o pêssego terminar onde a palavra termina.
  var heroWords: [StudyHeroWord] {
    guard let subject else {
      return StudyHeroWord.line("ainda não tem", highlight: "matéria", tail: "nenhuma por aqui.")
    }
    let name = subject.name.lowercased(with: StudyFormat.locale)
    guard let space = name.firstIndex(of: " ") else {
      return StudyHeroWord.line("hoje é dia de", highlight: name, tail: ".")
    }
    return StudyHeroWord.line(
      "hoje é dia de", highlight: String(name[name.startIndex..<space]),
      tail: "\(name[name.index(after: space)...]).")
  }
}

// MARK: - Título do herói

struct StudyHeroWord: Identifiable {
  let id: Int
  let text: String
  let highlighted: Bool

  /// Um ponto final logo depois do destaque gruda nele, senão a pontuação cai
  /// sozinha na linha de baixo.
  static func line(_ head: String, highlight: String, tail: String) -> [StudyHeroWord] {
    var words = head.split(separator: " ").map { (String($0), false) }
    if tail == "." {
      words.append(("\(highlight).", true))
    } else {
      words.append((highlight, true))
      words += tail.split(separator: " ").map { (String($0), false) }
    }
    return words.enumerated().map { StudyHeroWord(id: $0, text: $1.0, highlighted: $1.1) }
  }
}

struct StudyHeroTitle: View {
  @ScaledMetric(relativeTo: .title) private var size = 30.0
  let words: [StudyHeroWord]

  var body: some View {
    StudyWrap(spacing: size * 0.24, lineSpacing: 2) {
      ForEach(words) { word in
        Text(word.text)
          .padding(.horizontal, word.highlighted ? 10 : 0)
          .background(word.highlighted ? Color.studyPeach : .clear, in: .capsule)
      }
    }
    .font(.system(size: size, weight: .semibold))
    .tracking(-size * 0.03)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}
