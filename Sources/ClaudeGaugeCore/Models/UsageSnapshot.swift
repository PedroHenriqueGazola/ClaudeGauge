import Foundation

public struct UsageWindow: Equatable {
  public let percent: Double
  public let resetsAt: Date?

  public init(percent: Double, resetsAt: Date?) {
    self.percent = percent
    self.resetsAt = resetsAt
  }
}

public struct ExtraUsage: Equatable {
  public let isEnabled: Bool
  public let usedCredits: Double?
  public let monthlyLimit: Double?
  public let currency: String?

  public init(isEnabled: Bool, usedCredits: Double?, monthlyLimit: Double?, currency: String?) {
    self.isEnabled = isEnabled
    self.usedCredits = usedCredits
    self.monthlyLimit = monthlyLimit
    self.currency = currency
  }
}

public struct UsageSnapshot: Equatable {
  public let fiveHour: UsageWindow?
  public let sevenDay: UsageWindow?
  public let opusWeekly: UsageWindow?
  public let sonnetWeekly: UsageWindow?
  public let extraUsage: ExtraUsage?
  public let subscriptionType: String?
  public let lastUpdated: Date

  public init(
    fiveHour: UsageWindow?, sevenDay: UsageWindow?, opusWeekly: UsageWindow?,
    sonnetWeekly: UsageWindow?, extraUsage: ExtraUsage?, subscriptionType: String?,
    lastUpdated: Date
  ) {
    self.fiveHour = fiveHour
    self.sevenDay = sevenDay
    self.opusWeekly = opusWeekly
    self.sonnetWeekly = sonnetWeekly
    self.extraUsage = extraUsage
    self.subscriptionType = subscriptionType
    self.lastUpdated = lastUpdated
  }

  public var headlinePercent: Double {
    [fiveHour?.percent, sevenDay?.percent].compactMap { $0 }.max() ?? 0
  }
}
