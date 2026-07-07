import Foundation
import UserNotifications

final class NotificationCenterService: NSObject, UNUserNotificationCenterDelegate {
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
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      guard ProcessInfo.processInfo.environment["CLAUDEGAUGE_DEBUG"] != nil else { return }
      FileHandle.standardError.write(
        Data("[ClaudeGauge notif] authorization granted=\(granted) error=\(String(describing: error))\n".utf8))
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func notify(_ event: ClaudeHookEvent) {
    guard isBundled else { return }
    let (title, session, fallbackBody) = presentation(for: event)
    notify(title: title, body: session.title ?? fallbackBody, subtitle: session.project)
  }

  private func presentation(for event: ClaudeHookEvent)
    -> (title: String, session: ClaudeSession, fallbackBody: String)
  {
    switch event {
    case .finished(let session):
      return ("Claude terminou", session, "Resposta pronta")
    case .needsAttention(let session):
      return ("Claude precisa de você", session, "Esperando sua resposta")
    }
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

  private func notify(title: String, body: String, subtitle: String? = nil) {
    let content = UNMutableNotificationContent()
    content.title = title
    if let subtitle, !subtitle.isEmpty { content.subtitle = subtitle }
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      guard ProcessInfo.processInfo.environment["CLAUDEGAUGE_DEBUG"] != nil else { return }
      let status = error.map { "erro: \($0.localizedDescription)" } ?? "agendada"
      FileHandle.standardError.write(
        Data(("[ClaudeGauge notif] \(title) / \(body) — \(status)\n").utf8))
    }
  }
}
