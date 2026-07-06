import Foundation
import Security

struct OAuthTokens: Codable, Equatable {
  let accessToken: String
  let refreshToken: String?
  let expiresAt: Date?
  let subscriptionType: String?
  let scopes: [String]?

  var isExpired: Bool {
    guard let expiresAt else { return false }
    return Date() >= expiresAt.addingTimeInterval(-300)
  }
}

enum TokenStore {
  private static let service = "com.pedrogazola.claudegauge.oauth"
  private static let account = "oauth-tokens"

  static func load() -> OAuthTokens? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return try? decoder().decode(OAuthTokens.self, from: data)
  }

  static func save(_ tokens: OAuthTokens) {
    guard let data = try? encoder().encode(tokens) else { return }
    let identity: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(identity as CFDictionary)

    var attributes = identity
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(attributes as CFDictionary, nil)
  }

  static func clear() {
    let identity: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(identity as CFDictionary)
  }

  private static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    return encoder
  }

  private static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }
}
