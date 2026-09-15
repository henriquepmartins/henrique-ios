import HenriqueCore
import SwiftUI

public struct TodayScreen: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var compact = false
  @State private var openIds: Set<String> = []
  @State private var notch: CGFloat = 0.5
  let onPlan: () -> Void
  let onProgress: () -> Void

  public init(onPlan: @escaping () -> Void = {}, onProgress: @escaping () -> Void = {}) {
    self.onPlan = onPlan
    self.onProgress = onProgress
  }

  public var body: some View {
    ScrollViewReader { scroll in
      ScrollView {
        VStack(spacing: 36) {
          VStack(spacing: 12) {
            DayStrip(selected: store.selectedDate, notch: $notch)
            WorkoutHero(workout: store.dashboard?.workout, notch: notch) {
              withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                scroll.scrollTo("exercises", anchor: .top)
              }
            }
            .opacity(store.dashboard?.date == store.selectedDate ? 1 : 0.5)
            .overlay {
              if store.dashboard != nil && store.dashboard?.date != store.selectedDate {
                ProgressView("Carregando treino…")
                  .font(.caption)
                  .padding(12)
                  .background(.regularMaterial, in: .capsule)
              }
            }
            .animation(.easeOut(duration: 0.16), value: store.dashboard?.date == store.selectedDate)
          }
          if let workout = store.dashboard?.workout {
            VStack(spacing: 14) {
              HStack {
                VStack(alignment: .leading, spacing: 6) {
                  Text("plano do dia").font(.caption).foregroundStyle(Color.mutedInk)
                  Text("seus exercícios").font(.title2.weight(.medium)).tracking(-0.8)
                }
                Spacer()
                Picker("Modo de exibição", selection: $compact) {
                  Image(systemName: "list.bullet").tag(true)
                  Image(systemName: "rectangle.grid.1x2").tag(false)
                }.pickerStyle(.segmented).frame(width: 96)
                .onChange(of: compact) {
                  openIds = compact ? [] : Set(workout.exercises.map(\.id))
                }
              }
              HStack {
                Button("evolução", systemImage: "chart.xyaxis.line", action: onProgress)
                Spacer()
                Button("editar semana", systemImage: "square.and.pencil", action: onPlan)
              }.font(.caption).buttonStyle(.glass)
              ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseCard(exercise: exercise, isOpen: openIds.contains(exercise.id)) {
                  withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 1)) {
                    if !openIds.insert(exercise.id).inserted { openIds.remove(exercise.id) }
                  }
                }
                .staggeredEntrance(index: index, isReady: true)
              }
            }.id("exercises").disabled(store.dashboard?.date != store.selectedDate)
          } else if store.dashboard != nil {
            VStack(alignment: .leading, spacing: 14) {
              Image(systemName: "dumbbell").font(.title2)
              Text("nenhum exercício para hoje").font(.title2.weight(.medium))
              Text("Use o plano semanal para mover um treino ou criar uma sessão leve.")
                .font(.subheadline).foregroundStyle(Color.mutedInk)
              Button("abrir plano", action: onPlan).buttonStyle(.glass)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24).paperCard(radius: 32)
              .id("exercises")
          }
        }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
      }
      .scrollBounceBehavior(.basedOnSize)
      .refreshable { await store.load() }
      .overlay { TodayPlaceholder(phase: store.phase, isEmpty: store.dashboard == nil) }
      .onChange(of: store.dashboard?.workout?.id, initial: true) {
        let exercises = store.dashboard?.workout?.exercises ?? []
        openIds = Set(exercises.filter { $0.id == exercises.first?.id || $0.sets.completedWorkCount > 0 }.map(\.id))
      }
    }
  }
}

/// O aviso cobre a tela enquanto não há painel. A troca para o conteúdo é só
/// opacidade, então ele mesmo guarda o `isEmpty` que a anima nos dois usos.
struct TodayPlaceholder: View {
  let phase: AcademiaStore.Phase
  let isEmpty: Bool

  var body: some View {
    ZStack {
      if isEmpty {
        switch phase {
        case .loading:
          ProgressView().controlSize(.large).transition(.opacity)
        case .failed(let message):
          ContentUnavailableView(
            "Não carregou", systemImage: "wifi.exclamationmark", description: Text(message))
            .transition(.opacity)
        case .idle, .ready:
          EmptyView()
        }
      }
    }
    .animation(.easeOut(duration: 0.25), value: isEmpty)
  }
}

struct WorkoutHero: View {
  @Environment(\.accent) private var accent
  @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 46.0
  let workout: WorkoutSummary?
  let notch: CGFloat
  let onStart: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(workout == nil ? "dia de recuperação" : "treino de hoje")
        Spacer()
        if let workout { Label("\(workout.estimatedMinutes) min", systemImage: "clock") }
      }.font(.caption).foregroundStyle(accent.deep)
      Text(workout?.name.lowercased() ?? "descanso")
        .font(.system(size: titleSize, weight: .medium)).tracking(-titleSize * 0.055)
        .fixedSize(horizontal: false, vertical: true)
      Text(workout?.focus ?? "Sem treino programado. Mobilidade e uma caminhada curta já contam.")
        .font(.subheadline).foregroundStyle(accent.deep)
      if let workout {
        VStack(alignment: .leading, spacing: 12) {
          Text("\(workout.exerciseCount) exercícios, \(workout.workSetCount) séries valendo")
            .font(.subheadline)
          Text(workout.completionPercent > 0
            ? "\(workout.completionPercent)% concluído. Continue de onde parou."
            : "Seu plano está pronto para começar.")
            .font(.caption).foregroundStyle(Color.mutedInk)
          Button(workout.completionPercent > 0 ? "continuar" : "começar", systemImage: "play.fill", action: onStart)
            .buttonStyle(.glassProminent).tint(accent.deep).foregroundStyle(.white).controlSize(.large)
        }.padding(.top, 10)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 250, alignment: .leading)
    .padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 24)
    .background(alignment: .topTrailing) {
      ZStack {
        ForEach([280.0, 188.0, 96.0], id: \.self) { size in
          Circle().stroke(accent.deep.opacity(0.20), lineWidth: 1).frame(width: size, height: size)
        }
      }.frame(width: 280, height: 280).offset(x: 92, y: -20).accessibilityHidden(true)
    }
    .background(accent.acid)
    .clipShape(.rect(cornerRadius: 32))
    .overlay(RoundedRectangle(cornerRadius: 32).strokeBorder(accent.deep.opacity(0.13)))
    .padding(8)
    .background(accent.acid.mix(with: accent.signal, by: 0.18))
    .overlay(alignment: .top) { HeroNotch(center: notch).fill(Color.canvas).frame(height: 24) }
    .clipShape(.rect(cornerRadius: 40))
    .shadow(color: accent.deep.opacity(0.1), radius: 24, y: 14)
  }
}

struct HeroNotch: Shape {
  var center: CGFloat
  var animatableData: CGFloat {
    get { center }
    set { center = newValue }
  }
  func path(in rect: CGRect) -> Path {
    let x = rect.width * center
    var path = Path()
    path.move(to: .zero)
    path.addLine(to: CGPoint(x: x - 50, y: 0))
    path.addCurve(to: CGPoint(x: x - 4, y: 24), control1: CGPoint(x: x - 25, y: 0), control2: CGPoint(x: x - 18, y: 24))
    path.addLine(to: CGPoint(x: x + 4, y: 24))
    path.addCurve(to: CGPoint(x: x + 50, y: 0), control1: CGPoint(x: x + 18, y: 24), control2: CGPoint(x: x + 25, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: 0))
    path.closeSubpath()
    return path
  }
}
