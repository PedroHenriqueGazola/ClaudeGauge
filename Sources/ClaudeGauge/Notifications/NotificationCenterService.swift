import Foundation
import UserNotifications

final class NotificationCenterService {
  private var firedKeys: Set<String> = []
  private var lastPercentByWindow: [String: Double] = [:]

  private var isBundled: Bool {
    Bundle.main.bundleIdentifier != nil
  }

  private var thresholds: [Int] {
    let defaults = UserDefaults.standard
    var result: [Int] = []
    if defaults.object(forKey: "notifyAt75") as? Bool ?? true { result.append(75) }
    if defaults.object(forKey: "notifyAt90") as? Bool ?? true { result.append(90) }
    if defaults.object(forKey: "notifyAt95") as? Bool ?? true { result.append(95) }
    return result.sorted()
  }

  func requestAuthorizationIfNeeded() {
    guard isBundled else { return }
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  func evaluate(snapshot: UsageSnapshot) {
    guard isBundled else { return }

    let windows: [(String, Double)] = [
      ("Sessão de 5h", snapshot.fiveHour?.percent),
      ("Semanal", snapshot.sevenDay?.percent),
      ("Opus semanal", snapshot.opusWeekly?.percent),
      ("Sonnet semanal", snapshot.sonnetWeekly?.percent),
    ].compactMap { label, percent in percent.map { (label, $0) } }

    windows.forEach { evaluateWindow(label: $0.0, percent: $0.1) }
  }

  private func evaluateWindow(label: String, percent: Double) {
    resetFiredKeysIfCycleRestarted(label: label, percent: percent)

    for threshold in thresholds where percent >= Double(threshold) {
      let key = "\(label)_\(threshold)"
      guard !firedKeys.contains(key) else { continue }
      firedKeys.insert(key)
      notify(
        title: "Claude · \(label) em \(Int(percent))%",
        body: "Você passou de \(threshold)% do limite.")
    }

    lastPercentByWindow[label] = percent
  }

  private func resetFiredKeysIfCycleRestarted(label: String, percent: Double) {
    guard let previous = lastPercentByWindow[label], percent < previous - 5 else { return }
    firedKeys = firedKeys.filter { !$0.hasPrefix("\(label)_") }
  }

  private func notify(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}
