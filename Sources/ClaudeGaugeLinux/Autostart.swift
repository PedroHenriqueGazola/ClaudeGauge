import Foundation

enum Autostart {
  private static var desktopURL: URL {
    XDG.configHome.appendingPathComponent("autostart/claudegauge.desktop")
  }

  static var isEnabled: Bool {
    FileManager.default.fileExists(atPath: desktopURL.path)
  }

  static func setEnabled(_ enabled: Bool) {
    guard enabled else {
      try? FileManager.default.removeItem(at: desktopURL)
      return
    }

    let content = """
      [Desktop Entry]
      Type=Application
      Name=ClaudeGauge
      Comment=Uso do Claude na bandeja do sistema
      Exec=\(executablePath())
      Icon=claudegauge
      Terminal=false
      Categories=Utility;
      """
    try? FileManager.default.createDirectory(
      at: desktopURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? content.write(to: desktopURL, atomically: true, encoding: .utf8)
  }

  static func executablePath() -> String {
    (try? FileManager.default.destinationOfSymbolicLink(atPath: "/proc/self/exe"))
      ?? CommandLine.arguments[0]
  }
}
