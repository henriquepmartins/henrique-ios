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
    !username.isEmpty && !password.isEmpty && phase != .loading
  }

  var body: some View {
    ZStack {
      Color.canvas.ignoresSafeArea()

      VStack(spacing: 24) {
        VStack(spacing: 6) {
          Text("h&").font(.system(size: 64, weight: .medium)).tracking(-4).foregroundStyle(accent.deep)
          Text("entre para continuar")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        GlassEffectContainer(spacing: 10) {
          VStack(spacing: 10) {
            GlassField(placeholder: "usuário") {
              TextField("usuário", text: $username)
                .textContentType(.username)
                #if os(iOS)
                  .textInputAutocapitalization(.never)
                #endif
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
          Text(phase == .loading ? "entrando" : "entrar")
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

  }

  private func submit() {
    guard canSubmit else { return }
    focus = nil
    Task { await store.signIn(username: username, password: password) }
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
      .background(.white, in: .rect(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.ink.opacity(0.12)))
      .accessibilityLabel(placeholder)
  }
}
