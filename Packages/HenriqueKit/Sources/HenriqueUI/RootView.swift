import HenriqueCore
import SwiftUI

public enum AcademiaTab: String, Hashable, Sendable, CaseIterable {
  case hoje, semana, treino, progresso, apps

  /// "medidas" deixou de ser aba e virou uma seção de progresso. O nome antigo
  /// continua valendo na linha de comando para as capturas antigas abrirem.
  public init?(named name: String) {
    if name == "medidas" {
      self = .progresso
    } else {
      self.init(rawValue: name)
    }
  }
}

public enum AppSection: String, CaseIterable, Sendable {
  case academia, estudos

  var label: String {
    switch self {
    case .academia: "academia"
    case .estudos: "estudos"
    }
  }

  var detail: String {
    switch self {
    case .academia: "treino e progresso"
    case .estudos: "aprender e escrever"
    }
  }

  var symbol: String {
    switch self {
    case .academia: "dumbbell"
    case .estudos: "book"
    }
  }
}

public struct RootView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("henrique.accent") private var accent: Accent = .verde
  @AppStorage("henrique.app") private var section: AppSection = .academia
  @State private var tab: AcademiaTab
  @State private var estudosTab: EstudosTab
  @State private var appliedInitialSection = false
  private let store: AcademiaStore
  private let estudos: EstudosStore
  private let initialSection: AppSection?
  private let openSession: Bool
  private let openWrite: Bool

  public init(
    store: AcademiaStore, estudos: EstudosStore, initialSection: AppSection? = nil,
    initialTab: AcademiaTab = .treino, initialEstudosTab: EstudosTab = .hoje,
    openSession: Bool = false, openWrite: Bool = false
  ) {
    self.store = store
    self.estudos = estudos
    self.initialSection = initialSection
    self.openSession = openSession
    self.openWrite = openWrite
    tab = initialTab
    estudosTab = initialEstudosTab
  }

  /// O app que entra cresce um fio, o que sai encolhe o mesmo fio. Com movimento
  /// reduzido fica só a opacidade.
  private var appSwitch: AnyTransition {
    reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
  }

  public var body: some View {
    Group {
      if store.isSignedIn {
        switch section {
        case .academia:
          AcademiaTabs(accent: $accent, tab: $tab, onSwitchApp: { section = $0 })
            .transition(appSwitch)
        case .estudos:
          EstudosTabs(
            tab: $estudosTab, accent: $accent, onSwitchApp: { section = $0 },
            openSession: openSession, openWrite: openWrite)
            .transition(appSwitch)
        }
      } else {
        SignInScreen(phase: store.phase)
      }
    }
    .animation(.smooth(duration: 0.3), value: section)
    .environment(store)
    .environment(estudos)
    .environment(\.accent, accent)
    .environment(\.locale, Locale(identifier: "pt_BR"))
    .preferredColorScheme(.light)
    .tint(accent.base)
    .onAppear {
      // O valor padrão do AppStorage só vale quando a chave ainda não existe,
      // então a seção pedida no lançamento precisa ser gravada por cima.
      guard !appliedInitialSection else { return }
      appliedInitialSection = true
      if let initialSection { section = initialSection }
    }
    .task {
      estudos.onUnauthorized = { await store.signOut() }
      await store.start()
    }
    .onChange(of: store.isSignedIn) {
      if !store.isSignedIn { estudos.reset() }
    }
    .alert("Aviso", isPresented: .init(get: { store.banner != nil }, set: { if !$0 { store.banner = nil } })) {
      Button("Ok") { store.banner = nil }
    } message: { Text(store.banner ?? "") }
    .alert("Aviso", isPresented: .init(get: { estudos.banner != nil }, set: { if !$0 { estudos.banner = nil } })) {
      Button("Ok") { estudos.banner = nil }
    } message: { Text(estudos.banner ?? "") }
  }
}

struct AcademiaTabs: View {
  @Environment(AcademiaStore.self) private var store
  @State private var showingSetup = false
  @State private var showingApps = false
  @Binding var accent: Accent
  @Binding var tab: AcademiaTab
  let onSwitchApp: @MainActor (AppSection) -> Void

