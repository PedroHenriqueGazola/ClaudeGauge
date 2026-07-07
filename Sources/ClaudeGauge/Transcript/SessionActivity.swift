import Foundation

enum SessionActivityKind {
  case working
  case turnEnded
}

// Um evento emitido pelo TranscriptWatcher a cada linha relevante do transcript.
// `isLive` distingue atividade em tempo real (via FSEvents) do estado inicial
// lido da cauda dos transcripts no start — só a ao vivo dispara notificação.
struct SessionActivity {
  let sessionId: String
  let project: String?
  let title: String?
  let kind: SessionActivityKind
  let timestamp: Date
  let isLive: Bool
}

enum SessionStatus {
  case working
  case awaitingUser
  case idle

  var sortPriority: Int {
    switch self {
    case .awaitingUser: return 0
    case .working: return 1
    case .idle: return 2
    }
  }
}

struct ClaudeSessionState: Identifiable, Equatable {
  let id: String
  var project: String?
  var title: String?
  var status: SessionStatus
  var lastActivityAt: Date
}
