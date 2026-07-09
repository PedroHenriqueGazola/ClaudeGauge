import Foundation

public struct SpendEntry: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let inputTokens: Int
  public let outputTokens: Int
  public let cacheCreationTokens: Int
  public let cacheReadTokens: Int
  public let estimatedCost: Double

  public var totalTokens: Int {
    inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
  }
}

public struct SpendReport: Equatable, Sendable {
  public let models: [SpendEntry]
  public let projects: [SpendEntry]
  public let windowDays: Int
  public let generatedAt: Date

  public var totalCost: Double {
    models.reduce(0) { $0 + $1.estimatedCost }
  }

  public var isEmpty: Bool {
    models.isEmpty && projects.isEmpty
  }
}
