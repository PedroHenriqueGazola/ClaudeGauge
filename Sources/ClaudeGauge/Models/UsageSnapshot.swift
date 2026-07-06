import Foundation

struct UsageWindow: Equatable {
  let percent: Double
  let resetsAt: Date?
}

struct ExtraUsage: Equatable {
  let isEnabled: Bool
  let usedCredits: Double?
  let monthlyLimit: Double?
  let currency: String?
}

struct UsageSnapshot: Equatable {
  let fiveHour: UsageWindow?
  let sevenDay: UsageWindow?
  let opusWeekly: UsageWindow?
  let sonnetWeekly: UsageWindow?
  let extraUsage: ExtraUsage?
  let subscriptionType: String?
  let lastUpdated: Date

  var headlinePercent: Double {
    [fiveHour?.percent, sevenDay?.percent].compactMap { $0 }.max() ?? 0
  }
}
