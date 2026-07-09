import Foundation

// Onde o Claude Code grava os transcripts (~/.claude/projects, ou
// $CLAUDE_CONFIG_DIR/projects). Fica no core pra macOS e Linux compartilharem
// o mesmo caminho na agregação de gastos.
public enum ClaudeConfig {
  public static var projectsDirectory: URL {
    let environment = ProcessInfo.processInfo.environment
    let base =
      environment["CLAUDE_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    return base.appendingPathComponent("projects")
  }
}
