import ClaudeGaugeCore
import Foundation

struct FileTokenStore: TokenStoring {
  private var fileURL: URL {
    XDG.dataHome.appendingPathComponent("claudegauge/tokens.json")
  }

  func load() -> OAuthTokens? {
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    return OAuthTokens(jsonData: data)
  }

  func save(_ tokens: OAuthTokens) {
    guard let data = tokens.jsonData() else { return }
    let directory = fileURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    try? data.write(to: fileURL, options: .atomic)
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
  }

  func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }
}
