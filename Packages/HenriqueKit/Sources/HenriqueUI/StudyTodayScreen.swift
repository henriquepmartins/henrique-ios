import HenriqueCore
import SwiftUI

/// A sessão de foco é de 50 minutos porque é o que o cronômetro dela conta.
/// Mudar aqui sem mudar lá faz a promessa da home mentir.
private let blocoMinutos = 50

public struct StudyTodayScreen: View {
  @Environment(EstudosStore.self) private var store
  /// O espaço que liga o botão de começar à sessão que ele abre. Mora na raiz
  /// das abas, que é quem apresenta a sessão, do mesmo jeito que a academia faz.
  let sessionSource: Namespace.ID
  let onSession: () -> Void
  let onAssignments: () -> Void
  let onReview: () -> Void

  public init(
    sessionSource: Namespace.ID, onSession: @escaping () -> Void,
    onAssignments: @escaping () -> Void, onReview: @escaping () -> Void
  ) {
    self.sessionSource = sessionSource
    self.onSession = onSession
    self.onAssignments = onAssignments
    self.onReview = onReview
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        switch store.overview {
        case .idle, .loading:
          StudyLoadingState().transition(.blurReplace)
        case .failed(let message):
          StudyFailedState(message: message) { Task { await store.loadOverview(force: true) } }
            .transition(.blurReplace)
        case .ready(let overview):
          // A tela chegava inteira num quadro só. Numerar os blocos faz a
          // abertura descer de cima para baixo, na ordem em que o olho lê, e o
          // índice de cada um é o que os cards de pendência continuam a partir.
          VStack(alignment: .leading, spacing: 20) {
            StudyHeading(
              title: StudyFormat.weekdayLong(overview.date.date(in: StudyFormat.calendar)))
              .staggeredEntrance(index: 0, isReady: true)
            StudyTodayHero(overview: overview, sessionSource: sessionSource, onSession: onSession)
              .staggeredEntrance(index: 1, isReady: true)
            StudyTodayMetrics(overview: overview)
              .staggeredEntrance(index: 2, isReady: true)
            StudyTodayPending(overview: overview, onAssignments: onAssignments, base: 3)
            if overview.reviewCount > 0 || overview.lastSession != nil {
              StudyTodayContinue(overview: overview, onSession: onSession, onReview: onReview)
                .staggeredEntrance(index: 5, isReady: true)
            }
          }
          .transition(.blurReplace)
        }
      }
      .animation(Motion.crossfade, value: store.overview.phase)
      .padding(.horizontal, 16)
      .padding(.bottom, 32)
    }
    .studyPage()
    .task { await store.loadOverview() }
    .refreshable { await store.loadOverview(force: true) }
  }
}

private func contagem(_ total: Int, _ singular: String, _ plural: String) -> String {
  "\(total) \(total == 1 ? singular : plural)"
}

// MARK: - Herói

struct StudyTodayHero: View {
  let overview: StudyOverview
  let sessionSource: Namespace.ID
  let onSession: () -> Void

  var body: some View {
    let focus = StudyFocus(overview: overview)
    StudyCard {
      VStack(alignment: .leading, spacing: 12) {
        StudyPill(tone: .outline, systemImage: "clock", text: StudyFormat.minutes(blocoMinutos))
        StudyHeroTitle(words: focus.heroWords)
        if let line = focus.line(now: overview.date.date(in: StudyFormat.calendar)) {
          Text(line)
            .font(.subheadline)
            .foregroundStyle(Color.studyGraphite)
            .fixedSize(horizontal: false, vertical: true)
        }
        Button("começar", systemImage: "play.fill", action: onSession)
          .buttonStyle(.glassProminent)
          .tint(.studyBlue)
          .font(.subheadline)
          .padding(.top, 4)
          .matchedTransitionSource(id: "sessao", in: sessionSource)
      }
    }
  }
}

struct StudyTodayMetrics: View {
  let overview: StudyOverview

