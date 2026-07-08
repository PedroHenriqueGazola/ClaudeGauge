import CNotify
import ClaudeGaugeCore
import Foundation

final class NotificationService {
  private let evaluator = ThresholdEvaluator()

  func evaluate(snapshot: UsageSnapshot, thresholds: [Int]) {
    for crossing in evaluator.crossings(for: snapshot, thresholds: thresholds) {
      send(
        title: "Claude · \(crossing.label) em \(Int(crossing.percent))%",
        body: "Você passou de \(crossing.threshold)% do limite.")
    }
  }

  func send(title: String, body: String) {
    guard let notification = notify_notification_new(title, body, "claudegauge") else { return }
    notify_notification_show(notification, nil)
    g_object_unref(UnsafeMutableRawPointer(notification))
  }
}
