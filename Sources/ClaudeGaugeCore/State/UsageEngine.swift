import Foundation

public struct AccountUsage: Sendable, Identifiable {
  public let id: String
  public let organizationName: String?
  public let subscriptionType: String?
  public let snapshot: UsageSnapshot?
  public let errorMessage: String?
  public let needsReauth: Bool
}

public struct UsageRefreshResult {
  // Campos da conta ativa (barra de menu + tray Linux + compat).
  public let snapshot: UsageSnapshot?
  public let errorMessage: String?
  public let isStale: Bool
  public let needsReauth: Bool
  // Todas as contas (pra o popover "ver as duas").
  public let accounts: [AccountUsage]
  public let activeId: String?
}

public actor UsageEngine {
  private let authProvider: AuthProvider
  private let apiClient = UsageAPIClient()
  private var snapshotById: [String: UsageSnapshot] = [:]
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

    let resolved = await authProvider.currentAccounts()
    guard !resolved.accounts.isEmpty else {
      return UsageRefreshResult(
        snapshot: nil, errorMessage: AuthError.noAccount.errorDescription, isStale: false,
        needsReauth: true, accounts: [], activeId: nil)
    }

    var usages: [AccountUsage] = []
    var anySuccess = false
    for account in resolved.accounts {
      usages.append(await fetch(account))
      if usages.last?.errorMessage == nil { anySuccess = true }
    }
    if anySuccess { nextAllowedFetch = Date().addingTimeInterval(30) }

    let active = usages.first { $0.id == resolved.activeId } ?? usages.first
    if let snapshot = active?.snapshot, active?.errorMessage == nil { logDebug(snapshot) }

    return UsageRefreshResult(
      snapshot: active?.snapshot,
      errorMessage: active?.errorMessage,
      isStale: active?.errorMessage != nil && active?.snapshot != nil,
      needsReauth: active?.needsReauth ?? false,
      accounts: usages,
      activeId: active?.id)
  }

  private func fetch(_ account: ResolvedAccount) async -> AccountUsage {
    do {
      let snapshot = try await apiClient.fetchUsage(
        accessToken: account.accessToken, subscriptionType: account.subscriptionType)
      snapshotById[account.id] = snapshot
      return AccountUsage(
        id: account.id, organizationName: account.organizationName,
        subscriptionType: account.subscriptionType, snapshot: snapshot, errorMessage: nil,
        needsReauth: false)
    } catch {
      if case UsageAPIError.rateLimited(let retryAfter) = error {
        nextAllowedFetch = Date().addingTimeInterval(retryAfter ?? 300)
      }
      var needsReauth = false
      if case UsageAPIError.unauthorized = error { needsReauth = true }
      let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      if ProcessInfo.processInfo.environment["CLAUDEGAUGE_DEBUG"] != nil {
        FileHandle.standardError.write(Data("[ClaudeGauge] refresh falhou: \(message)\n".utf8))
      }
      return AccountUsage(
        id: account.id, organizationName: account.organizationName,
        subscriptionType: account.subscriptionType, snapshot: snapshotById[account.id],
        errorMessage: message, needsReauth: needsReauth)
    }
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
