import Foundation

// Configura o hook `Notification` do Claude Code no ~/.claude/settings.json do
// usuário, apontando pro claude-notify.sh embutido no .app. É o que liga o aviso
// de "precisa de você" sem setup manual. Mescla com o settings existente: mexe
// só no hook do ClaudeGauge (identificado pelo script claude-notify.sh),
// preservando qualquer outra config e outros hooks.
enum ClaudeHookInstaller {
  private static let marker = "claude-notify.sh"

  static func setNotificationHook(enabled: Bool) {
    guard let scriptPath = Bundle.main.path(forResource: "claude-notify", ofType: "sh") else {
      return
    }

    var root = readSettings()
    var hooks = root["hooks"] as? [String: Any] ?? [:]
    var groups = (hooks["Notification"] as? [[String: Any]]) ?? []

    groups.removeAll(where: isOwnGroup)
    if enabled {
      groups.append([
        "hooks": [["type": "command", "command": "\"\(scriptPath)\" attention"]]
      ])
    }

    if groups.isEmpty {
      hooks.removeValue(forKey: "Notification")
    } else {
      hooks["Notification"] = groups
    }
    if hooks.isEmpty {
      root.removeValue(forKey: "hooks")
    } else {
      root["hooks"] = hooks
    }
    writeSettings(root)
  }

  private static func isOwnGroup(_ group: [String: Any]) -> Bool {
    let inner = group["hooks"] as? [[String: Any]] ?? []
    return inner.contains { ($0["command"] as? String)?.contains(marker) == true }
  }

  private static var settingsURL: URL {
    let environment = ProcessInfo.processInfo.environment
    let base =
      environment["CLAUDE_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    return base.appendingPathComponent("settings.json")
  }

  private static func readSettings() -> [String: Any] {
    guard let data = try? Data(contentsOf: settingsURL),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    return root
  }

  private static func writeSettings(_ root: [String: Any]) {
    guard let data = try? JSONSerialization.data(
      withJSONObject: root,
      options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    else { return }
    try? FileManager.default.createDirectory(
      at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: settingsURL)
  }
}
