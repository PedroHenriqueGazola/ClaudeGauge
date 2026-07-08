import AppKit
import ClaudeGaugeCore
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

  private let engine = UsageEngine(tokenStore: KeychainTokenStore())
  private let notifier = NotificationCenterService()
  let sessionRegistry: SessionRegistry
  private var timer: Timer?

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
    syncAttentionHook()
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { [weak self] in await self?.refresh() }
    }
  }

  func notifyClaudeHook(_ event: ClaudeHookEvent) {
    notifier.notify(enrich(event))
  }

  // Pro aviso de "precisa de você", tenta mostrar o que o Claude quer (ex.: o
  // comando que ele pediu pra rodar), lido da última tool_use do transcript.
  private func enrich(_ event: ClaudeHookEvent) -> ClaudeHookEvent {
    guard case .needsAttention(var session) = event,
      let path = session.transcriptPath,
      let summary = ClaudeTranscript.pendingToolSummary(transcriptPath: path)
    else { return event }
    session.detail = summary
    return .needsAttention(session)
  }

  // Reaplica o hook de "precisa de você" no launch pra manter o caminho do
  // script (dentro do .app) válido caso o app tenha sido movido/atualizado.
  private func syncAttentionHook() {
    guard UserDefaults.standard.bool(forKey: "notifyOnAttention") else { return }
    ClaudeHookInstaller.setNotificationHook(enabled: true)
  }

  func scheduleTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: refreshIntervalSeconds, repeats: true) {
      [weak self] _ in
      Task { [weak self] in await self?.refresh() }
    }
  }

  func refresh(force: Bool = false) async {
    if isRefreshing { return }

    isRefreshing = true
    defer { isRefreshing = false }

    guard let result = await engine.refresh(force: force) else { return }
    snapshot = result.snapshot
    errorMessage = result.errorMessage
    isStale = result.isStale
    if result.errorMessage == nil, let snapshot = result.snapshot {
      notifier.evaluate(snapshot: snapshot)
    }
  }
}
