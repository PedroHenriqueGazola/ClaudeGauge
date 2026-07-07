import Foundation

enum ClaudeHookEvent: Equatable {
  case finished(project: String?)
  case needsAttention(project: String?)
}

enum ClaudeHookURL {
  static let scheme = "claudegauge"
  private static let host = "notify"

  static func parse(_ url: URL) -> ClaudeHookEvent? {
    guard url.scheme == scheme, url.host == host else { return nil }

    let query = queryValues(url)
    let project = query["project"].flatMap { $0.isEmpty ? nil : $0 }

    switch query["event"] {
    case "finished":
      return .finished(project: project)
    case "attention":
      return .needsAttention(project: project)
    default:
      return nil
    }
  }

  private static func queryValues(_ url: URL) -> [String: String] {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return items.reduce(into: [:]) { result, item in
      guard let value = item.value else { return }
      result[item.name] = value
    }
  }
}
