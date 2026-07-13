import ClaudeGaugeCore
import Foundation

struct FileTokenStore: TokenStoring {
  private var fileURL: URL {
    XDG.dataHome.appendingPathComponent("claudegauge/tokens.json")
  }

  func load() -> StoredAccounts {
    guard let data = try? Data(contentsOf: fileURL) else { return StoredAccounts() }
    if let accounts = StoredAccounts(jsonData: data) { return accounts }
    // Migra o formato antigo (um único OAuthTokens no mesmo arquivo).
    if let migrated = StoredAccounts.migrating(fromLegacy: data, newId: UUID().uuidString) {
      save(migrated)
      return migrated
    }
    return StoredAccounts()
  }

  func save(_ accounts: StoredAccounts) {
    guard let data = accounts.jsonData() else { return }
    let directory = fileURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    try? data.write(to: fileURL, options: .atomic)
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
  }
}
