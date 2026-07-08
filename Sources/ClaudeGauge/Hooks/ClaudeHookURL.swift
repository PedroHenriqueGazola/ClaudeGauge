import Foundation

struct ClaudeSession: Equatable {
  let project: String?
  let title: String?
  var detail: String? = nil
  var transcriptPath: String? = nil
}

enum ClaudeHookEvent: Equatable {
  case finished(ClaudeSession)
  case needsAttention(ClaudeSession)
}

enum ClaudeHookURL {
  static let scheme = "claudegauge"
  private static let host = "notify"

  static func parse(_ url: URL) -> ClaudeHookEvent? {
    guard url.scheme == scheme, url.host == host else { return nil }

    let query = queryValues(url)
    let session = ClaudeSession(
      project: nonEmpty(query["project"]),
      title: nonEmpty(query["title"]),
      detail: nonEmpty(query["detail"]),
      transcriptPath: nonEmpty(query["transcript"]))

    switch query["event"] {
    case "finished":
      return .finished(session)
    case "attention":
      return .needsAttention(session)
    default:
      return nil
    }
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  private static func queryValues(_ url: URL) -> [String: String] {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return items.reduce(into: [:]) { result, item in
      guard let value = item.value else { return }
      result[item.name] = value
    }
  }
}
