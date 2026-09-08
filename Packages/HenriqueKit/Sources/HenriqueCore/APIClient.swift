import Foundation

public enum APIError: Error, Equatable, Sendable {
  case unauthorized
  case http(status: Int, message: String)
  case transport(String)
  case decoding(String)

  public var message: String {
    switch self {
    case .unauthorized: "Sua sessão expirou. Entre de novo."
    case .http(_, let message): message
    case .transport: "Não consegui falar com o servidor."
    case .decoding: "O servidor respondeu num formato que eu não entendi."
    }
  }
}

/// As rotas ficam nomeadas em um só lugar. O servidor declara exatamente estes
/// caminhos, então uma divergência aparece aqui e não espalhada pelas telas.
public enum Route: String, Sendable {
  case dashboard = "/api/v1/dashboard/get"
  case recordSet = "/api/v1/workout/record-set"
  case saveWorkout = "/api/v1/plan/save-workout"
  case setStrengthGoal = "/api/v1/goal/set-strength"
  case addMeasurement = "/api/v1/measurement/add"
  case signIn = "/api/auth/sign-in/username"
  case signOut = "/api/auth/sign-out"
}

public actor APIClient {
  private let baseURL: URL
  private let session: URLSession
  private let tokenStore: any TokenStore
  private let encoder = JSONEncoder()
  private let decoder: JSONDecoder

  public init(
    baseURL: URL, tokenStore: any TokenStore, session: URLSession? = nil
  ) {
    self.baseURL = baseURL
    self.tokenStore = tokenStore
    self.session = session ?? Self.makeSession()
    self.decoder = .henrique()
  }

  /// O pote de cookies compartilhado guardaria a sessão por fora do chaveiro, e
  /// aí sair da conta não sairia de verdade: o cookie continuaria sendo enviado.
  /// Desligando o pote, o token guardado é a única fonte da sessão.
  private static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    return URLSession(configuration: configuration)
  }

  public var isSignedIn: Bool { tokenStore.read() != nil }

  public func signIn(username: String, password: String) async throws {
    struct Body: Encodable {
      let username: String
      let password: String
    }
    let (_, response) = try await send(.signIn, body: Body(username: username, password: password))
    guard let cookie = Self.sessionCookie(from: response, url: baseURL) else {
      throw APIError.http(status: response.statusCode, message: "O servidor não abriu a sessão.")
    }
    tokenStore.write(cookie)
  }

  public func signOut() async {
    _ = try? await send(.signOut, body: EmptyBody())
    tokenStore.write(nil)
  }

  public func dashboard(on date: CalendarDate) async throws -> Dashboard {
    try await call(.dashboard, body: DateInput(date: date))
  }

  public func recordSet(_ input: RecordSetInput) async throws -> Dashboard {
    try await call(.recordSet, body: input)
  }

  public func saveWorkout(_ input: SaveWorkoutInput) async throws -> Dashboard {
    try await call(.saveWorkout, body: input)
  }

  public func setStrengthGoal(_ input: SetStrengthGoalInput) async throws -> Dashboard {
    try await call(.setStrengthGoal, body: input)
  }

  public func addMeasurement(_ input: AddMeasurementInput) async throws -> Dashboard {
    try await call(.addMeasurement, body: input)
  }

  private struct EmptyBody: Encodable {}

  private func call<Body: Encodable, Value: Decodable>(_ route: Route, body: Body) async throws
    -> Value
  {
    let (data, _) = try await send(route, body: body)
    do {
      return try decoder.decode(Value.self, from: data)
    } catch {
      throw APIError.decoding(String(describing: error))
    }
  }

  private func send<Body: Encodable>(_ route: Route, body: Body) async throws -> (
    Data, HTTPURLResponse
  ) {
    var request = URLRequest(url: baseURL.appending(path: route.rawValue))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let token = tokenStore.read() {
      request.setValue(token, forHTTPHeaderField: "Cookie")
    }
    request.httpBody = try encoder.encode(body)

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw APIError.transport(error.localizedDescription)
    }
    guard let http = response as? HTTPURLResponse else {
      throw APIError.transport("resposta sem status")
    }
    if http.statusCode == 401 {
      tokenStore.write(nil)
      throw APIError.unauthorized
    }
    guard (200..<300).contains(http.statusCode) else {
      throw APIError.http(status: http.statusCode, message: Self.serverMessage(from: data))
    }
    return (data, http)
  }

  static func serverMessage(from data: Data) -> String {
    struct Failure: Decodable {
      let message: String?
      let error: String?
    }
    guard let failure = try? JSONDecoder().decode(Failure.self, from: data) else {
      return "O servidor recusou a chamada."
    }
    return failure.message ?? failure.error ?? "O servidor recusou a chamada."
  }

  static func sessionCookie(from response: HTTPURLResponse, url: URL) -> String? {
    let headers = response.allHeaderFields as? [String: String] ?? [:]
    let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
    let session = cookies.filter { $0.name.contains("session_token") }
    guard !session.isEmpty else { return nil }
    return session.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
  }
}
