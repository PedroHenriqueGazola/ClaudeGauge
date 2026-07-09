import Foundation

public struct SpendEntry: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let inputTokens: Int
  public let outputTokens: Int
  public let cacheCreationTokens: Int
  public let cacheReadTokens: Int
  public let estimatedCost: Double

  public init(
    id: String, name: String, inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int,
    cacheReadTokens: Int, estimatedCost: Double
  ) {
    self.id = id
    self.name = name
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.cacheCreationTokens = cacheCreationTokens
    self.cacheReadTokens = cacheReadTokens
    self.estimatedCost = estimatedCost
  }

  public var totalTokens: Int {
    inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
  }
}

public struct SpendReport: Equatable, Sendable {
  public let models: [SpendEntry]
  public let projects: [SpendEntry]
  public let windowDays: Int
  public let generatedAt: Date

  public init(models: [SpendEntry], projects: [SpendEntry], windowDays: Int, generatedAt: Date) {
    self.models = models
    self.projects = projects
    self.windowDays = windowDays
    self.generatedAt = generatedAt
  }

  public var totalCost: Double {
    models.reduce(0) { $0 + $1.estimatedCost }
  }

  public var isEmpty: Bool {
    models.isEmpty && projects.isEmpty
  }
}
