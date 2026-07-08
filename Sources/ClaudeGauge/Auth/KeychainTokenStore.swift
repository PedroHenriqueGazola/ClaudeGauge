import ClaudeGaugeCore
import Foundation
import Security

struct KeychainTokenStore: TokenStoring {
  private static let service = "com.pedrogazola.claudegauge.oauth"
  private static let account = "oauth-tokens"

  func load() -> OAuthTokens? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return OAuthTokens(jsonData: data)
  }

  func save(_ tokens: OAuthTokens) {
    guard let data = tokens.jsonData() else { return }
    let identity: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
    ]
    SecItemDelete(identity as CFDictionary)

    var attributes = identity
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(attributes as CFDictionary, nil)
  }

  func clear() {
    let identity: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
    ]
    SecItemDelete(identity as CFDictionary)
  }
}
