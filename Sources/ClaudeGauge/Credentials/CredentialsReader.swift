import Foundation
import Security

struct ClaudeCredentials {
  let accessToken: String
  let expiresAt: Date?
  let subscriptionType: String?
}

enum CredentialsError: LocalizedError {
  case notFound

  var errorDescription: String? {
    switch self {
    case .notFound:
      return "Não encontrei o login do Claude Code. Rode `claude` no terminal e faça login."
    }
  }
}

struct CredentialsReader {
  private let keychainServicePrefix = "Claude Code-credentials"

  func read() throws -> ClaudeCredentials {
    if let token = environmentToken() {
      return ClaudeCredentials(accessToken: token, expiresAt: nil, subscriptionType: nil)
    }
    if let credentials = readFromFile() {
      return credentials
    }
    if let credentials = readFromKeychain() {
      return credentials
    }
    throw CredentialsError.notFound
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

  private func readFromKeychain() -> ClaudeCredentials? {
    keychainServiceNames().lazy
      .compactMap { readSecret(service: $0) }
      .compactMap { parse($0) }
      .max { ($0.expiresAt ?? .distantPast) < ($1.expiresAt ?? .distantPast) }
  }

  private func keychainServiceNames() -> [String] {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecMatchLimit as String: kSecMatchLimitAll,
      kSecReturnAttributes as String: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let items = result as? [[String: Any]]
    else { return [keychainServicePrefix] }

    let matching = items
      .compactMap { $0[kSecAttrService as String] as? String }
      .filter { $0.hasPrefix(keychainServicePrefix) }

    return matching.isEmpty ? [keychainServicePrefix] : matching
  }

  private func readSecret(service: String) -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return data
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
      subscriptionType: oauth["subscriptionType"] as? String
    )
  }

  private func expiryDate(from value: Any?) -> Date? {
    guard let raw = (value as? NSNumber)?.doubleValue else { return nil }
    let seconds = raw > 1_000_000_000_000 ? raw / 1000 : raw
    return Date(timeIntervalSince1970: seconds)
  }
}