  var body: some View {
    HStack(spacing: 8) {
      StudyMetric(value: StudyFormat.minutes(overview.weekMinutes), caption: "na semana")
      StudyMetric(
        value: "\(overview.dueSoon.count { $0.status == .done })/\(overview.dueSoon.count)",
        caption: "entregas")
      StudyMetric(value: "\(overview.reviewCount)", caption: "cartões")
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

// MARK: - Pendências

struct StudyTodayPending: View {
  @Environment(EstudosStore.self) private var store
  let overview: StudyOverview
  let onAssignments: () -> Void
  /// Onde este bloco entra na cascata da tela. Os cards continuam daqui, então
  /// eles nunca chegam antes do próprio título.
  var base = 0

  var body: some View {
    let now = overview.date.date(in: StudyFormat.calendar)
    VStack(alignment: .leading, spacing: 0) {
      StudySectionHeading(title: "pendências", action: ("ver todas", onAssignments))
        .staggeredEntrance(index: base, isReady: true)
      VStack(spacing: 8) {
        if let sync = overview.lastSync {
          StudyCallout(
            icon: "arrow.triangle.2.circlepath", tone: .sky,
            title: "sincronizado \(StudyFormat.relative(sync.completedAt, now: Date()))",
            detail: contagem(sync.createdCount, "nova", "novas"))
            .staggeredEntrance(index: base + 1, isReady: true)
        }
        if overview.dueSoon.isEmpty {
          StudyEmptyState(icon: "calendar", title: "sem entregas")
            .staggeredEntrance(index: base + 1, isReady: true)
        } else {
          ForEach(Array(overview.dueSoon.enumerated()), id: \.element.id) { index, item in
            StudyTaskCard(assignment: item, now: now) { next in
              Task { await store.setStatus(of: item, to: next) }
            }
            .staggeredEntrance(index: base + 1 + index, isReady: true)
          }
        }
      }
    }
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
      StudyDbList {
        if overview.reviewCount > 0 {
          StudyDbRow(
            icon: "rectangle.on.rectangle",
            title: contagem(overview.reviewCount, "cartão", "cartões"),
            end: { StudyPill(tone: .coral, text: "hoje") },
            action: onReview)
        }
        if let session = overview.lastSession {
          StudyDbRow(
            icon: "timer", title: "retomar", detail: sessionDetail(session), action: onSession)
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

  func line(now: Date) -> String? {
    if let assignment {
      return "\(assignment.title) · \(StudyFormat.due(assignment.dueAt, now: now))"
    }
    if let lastSession {
      // O prazo se mede em dias, e "há 3 h" se mede no relógio. O meio-dia da
      // data do overview serve ao primeiro e faria a tarde inteira virar "agora".
      let when = StudyFormat.relative(lastSession.startedAt, now: Date())
      let clock = StudyFormat.minutes(lastSession.completedMinutes)
      return "\(clock) · \(when)"
    }
    return nil
  }

  /// O destaque cobre a primeira palavra da matéria, então a frase é montada
  /// palavra por palavra para o pêssego terminar onde a palavra termina.
  var heroWords: [StudyHeroWord] {
    guard let subject else { return StudyHeroWord.line(head: "sem", highlight: "matérias") }
    let name = subject.name.lowercased(with: StudyFormat.locale)
    guard let space = name.firstIndex(of: " ") else {
      return StudyHeroWord.line(highlight: name)
    }
    return StudyHeroWord.line(
      highlight: String(name[name.startIndex..<space]),
      tail: String(name[name.index(after: space)...]))
  }
}

// MARK: - Título do herói

struct StudyHeroWord: Identifiable {
  let id: Int
  let text: String
  let highlighted: Bool

  static func line(head: String = "", highlight: String, tail: String = "") -> [StudyHeroWord] {
    let plain = { (text: String) in text.split(separator: " ").map { (String($0), false) } }
    let words = plain(head) + [(highlight, true)] + plain(tail)
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
