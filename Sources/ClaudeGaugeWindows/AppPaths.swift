import Foundation

enum AppPaths {
  static var appData: URL {
    if let path = ProcessInfo.processInfo.environment["APPDATA"], !path.isEmpty {
      return URL(fileURLWithPath: path).appendingPathComponent("ClaudeGauge")
    }
    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("AppData/Roaming/ClaudeGauge")
  }
}
