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
      // A bolha é o botão do painel, então ela mostra o x enquanto o painel
      // está aberto, do mesmo jeito que um menu marca que está aberto.
      Tab(
        "apps", systemImage: showingApps ? "xmark" : "square.grid.2x2",
        value: AcademiaTab.apps, role: appHubTabRole
      ) {
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

/// A bolha não leva a lugar nenhum, ela abre o painel de apps. Escolher a aba
/// dela vira abrir o painel e a seleção fica onde estava.
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
  /// O painel de apps que a bolha abre. Mora nos dois apps e veste a pele de
  /// quem o abriu, então `current` escolhe o estilo e marca o app atual.
  func appSwitcher(
    current: AppSection, isPresented: Binding<Bool>,
    onSelect: @escaping @MainActor (AppSection) -> Void
  ) -> some View {
    modifier(AppSwitcher(current: current, isPresented: isPresented, onSelect: onSelect))
  }
}

private struct AppSwitcher: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let current: AppSection
  @Binding var isPresented: Bool
  let onSelect: @MainActor (AppSection) -> Void

  func body(content: Content) -> some View {
    content
      // Véu e painel entram como camadas separadas para o véu só aparecer e o
      // painel crescer do canto da bolha.
      .overlay {
        if isPresented {
          Color.ink.opacity(0.12)
            .ignoresSafeArea()
            .contentShape(.rect)
            .onTapGesture { isPresented = false }
            .transition(.opacity)
        }
      }
      .overlay(alignment: .bottomTrailing) {
        if isPresented {
          AppSwitcherPanel(current: current) { app in
            isPresented = false
            if app != current { onSelect(app) }
          }
          .padding(.trailing, 14)
          .padding(.bottom, 72)
          .transition(.scale(scale: 0.88, anchor: .bottomTrailing).combined(with: .opacity))
        }
      }
      .animation(reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0.2), value: isPresented)
  }
}

private struct AppSwitcherPanel: View {
  let current: AppSection
  let onSelect: @MainActor (AppSection) -> Void

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { index, app in
        if index > 0 { Divider().padding(.leading, 52) }
        AppSwitcherRow(app: app, style: current, isCurrent: app == current) { onSelect(app) }
      }
    }
    .frame(width: 228)
    .glassEffect(in: .rect(cornerRadius: 24))
    .shadow(color: Color.ink.opacity(0.18), radius: 22, y: 10)
    .tint(current == .estudos ? .studyBlue : nil)
  }
}

private struct AppSwitcherRow: View {
  @Environment(\.accent) private var accent
  let app: AppSection
  let style: AppSection
  let isCurrent: Bool
  let action: @MainActor () -> Void

  private var tint: Color { style == .estudos ? .studyBlue : accent.base }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: app.symbol).font(.system(size: 17)).frame(width: 24)
        Text(app.label).font(.body.weight(.medium))
        Spacer(minLength: 0)
        if isCurrent {
          Image(systemName: "checkmark")
            .font(.footnote.weight(.semibold))
            .accessibilityLabel("app atual")
        }
      }
      .foregroundStyle(isCurrent ? tint : Color.ink)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .contentShape(.rect)
    }
    .buttonStyle(StudyPressStyle())
    .accessibilityAddTraits(isCurrent ? .isSelected : [])
  }
}

struct OverviewScreen: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.accent) private var accent
  @State private var showingStreak = false
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
          StreakCard(snapshot: StreakSnapshot(dashboard: data)) { showingStreak = true }
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
    .sheet(isPresented: $showingStreak) {
      if let data = store.dashboard {
        StreakScreen(snapshot: StreakSnapshot(dashboard: data))
      }
    }
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
