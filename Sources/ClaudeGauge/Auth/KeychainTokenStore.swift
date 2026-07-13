import ClaudeGaugeCore
import Foundation
import Security

struct KeychainTokenStore: TokenStoring {
  private static let service = "com.pedrogazola.claudegauge.oauth"
  private static let accountsKey = "accounts"
  private static let legacyKey = "oauth-tokens"

  func load() -> StoredAccounts {
    if let data = read(Self.accountsKey), let accounts = StoredAccounts(jsonData: data) {
      return accounts
    }
    // Migra o formato antigo (um único OAuthTokens) pro novo, uma vez.
    if let legacy = read(Self.legacyKey),
      let migrated = StoredAccounts.migrating(fromLegacy: legacy, newId: UUID().uuidString)
    {
      save(migrated)
      delete(Self.legacyKey)
      return migrated
    }
    return StoredAccounts()
  }

  func save(_ accounts: StoredAccounts) {
    guard let data = accounts.jsonData() else { return }
    // Atualiza in-place quando o item já existe — recriar (delete+add) resetaria
    // a ACL do Keychain e faria o macOS repedir a senha a cada gravação.
    let update = [kSecValueData as String: data]
    let status = SecItemUpdate(identity(Self.accountsKey) as CFDictionary, update as CFDictionary)
    if status == errSecItemNotFound {
      var attributes = identity(Self.accountsKey)
      attributes[kSecValueData as String] = data
      attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
      SecItemAdd(attributes as CFDictionary, nil)
    }
    delete(Self.legacyKey)
  }

  private func read(_ account: String) -> Data? {
    var query = identity(account)
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnData as String] = true
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return data
  }

  private func delete(_ account: String) {
    SecItemDelete(identity(account) as CFDictionary)
  }

  private func identity(_ account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: account,
    ]
  }
}
