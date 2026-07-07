import Foundation
import Observation

// Fonte de verdade das sessões do Claude Code em andamento. Consome a atividade
// do TranscriptWatcher, deriva o estado de cada sessão (trabalhando / sua vez /
// ociosa), e publica a lista ordenada pra UI. Quando uma sessão termina o turno
// ao vivo, avisa via onTurnFinished (a notificação de fim de resposta).
@MainActor
@Observable
final class SessionRegistry {
  private(set) var sessions: [ClaudeSessionState] = []

  private var byId: [String: ClaudeSessionState] = [:]
  private let onTurnFinished: (ClaudeSession) -> Void
  private var watcher: TranscriptWatcher?
  private var sweepTimer: Timer?

  private let idleAfter: TimeInterval = 5 * 60
  private let forgetAfter: TimeInterval = 3 * 60 * 60

  init(onTurnFinished: @escaping (ClaudeSession) -> Void) {
    self.onTurnFinished = onTurnFinished
  }

  func start() {
    guard watcher == nil else { return }
    let watcher = TranscriptWatcher { [weak self] activity in
      Task { @MainActor in self?.apply(activity) }
    }
    watcher.start()
    self.watcher = watcher
    scheduleSweep()
  }

  private func apply(_ activity: SessionActivity) {
    let previous = byId[activity.sessionId]
    let wasAwaiting = previous?.status == .awaitingUser

    var state = previous ?? ClaudeSessionState(
      id: activity.sessionId, project: activity.project, title: activity.title,
      status: .working, lastActivityAt: activity.timestamp)
    if let project = activity.project { state.project = project }
    if let title = activity.title { state.title = title }
    state.lastActivityAt = max(state.lastActivityAt, activity.timestamp)
    state.status = status(for: activity.kind, lastActivityAt: state.lastActivityAt)
    byId[activity.sessionId] = state
    republish()

    if activity.isLive, activity.kind == .turnEnded, !wasAwaiting {
      onTurnFinished(ClaudeSession(project: state.project, title: state.title))
    }
  }

  private func status(for kind: SessionActivityKind, lastActivityAt: Date) -> SessionStatus {
    guard Date().timeIntervalSince(lastActivityAt) <= idleAfter else { return .idle }
    return kind == .turnEnded ? .awaitingUser : .working
  }

  private func scheduleSweep() {
    sweepTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.sweep() }
    }
  }

  private func sweep() {
    let now = Date()
    for (id, state) in byId {
      let inactiveFor = now.timeIntervalSince(state.lastActivityAt)
      if inactiveFor > forgetAfter {
        byId[id] = nil
        continue
      }
      if state.status != .idle, inactiveFor > idleAfter {
        byId[id]?.status = .idle
      }
    }
    republish()
  }

  private func republish() {
    sessions = byId.values.sorted(by: ordered)
    logDebug()
  }

  private func logDebug() {
    guard ProcessInfo.processInfo.environment["CLAUDEGAUGE_DEBUG"] != nil else { return }
    let parts = sessions.map { "\($0.project ?? "?")=\($0.status)" }
    FileHandle.standardError.write(
      Data("[ClaudeGauge sessions] \(parts.joined(separator: ", "))\n".utf8))
  }

  private func ordered(_ lhs: ClaudeSessionState, _ rhs: ClaudeSessionState) -> Bool {
    guard lhs.status.sortPriority == rhs.status.sortPriority else {
      return lhs.status.sortPriority < rhs.status.sortPriority
    }
    return lhs.lastActivityAt > rhs.lastActivityAt
  }
}
