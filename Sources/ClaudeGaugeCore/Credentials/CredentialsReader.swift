import Foundation

public struct ClaudeCredentials {
  public let accessToken: String
  public let expiresAt: Date?
  public let subscriptionType: String?
}

// Lê as credenciais do Claude Code só de fontes silenciosas: a env var e o
// arquivo ~/.claude/.credentials.json. NÃO lê o item do Keychain do Claude
// Code de propósito — acesso cross-app dispara o diálogo de senha do macOS a
// cada renovação de token do CLI (o Claude Code reescreve o item e reseta a
// permissão). Pra quem não tem o arquivo, o caminho é o login OAuth do app.
public struct CredentialsReader {
  public init() {}

  public func read() -> ClaudeCredentials? {
    if let token = environmentToken() {
      return ClaudeCredentials(accessToken: token, expiresAt: nil, subscriptionType: nil)
    }
    return readFromFile()
  }

  private func environmentToken() -> String? {
    guard let token = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"],
      !token.isEmpty
    else { return nil }
    return token
  }

  private var claudeDirectory: URL {
    let environment = ProcessInfo.processInfo.environment
    if let directory = environment["CLAUDE_CONFIG_DIR"], !directory.isEmpty {
      return URL(fileURLWithPath: directory)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
  }

  private func readFromFile() -> ClaudeCredentials? {
    let candidates = [
      claudeDirectory.appendingPathComponent(".credentials.json"),
      claudeDirectory.appendingPathComponent("credentials.json"),
    ]
    return candidates.lazy
      .compactMap { try? Data(contentsOf: $0) }
      .compactMap { parse($0) }
      .first
  }

  private func parse(_ data: Data) -> ClaudeCredentials? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let oauth = root["claudeAiOauth"] as? [String: Any],
      let token = oauth["accessToken"] as? String,
      !token.isEmpty
    else { return nil }

    return ClaudeCredentials(
      accessToken: token,
      expiresAt: expiryDate(from: oauth["expiresAt"]),
      subscriptionType: oauth["subscriptionType"] as? String)
  }

  private func expiryDate(from value: Any?) -> Date? {
    guard let raw = (value as? NSNumber)?.doubleValue else { return nil }
    let seconds = raw > 1_000_000_000_000 ? raw / 1000 : raw
    return Date(timeIntervalSince1970: seconds)
  }
}
