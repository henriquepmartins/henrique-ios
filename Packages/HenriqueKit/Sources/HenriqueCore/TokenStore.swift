import Foundation

public protocol TokenStore: Sendable {
  func read() -> String?
  func write(_ token: String?)
}

/// Guarda o cookie de sessão do better-auth no chaveiro. O item fica preso ao
/// dispositivo depois do primeiro desbloqueio, então uma renovação em segundo
/// plano continua conseguindo ler o token.
public struct KeychainTokenStore: TokenStore {
  private let service: String
  private let account: String

  public init(service: String = "app.henrique.session", account: String = "default") {
    self.service = service
    self.account = account
  }

  private var query: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }

  public func read() -> String? {
    var lookup = query
    lookup[kSecReturnData as String] = true
    lookup[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  public func write(_ token: String?) {
    SecItemDelete(query as CFDictionary)
    guard let token, let data = token.data(using: .utf8) else { return }
    var insert = query
    insert[kSecValueData as String] = data
    insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(insert as CFDictionary, nil)
  }
}

public final class MemoryTokenStore: TokenStore, @unchecked Sendable {
  private let lock = NSLock()
  private var token: String?

  public init(token: String? = nil) { self.token = token }

  public func read() -> String? {
    lock.withLock { token }
  }

  public func write(_ token: String?) {
    lock.withLock { self.token = token }
  }
}
