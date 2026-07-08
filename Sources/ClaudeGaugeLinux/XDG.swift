import Foundation

enum XDG {
  static var configHome: URL {
    directory(environment: "XDG_CONFIG_HOME", fallback: ".config")
  }

  static var dataHome: URL {
    directory(environment: "XDG_DATA_HOME", fallback: ".local/share")
  }

  private static func directory(environment: String, fallback: String) -> URL {
    if let path = ProcessInfo.processInfo.environment[environment], !path.isEmpty {
      return URL(fileURLWithPath: path)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(fallback)
  }
}
