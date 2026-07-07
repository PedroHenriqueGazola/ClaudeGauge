import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UsageModel {
  static let shared = UsageModel()

  private(set) var snapshot: UsageSnapshot?
  private(set) var errorMessage: String?
  private(set) var isRefreshing = false
  private(set) var isStale = false

  private let authProvider = AuthProvider()
  private let apiClient = UsageAPIClient()
  private let notifier = NotificationCenterService()
  let sessionRegistry: SessionRegistry
  private var timer: Timer?
  private var nextAllowedFetch: Date = .distantPast

  private init() {
    let notifier = notifier
    sessionRegistry = SessionRegistry { session in
      guard UserDefaults.standard.object(forKey: "notifyOnTurnEnd") as? Bool ?? true else { return }
      notifier.notify(.finished(session))
    }
  }

  private var refreshIntervalSeconds: Double {
    let stored = UserDefaults.standard.double(forKey: "refreshIntervalSeconds")
    return stored >= 60 ? stored : 180
  }

  func start() {
    notifier.requestAuthorizationIfNeeded()
    Task { await refresh() }
    scheduleTimer()
    sessionRegistry.start()
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { [weak self] in await self?.refresh() }
    }
  }

  func notifyClaudeHook(_ event: ClaudeHookEvent) {
    notifier.notify(event)
  }

  func scheduleTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: refreshIntervalSeconds, repeats: true) {
      [weak self] _ in
      Task { [weak self] in await self?.refresh() }
    }
  }

  func refresh(force: Bool = false) async {
    if !force && Date() < nextAllowedFetch { return }
    if isRefreshing { return }

    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let auth = try await authProvider.currentAuth()
      let snapshot = try await apiClient.fetchUsage(
        accessToken: auth.accessToken,
        subscriptionType: auth.subscriptionType)
      self.snapshot = snapshot
      errorMessage = nil
      isStale = false
      nextAllowedFetch = Date().addingTimeInterval(30)
      notifier.evaluate(snapshot: snapshot)
      logDebug(snapshot)
    } catch {
      handle(error)
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
    FileHandle.standardError.write(Data(("[ClaudeGauge] " + parts.joined(separator: " ") + "\n").utf8))
  }

  private func handle(_ error: Error) {
    isStale = snapshot != nil
    if case UsageAPIError.rateLimited(let retryAfter) = error {
      nextAllowedFetch = Date().addingTimeInterval(retryAfter ?? 300)
    }
    if case UsageAPIError.unauthorized = error {
      authProvider.invalidate()
    }
    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
  }
}