  var body: some View {
    TabView(selection: appSwitcherSelection($tab, isPresented: $showingApps, bubble: .apps)) {
      Tab("hoje", systemImage: "house", value: AcademiaTab.hoje) {
        shell { OverviewScreen { tab = .treino } }
      }
      Tab("plano", systemImage: "list.clipboard", value: AcademiaTab.semana) {
        shell {
          WeekScreen { weekday in
            let delta = (weekday - store.selectedDate.weekday() + 7) % 7
            Task { await store.select(date: store.selectedDate.adding(days: delta)) }
            tab = .treino
          }
        }
      }
      Tab("treino", systemImage: "dumbbell", value: AcademiaTab.treino) {
        shell { TodayScreen(onPlan: { tab = .semana }, onProgress: { tab = .progresso }) }
      }
      Tab("progresso", systemImage: "chart.xyaxis.line", value: AcademiaTab.progresso) {
        shell { ProgressScreen(onWorkout: { tab = .treino }) }
      }
      Tab("apps", systemImage: "square.grid.2x2", value: AcademiaTab.apps, role: appHubTabRole) {
        Color.clear
      }
    }
    .appSwitcher(current: .academia, isPresented: $showingApps, onSelect: onSwitchApp)
    .sheet(isPresented: $showingSetup) { SetupScreen() }
    .onChange(of: store.dashboard?.onboardingCompleted, initial: true) {
      if store.dashboard?.onboardingCompleted == false { showingSetup = true }
    }
    .onAppear { if tab == .apps { tab = .hoje; showingApps = true } }
  }

  private func shell<Content: View>(
    _ label: String = "seu treino", @ViewBuilder content: () -> Content
  ) -> some View {
    NavigationStack {
      content()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationLeading) {
            VStack(alignment: .leading, spacing: 2) {
              Text("academia").font(.caption2).foregroundStyle(accent.base)
              Text(label).font(.headline.weight(.medium))
            }.fixedSize(horizontal: true, vertical: false)
          }.sharedBackgroundVisibility(.hidden)
          ToolbarItem(placement: .primaryAction) {
            Menu {
              Button("Primeiros passos", systemImage: "slider.horizontal.3") { showingSetup = true }
              Picker("cor do app", selection: $accent) {
                ForEach(Accent.allCases) { color in Text(color.label).tag(color) }
              }
              Button("Editar plano", systemImage: "list.clipboard") { tab = .semana }
            } label: { Label("configurar", systemImage: "gearshape") }
          }
          ToolbarItem(placement: .primaryAction) {
            Menu {
              Button("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                Task { await store.signOut() }
              }
            } label: { Image(systemName: "person.crop.circle") }
            .accessibilityLabel("sua conta")
          }
        }
    }
  }
}

/// A bolha redonda separada da barra é o papel `prominent`, novo no iOS 27. No
/// iOS 26 o papel de busca é o que desenha a mesma bolha.
var appHubTabRole: TabRole {
  if #available(iOS 27, macOS 27, *) { .prominent } else { .search }
}

/// A bolha não leva a lugar nenhum, ela abre a lista. Escolher a aba dela vira
/// abrir a folha e a seleção fica onde estava.
@MainActor func appSwitcherSelection<Tab: Hashable & Sendable>(
  _ tab: Binding<Tab>, isPresented: Binding<Bool>, bubble: Tab
) -> Binding<Tab> {
  Binding(
    get: { tab.wrappedValue },
    set: { picked in
      if picked == bubble {
        isPresented.wrappedValue = true
      } else {
        tab.wrappedValue = picked
      }
    })
}

extension View {
  /// A lista de apps que a bolha abre. Mora nos dois apps e veste a pele de
  /// quem a abriu, então `current` escolhe o estilo e marca o app atual.
  func appSwitcher(
    current: AppSection, isPresented: Binding<Bool>,
    onSelect: @escaping @MainActor (AppSection) -> Void
  ) -> some View {
    modifier(AppSwitcher(current: current, isPresented: isPresented, onSelect: onSelect))
  }
}

private struct AppSwitcher: ViewModifier {
  let current: AppSection
  @Binding var isPresented: Bool
  let onSelect: @MainActor (AppSection) -> Void
  @State private var picked: AppSection?

  func body(content: Content) -> some View {
    content
      // A troca espera a folha sair. Feita junto, a transição do app engole a
      // animação de fechar.
      .sheet(isPresented: $isPresented, onDismiss: sendPick) {
        AppSwitcherList(current: current) { app in
          picked = app == current ? nil : app
          isPresented = false
        }
      }
  }

  private func sendPick() {
    guard let app = picked else { return }
    picked = nil
    onSelect(app)
  }
}

private struct AppSwitcherList: View {
  let current: AppSection
  let onSelect: @MainActor (AppSection) -> Void

