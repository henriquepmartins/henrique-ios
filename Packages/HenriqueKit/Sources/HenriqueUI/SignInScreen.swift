import HenriqueCore
import SwiftUI

struct SignInScreen: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.accent) private var accent
  @State private var username = ""
  @State private var password = ""
  @FocusState private var focus: Field?

  let phase: AcademiaStore.Phase

  private enum Field: Hashable { case username, password }

  private var canSubmit: Bool {
    !username.isEmpty && password.count >= 6 && phase != .loading
  }

  var body: some View {
    ZStack {
      SignInBackdrop(accent: accent)

      VStack(spacing: 24) {
        VStack(spacing: 6) {
          Text("Academia").font(.largeTitle.weight(.semibold))
          Text("Entre para ver o treino de hoje.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        GlassEffectContainer(spacing: 10) {
          VStack(spacing: 10) {
            GlassField(placeholder: "usuário") {
              TextField("usuário", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .username)
                .submitLabel(.next)
                .onSubmit { focus = .password }
            }
            GlassField(placeholder: "senha") {
              SecureField("senha", text: $password)
                .textContentType(.password)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }
            }
          }
        }

        if case .failed(let message) = phase {
          Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .transition(.opacity)
        }

        Button(action: submit) {
          Text(phase == .loading ? "Entrando…" : "Entrar")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(!canSubmit)
      }
      .padding(.horizontal, 28)
      .frame(maxWidth: 420)
    }
    .animation(.smooth(duration: 0.25), value: phase)
  }

  private func submit() {
    guard canSubmit else { return }
    focus = nil
    Task { await store.signIn(username: username, password: password) }
  }
}

/// O vidro precisa de alguma coisa embaixo para refratar. Sobre uma cor chapada
/// ele vira um retângulo cinza, então o fundo traz duas manchas de cor.
struct SignInBackdrop: View {
  let accent: Accent

  var body: some View {
    ZStack {
      accent.pale.opacity(0.55)
      Circle()
        .fill(accent.base.opacity(0.35))
        .frame(width: 320, height: 320)
        .blur(radius: 90)
        .offset(x: -110, y: -230)
      Circle()
        .fill(accent.signal.opacity(0.45))
        .frame(width: 280, height: 280)
        .blur(radius: 90)
        .offset(x: 130, y: 260)
    }
    .ignoresSafeArea()
  }
}

struct GlassField<Content: View>: View {
  let placeholder: String
  @ViewBuilder let content: Content

  var body: some View {
    content
      .textFieldStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .glassEffect(.regular.interactive(), in: .capsule)
      .accessibilityLabel(placeholder)
  }
}
