import Foundation

struct SpendEntry: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let inputTokens: Int
  let outputTokens: Int
  let cacheCreationTokens: Int
  let cacheReadTokens: Int
  let estimatedCost: Double

  var totalTokens: Int {
    inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
  }
}

struct SpendReport: Equatable, Sendable {
  let models: [SpendEntry]
  let projects: [SpendEntry]
  let windowDays: Int
  let generatedAt: Date

  var totalCost: Double {
    models.reduce(0) { $0 + $1.estimatedCost }
  }

  var isEmpty: Bool {
    models.isEmpty && projects.isEmpty
  }
}
