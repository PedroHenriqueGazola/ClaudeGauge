import Foundation

public struct ThresholdCrossing: Equatable {
  public let label: String
  public let percent: Double
  public let threshold: Int
}

public final class ThresholdEvaluator {
  private var firedKeys: Set<String> = []
  private var lastPercentByWindow: [String: Double] = [:]

  public init() {}

  public func crossings(for snapshot: UsageSnapshot, thresholds: [Int]) -> [ThresholdCrossing] {
    let windows: [(String, Double)] = [
      ("Sessão de 5h", snapshot.fiveHour?.percent),
      ("Semanal", snapshot.sevenDay?.percent),
      ("Opus semanal", snapshot.opusWeekly?.percent),
      ("Sonnet semanal", snapshot.sonnetWeekly?.percent),
    ].compactMap { label, percent in percent.map { (label, $0) } }

    return windows.flatMap { crossings(label: $0.0, percent: $0.1, thresholds: thresholds) }
  }

  private func crossings(label: String, percent: Double, thresholds: [Int]) -> [ThresholdCrossing] {
    resetFiredKeysIfCycleRestarted(label: label, percent: percent)

    var result: [ThresholdCrossing] = []
    for threshold in thresholds.sorted() where percent >= Double(threshold) {
      let key = "\(label)_\(threshold)"
      guard !firedKeys.contains(key) else { continue }
      firedKeys.insert(key)
      result.append(ThresholdCrossing(label: label, percent: percent, threshold: threshold))
    }

    lastPercentByWindow[label] = percent
    return result
  }

  private func resetFiredKeysIfCycleRestarted(label: String, percent: Double) {
    guard let previous = lastPercentByWindow[label], percent < previous - 5 else { return }
    firedKeys = firedKeys.filter { !$0.hasPrefix("\(label)_") }
  }
}
