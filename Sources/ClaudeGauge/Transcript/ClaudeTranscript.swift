import Foundation

enum ClaudeTranscript {
  // Resume a ferramenta que o Claude quer usar (última tool_use da última
  // resposta do assistant) pra a notificação de "precisa de você" mostrar o
  // que ele quer — ex: "Bash: npm run deploy". Lê só a cauda do arquivo.
  static func pendingToolSummary(transcriptPath: String) -> String? {
    guard let handle = FileHandle(forReadingAtPath: transcriptPath) else { return nil }
    defer { try? handle.close() }

    let window: UInt64 = 65536
    let size = (try? handle.seekToEnd()) ?? 0
    try? handle.seek(toOffset: size > window ? size - window : 0)
    guard let data = try? handle.readToEnd() else { return nil }

    for line in data.split(separator: 0x0A).reversed() {
      guard let row = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
        row["type"] as? String == "assistant",
        let content = (row["message"] as? [String: Any])?["content"] as? [[String: Any]],
        let summary = summary(from: content)
      else { continue }
      return summary
    }
    return nil
  }

  private static func summary(from content: [[String: Any]]) -> String? {
    let toolUses = content.filter { $0["type"] as? String == "tool_use" }
    guard let tool = toolUses.last, let name = tool["name"] as? String else { return nil }
    return describe(tool: name, input: tool["input"] as? [String: Any] ?? [:])
  }

  private static func describe(tool: String, input: [String: Any]) -> String {
    let detail =
      input["command"] as? String
      ?? (input["file_path"] as? String).map { ($0 as NSString).lastPathComponent }
      ?? input["pattern"] as? String
      ?? input["url"] as? String
    guard let detail, !detail.isEmpty else { return tool }
    return "\(tool): \(truncated(detail))"
  }

  private static func truncated(_ text: String, limit: Int = 80) -> String {
    let flat = text.replacingOccurrences(of: "\n", with: " ")
    return flat.count <= limit ? flat : String(flat.prefix(limit - 1)) + "…"
  }
}