  private var height: CGFloat { CGFloat(AppSection.allCases.count) * 84 + 16 }

  var body: some View {
    VStack(spacing: 12) {
      ForEach(AppSection.allCases, id: \.self) { app in
        AppHubCard(app: app, style: current, isCurrent: app == current) { onSelect(app) }
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(backdrop.ignoresSafeArea())
    .presentationDetents([.height(height)])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(28)
    .tint(current == .estudos ? .studyBlue : nil)
  }

  private var backdrop: Color {
    current == .estudos ? .studyPaper : .canvas
  }
}

private struct AppHubCard: View {
  @Environment(\.accent) private var accent
  let app: AppSection
  let style: AppSection
  let isCurrent: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      switch style {
      case .academia: row.padding(16).paperCard(radius: 24)
      case .estudos: StudyCard { row }
      }
    }
    .buttonStyle(StudyPressStyle())
    .accessibilityAddTraits(isCurrent ? .isSelected : [])
  }

  private var tint: Color { style == .estudos ? .studyBlue : accent.base }

  private var row: some View {
    HStack(spacing: 14) {
      Image(systemName: app.symbol)
        .font(.title2)
        .foregroundStyle(tint)
        .frame(width: 32)
      VStack(alignment: .leading, spacing: 2) {
        Text(app.label).font(.headline.weight(.medium)).foregroundStyle(Color.primary)
        Text(app.detail)
          .font(.subheadline)
          .foregroundStyle(style == .estudos ? Color.studyGraphite : Color.mutedInk)
      }
      Spacer(minLength: 0)
      if isCurrent {
        Image(systemName: "checkmark")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(tint)
          .accessibilityLabel("app atual")
      }
    }
  }
}

struct OverviewScreen: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.accent) private var accent
  let onWorkout: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        PageHeading(eyebrow: "seu ritmo agora", title: "consistência que dá para enxergar",
          subtitle: "O objetivo é chegar ao próximo treino sabendo o que fazer e por quê.")
        if let data = store.dashboard {
          VStack(alignment: .leading, spacing: 10) {
            Text("\(data.consistencyPercent)%").font(.system(size: 48, weight: .medium)).monospacedDigit()
            Text("de constância em quatro semanas").font(.subheadline)
          }
          .foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
          .padding(22).background(accent.deep, in: .rect(cornerRadius: 28))
          .staggeredEntrance(index: 0, isReady: true)
          HStack(spacing: 12) {
            StatTile(value: "\(data.currentStreak)", caption: "treinos na sequência atual")
            StatTile(value: "\(data.weeklyCompleted)/\(data.weeklyPlanned)", caption: "treinos concluídos nesta semana")
          }
          .fixedSize(horizontal: false, vertical: true)
          .staggeredEntrance(index: 1, isReady: true)
          HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
              Text("próxima ação").font(.caption).foregroundStyle(accent.base)
              Text(data.workout?.name.lowercased() ?? "recuperar e preparar").font(.title2.weight(.medium))
              Text(data.workout?.focus ?? "A semana continua no próximo treino programado.")
                .font(.subheadline).foregroundStyle(Color.mutedInk)
            }
            Spacer(minLength: 0)
            Button("Abrir treino", systemImage: "arrow.right", action: onWorkout)
              .labelStyle(.iconOnly).buttonStyle(.glass).controlSize(.large)
          }.padding(22).paperCard(radius: 32)
            .staggeredEntrance(index: 2, isReady: true)
        }
      }.padding(16).padding(.bottom, 24)
    }
    .refreshable { await store.load() }
    .overlay { TodayPlaceholder(phase: store.phase, isEmpty: store.dashboard == nil) }
  }
}

struct StatTile: View {
  let value: String
  let caption: String
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(value).font(.system(size: 38, weight: .medium)).monospacedDigit()
        .contentTransition(.numericText())
        .animation(.smooth(duration: 0.3), value: value)
      Text(caption).font(.caption).foregroundStyle(Color.mutedInk)
    }
    .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
    .padding(18)
    // Mesma regra do StudyMetric: a fileira fica reta mesmo quando uma legenda
    // quebra linha e a outra não.
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .paperCard()
    .accessibilityElement(children: .combine)
  }
}

extension ToolbarItemPlacement {
  static var navigationLeading: ToolbarItemPlacement {
    #if os(iOS)
    .topBarLeading
    #else
    .navigation
    #endif
  }
}
