import Foundation

public struct UsageRefreshResult {
  public let snapshot: UsageSnapshot?
  public let errorMessage: String?
  public let isStale: Bool
  public let needsReauth: Bool
}

public actor UsageEngine {
  private let authProvider: AuthProvider
  private let apiClient = UsageAPIClient()
  private var snapshot: UsageSnapshot?
  private var nextAllowedFetch: Date = .distantPast
  private var isRefreshing = false

  public init(tokenStore: TokenStoring) {
    authProvider = AuthProvider(tokenStore: tokenStore)
  }

  public func refresh(force: Bool = false) async -> UsageRefreshResult? {
    if !force && Date() < nextAllowedFetch { return nil }
    if isRefreshing { return nil }

    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let auth = try await authProvider.currentAuth()
      let fetched = try await apiClient.fetchUsage(
        accessToken: auth.accessToken,
        subscriptionType: auth.subscriptionType)
      snapshot = fetched
      nextAllowedFetch = Date().addingTimeInterval(30)
      logDebug(fetched)
      return UsageRefreshResult(
        snapshot: fetched, errorMessage: nil, isStale: false, needsReauth: false)
    } catch {
      return handle(error)
    }
  }

  private func handle(_ error: Error) -> UsageRefreshResult {
    var needsReauth = error is AuthError
    if case UsageAPIError.rateLimited(let retryAfter) = error {
      nextAllowedFetch = Date().addingTimeInterval(retryAfter ?? 300)
    }
    if case UsageAPIError.unauthorized = error {
      authProvider.invalidate()
      needsReauth = true
    }
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    if ProcessInfo.processInfo.environment["CLAUDEGAUGE_DEBUG"] != nil {
      FileHandle.standardError.write(Data("[ClaudeGauge] refresh falhou: \(message)\n".utf8))
    }
    return UsageRefreshResult(
      snapshot: snapshot, errorMessage: message, isStale: snapshot != nil, needsReauth: needsReauth)
  }

  private func logDebug(_ snapshot: UsageSnapshot) {
    guard ProcessInfo.processInfo.environment["CLAUDEGAUGE_DEBUG"] != nil else { return }
    func describe(_ label: String, _ window: UsageWindow?) -> String {
      guard let window else { return "\(label)=n/a" }
      return "\(label)=\(Int(window.percent.rounded()))%"
    }
    let parts = [
      describe("5h", snapshot.fiveHour),
      describe("7d", snapshot.sevenDay),
      describe("opus", snapshot.opusWeekly),
      describe("sonnet", snapshot.sonnetWeekly),
      "plan=\(snapshot.subscriptionType ?? "n/a")",
    ]
    FileHandle.standardError.write(
      Data(("[ClaudeGauge] " + parts.joined(separator: " ") + "\n").utf8))
  }
}
