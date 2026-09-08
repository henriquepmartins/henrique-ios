import HenriqueCore
import SwiftUI

public enum AcademiaTab: String, Hashable, Sendable, CaseIterable {
  case hoje, semana, progresso, medidas
}

public struct RootView: View {
  @State private var accent: Accent = .verde
  @State private var tab: AcademiaTab
  private let store: AcademiaStore

  public init(store: AcademiaStore, initialTab: AcademiaTab = .hoje) {
    self.store = store
    tab = initialTab
  }

  public var body: some View {
    Group {
      if store.isSignedIn {
        AcademiaTabs(accent: $accent, tab: $tab)
      } else {
        SignInScreen(phase: store.phase)
      }
    }
    .environment(store)
    .environment(\.accent, accent)
    .tint(accent.base)
    .task { await store.start() }
    .alert(
      "Aviso", isPresented: .init(get: { store.banner != nil }, set: { if !$0 { store.banner = nil } })
    ) {
      Button("Ok") { store.banner = nil }
    } message: {
      Text(store.banner ?? "")
    }
  }
}

struct AcademiaTabs: View {
  @Binding var accent: Accent
  @Binding var tab: AcademiaTab

  var body: some View {
    TabView(selection: $tab) {
      Tab("Hoje", systemImage: "flame.fill", value: AcademiaTab.hoje) {
        NavigationStack { TodayScreen() }
      }
      Tab("Semana", systemImage: "calendar", value: AcademiaTab.semana) {
        NavigationStack { WeekScreen() }
      }
      Tab("Progresso", systemImage: "chart.xyaxis.line", value: AcademiaTab.progresso) {
        NavigationStack { ProgressScreen() }
      }
      Tab("Medidas", systemImage: "figure.arms.open", value: AcademiaTab.medidas) {
        NavigationStack { MeasurementsScreen(accent: $accent) }
      }
    }
    #if os(iOS)
      .tabBarMinimizeBehavior(.onScrollDown)
    #endif
  }
}
