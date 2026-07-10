import ClaudeGaugeCore
import Foundation

struct FileTokenStore: TokenStoring {
  private var fileURL: URL {
    AppPaths.appData.appendingPathComponent("tokens.json")
  }

  func load() -> OAuthTokens? {
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    return OAuthTokens(jsonData: data)
  }

  func save(_ tokens: OAuthTokens) {
    guard let data = tokens.jsonData() else { return }
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: fileURL, options: .atomic)
  }

  func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }
}
