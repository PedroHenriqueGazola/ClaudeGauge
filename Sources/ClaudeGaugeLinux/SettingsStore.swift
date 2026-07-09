import Foundation

struct LinuxSettings: Codable {
  var refreshIntervalSeconds: Double
  var notifyAt75: Bool
  var notifyAt90: Bool
  var notifyAt95: Bool

  static let standard = LinuxSettings(
    refreshIntervalSeconds: 180, notifyAt75: true, notifyAt90: true, notifyAt95: true)
}

final class SettingsStore {
  private(set) var settings: LinuxSettings

  private static var fileURL: URL {
    XDG.configHome.appendingPathComponent("claudegauge/config.json")
  }

  init() {
    if let data = try? Data(contentsOf: Self.fileURL),
      let decoded = try? JSONDecoder().decode(LinuxSettings.self, from: data)
    {
      settings = decoded
    } else {
      settings = .standard
    }
  }

  var thresholds: [Int] {
    var result: [Int] = []
    if settings.notifyAt75 { result.append(75) }
    if settings.notifyAt90 { result.append(90) }
    if settings.notifyAt95 { result.append(95) }
    return result
  }

  func update(_ transform: (inout LinuxSettings) -> Void) {
    transform(&settings)
    save()
  }

  private func save() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(settings) else { return }
    try? FileManager.default.createDirectory(
      at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: Self.fileURL, options: .atomic)
  }
}
