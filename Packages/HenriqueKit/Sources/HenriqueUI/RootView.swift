import HenriqueCore
import SwiftUI

public struct RootView: View {
  @State private var accent: Accent = .verde
  private let store: AcademiaStore

  public init(store: AcademiaStore) {
    self.store = store
  }

  public var body: some View {
    Group {
      if store.isSignedIn {
        AcademiaTabs(accent: $accent)
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

  var body: some View {
    TabView {
      Tab("Hoje", systemImage: "flame.fill") {
        NavigationStack { TodayScreen() }
      }
      Tab("Semana", systemImage: "calendar") {
        NavigationStack { WeekScreen() }
      }
      Tab("Progresso", systemImage: "chart.xyaxis.line") {
        NavigationStack { ProgressScreen() }
      }
      Tab("Medidas", systemImage: "figure.arms.open") {
        NavigationStack { MeasurementsScreen(accent: $accent) }
      }
    }
    .tabBarMinimizeBehavior(.onScrollDown)
  }
}
