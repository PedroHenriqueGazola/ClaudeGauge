import Foundation

// O Claude Code grava cada sessão em ~/.claude/projects/<projeto>/<sessão>.jsonl,
// uma linha JSON por evento. Uma resposta termina quando aparece uma linha
// `type: assistant` com `stop_reason: end_turn` (tool_use = ainda trabalhando).
// Observar esses arquivos é a forma de notificar o fim de um turno sem depender
// dos hooks do Claude Code — que a política da org pode bloquear
// (allowManagedHooksOnly).
final class TranscriptWatcher {
  private let projectsDirectory: URL
  private let onTurnFinished: (String?) -> Void

  private var stream: FSEventStreamRef?
  private var offsetByPath: [String: UInt64] = [:]
  private let queue = DispatchQueue(label: "com.pedrogazola.claudegauge.transcript")

  init(projectsDirectory: URL = TranscriptWatcher.defaultProjectsDirectory,
       onTurnFinished: @escaping (String?) -> Void) {
    self.projectsDirectory = projectsDirectory
    self.onTurnFinished = onTurnFinished
  }

  static var defaultProjectsDirectory: URL {
    let environment = ProcessInfo.processInfo.environment
    let base =
      environment["CLAUDE_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    return base.appendingPathComponent("projects")
  }

  func start() {
    guard FileManager.default.fileExists(atPath: projectsDirectory.path) else { return }
    queue.async { [weak self] in
      self?.seekToEndOfExistingFiles()
      self?.startStream()
    }
  }

  private func seekToEndOfExistingFiles() {
    for file in transcriptFiles() {
      offsetByPath[file.path] = fileSize(file.path)
    }
  }

  private func startStream() {
    var context = FSEventStreamContext(
      version: 0,
      info: Unmanaged.passUnretained(self).toOpaque(),
      retain: nil, release: nil, copyDescription: nil)

    let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
      guard let info else { return }
      let watcher = Unmanaged<TranscriptWatcher>.fromOpaque(info).takeUnretainedValue()
      let changed = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
      watcher.handleChangedPaths(changed)
    }

    let flags = UInt32(
      kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        | kFSEventStreamCreateFlagUseCFTypes)
    guard let stream = FSEventStreamCreate(
      nil, callback, &context, [projectsDirectory.path] as CFArray,
      FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags)
    else { return }

    self.stream = stream
    FSEventStreamSetDispatchQueue(stream, queue)
    FSEventStreamStart(stream)
  }

  private func handleChangedPaths(_ paths: [String]) {
    paths
      .filter { $0.hasSuffix(".jsonl") }
      .forEach(processNewLines(inFileAt:))
  }

  private func processNewLines(inFileAt path: String) {
    guard let data = unreadData(at: path) else { return }
    data
      .split(separator: 0x0A, omittingEmptySubsequences: true)
      .compactMap { parseLine(Data($0)) }
      .filter(isFinishedTurn)
      .forEach { onTurnFinished(projectName(from: $0)) }
  }

  private func unreadData(at path: String) -> Data? {
    guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
    defer { try? handle.close() }

    let start = offsetByPath[path] ?? 0
    try? handle.seek(toOffset: start)
    guard let tail = try? handle.readToEnd(), !tail.isEmpty else { return nil }

    guard let lastNewline = tail.lastIndex(of: 0x0A) else { return nil }
    let completeCount = tail.distance(from: tail.startIndex, to: lastNewline) + 1
    offsetByPath[path] = start + UInt64(completeCount)
    return tail.prefix(completeCount)
  }

  private func parseLine(_ line: Data) -> [String: Any]? {
    try? JSONSerialization.jsonObject(with: line) as? [String: Any]
  }

  private func isFinishedTurn(_ row: [String: Any]) -> Bool {
    guard row["type"] as? String == "assistant" else { return false }
    guard row["isSidechain"] as? Bool != true else { return false }
    guard let message = row["message"] as? [String: Any] else { return false }
    let stopReason = message["stop_reason"] as? String
    return stopReason == "end_turn" || stopReason == "stop_sequence"
  }

  private func projectName(from row: [String: Any]) -> String? {
    guard let cwd = row["cwd"] as? String, !cwd.isEmpty else { return nil }
    return URL(fileURLWithPath: cwd).lastPathComponent
  }

  private func transcriptFiles() -> [URL] {
    let enumerator = FileManager.default.enumerator(
      at: projectsDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles])
    let all = enumerator?.allObjects as? [URL] ?? []
    return all.filter { $0.pathExtension == "jsonl" }
  }

  private func fileSize(_ path: String) -> UInt64 {
    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    return (attributes?[.size] as? UInt64) ?? 0
  }
}
