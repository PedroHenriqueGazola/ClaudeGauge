import Foundation

// O Claude Code grava cada sessão em ~/.claude/projects/<projeto>/<sessão>.jsonl,
// uma linha JSON por evento. Este watcher observa esses arquivos via FSEvents e
// reporta a atividade de cada sessão (trabalhando / turno terminado), sem
// depender dos hooks do Claude Code — que a política da org pode bloquear
// (allowManagedHooksOnly). No start, lê a cauda dos transcripts recentes pra
// reconstruir o estado das sessões que já estavam abertas.
final class TranscriptWatcher {
  private let projectsDirectory: URL
  private let onActivity: (SessionActivity) -> Void

  private var stream: FSEventStreamRef?
  private var offsetByPath: [String: UInt64] = [:]
  private var titleBySession: [String: String] = [:]
  private let queue = DispatchQueue(label: "com.pedrogazola.claudegauge.transcript")

  private let initialLookback: TimeInterval = 6 * 60 * 60

  init(projectsDirectory: URL = TranscriptWatcher.defaultProjectsDirectory,
       onActivity: @escaping (SessionActivity) -> Void) {
    self.projectsDirectory = projectsDirectory
    self.onActivity = onActivity
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
      self?.loadInitialStates()
      self?.seekToEndOfExistingFiles()
      self?.startStream()
    }
  }

  func stop() {
    queue.async { [weak self] in
      guard let stream = self?.stream else { return }
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
      self?.stream = nil
    }
  }

  private func loadInitialStates() {
    let cutoff = Date().addingTimeInterval(-initialLookback)
    for file in transcriptFiles() where modificationDate(file.path) > cutoff {
      loadTail(file.path)
    }
  }

  private func loadTail(_ path: String) {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
    let rows = content.split(separator: "\n").compactMap { parseLine(Data($0.utf8)) }
    rows.forEach(captureTitle)
    guard let last = rows.last(where: isRelevant) else { return }
    emitActivity(from: last, path: path, isLive: false)
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
      .forEach { row in
        captureTitle(row)
        emitActivity(from: row, path: path, isLive: true)
      }
  }

  private func emitActivity(from row: [String: Any], path: String, isLive: Bool) {
    guard isRelevant(row), let sessionId = row["sessionId"] as? String else { return }
    let cwd = row["cwd"] as? String
    onActivity(
      SessionActivity(
        sessionId: sessionId,
        project: cwd.map { URL(fileURLWithPath: $0).lastPathComponent },
        cwd: cwd,
        title: title(forSession: sessionId, path: path),
        kind: activityKind(row),
        timestamp: timestamp(row) ?? Date(),
        isLive: isLive))
  }

  private func isRelevant(_ row: [String: Any]) -> Bool {
    guard row["isSidechain"] as? Bool != true else { return false }
    let type = row["type"] as? String
    return type == "assistant" || type == "user"
  }

  private func activityKind(_ row: [String: Any]) -> SessionActivityKind {
    guard row["type"] as? String == "assistant" else { return .working }
    let stopReason = (row["message"] as? [String: Any])?["stop_reason"] as? String
    return (stopReason == "end_turn" || stopReason == "stop_sequence") ? .turnEnded : .working
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

  private func captureTitle(_ row: [String: Any]) {
    guard row["type"] as? String == "ai-title",
      let sessionId = row["sessionId"] as? String,
      let title = (row["aiTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !title.isEmpty
    else { return }
    titleBySession[sessionId] = title
  }

  private func title(forSession sessionId: String, path: String) -> String? {
    if let cached = titleBySession[sessionId] { return cached }
    guard let title = readTitleFromFile(path) else { return nil }
    titleBySession[sessionId] = title
    return title
  }

  private func readTitleFromFile(_ path: String) -> String? {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    for line in content.split(separator: "\n").reversed() {
      guard let row = parseLine(Data(line.utf8)),
        row["type"] as? String == "ai-title",
        let title = (row["aiTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
        !title.isEmpty
      else { continue }
      return title
    }
    return nil
  }

  private func timestamp(_ row: [String: Any]) -> Date? {
    guard let string = row["timestamp"] as? String else { return nil }
    return Self.isoFractional.date(from: string) ?? Self.isoPlain.date(from: string)
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

  private func modificationDate(_ path: String) -> Date {
    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    return (attributes?[.modificationDate] as? Date) ?? .distantPast
  }

  private static let isoFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let isoPlain = ISO8601DateFormatter()
}
