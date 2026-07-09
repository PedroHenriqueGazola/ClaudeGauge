import Foundation

// Lê os transcripts do Claude Code (~/.claude/projects/**/*.jsonl) e soma os
// tokens por modelo e por projeto (cwd) numa janela de dias, estimando o custo
// equivalente API. Pré-filtra por mtime pra só abrir arquivos recentes e ainda
// confere o timestamp de cada linha pra respeitar o limite da janela. Roda em
// background (fora do MainActor) — o resultado é publicado pelo UsageModel.
public enum SpendAggregator {
  public static func report(projectsDirectory: URL, windowDays: Int, now: Date) -> SpendReport {
    let cutoff = now.addingTimeInterval(-Double(windowDays) * 86_400)
    var byModel: [String: Accumulator] = [:]
    var byProject: [String: Accumulator] = [:]

    for file in transcriptFiles(in: projectsDirectory)
    where modificationDate(file) > cutoff {
      accumulate(file: file, cutoff: cutoff, byModel: &byModel, byProject: &byProject)
    }

    return SpendReport(
      models: entries(from: byModel, name: ModelCatalog.displayName(forModel:)),
      projects: entries(from: byProject, name: { $0 }),
      windowDays: windowDays,
      generatedAt: now)
  }

  private struct Accumulator {
    var inputTokens = 0
    var outputTokens = 0
    var cacheCreationTokens = 0
    var cacheReadTokens = 0
    var cost = 0.0
  }

  private static func accumulate(
    file: URL, cutoff: Date, byModel: inout [String: Accumulator],
    byProject: inout [String: Accumulator]
  ) {
    guard let data = FileManager.default.contents(atPath: file.path) else { return }
    for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
      guard let usage = billableUsage(line: Data(line), cutoff: cutoff) else { continue }
      add(usage, to: &byModel[usage.model, default: Accumulator()])
      add(usage, to: &byProject[usage.project, default: Accumulator()])
    }
  }

  private struct BillableUsage {
    let model: String
    let project: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Double
  }

  private static func billableUsage(line: Data, cutoff: Date) -> BillableUsage? {
    guard let row = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
      row["type"] as? String == "assistant",
      let message = row["message"] as? [String: Any],
      let model = message["model"] as? String,
      let usage = message["usage"] as? [String: Any],
      let pricing = ModelCatalog.pricing(forModel: model)
    else { return nil }
    if let timestamp = timestamp(row), timestamp < cutoff { return nil }

    let input = usage["input_tokens"] as? Int ?? 0
    let output = usage["output_tokens"] as? Int ?? 0
    let cacheWrite = cacheWriteTokens(usage)
    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

    return BillableUsage(
      model: model,
      project: project(from: row),
      inputTokens: input,
      outputTokens: output,
      cacheCreationTokens: cacheWrite.fiveMinute + cacheWrite.oneHour,
      cacheReadTokens: cacheRead,
      cost: pricing.cost(
        inputTokens: input, outputTokens: output, cacheWrite5mTokens: cacheWrite.fiveMinute,
        cacheWrite1hTokens: cacheWrite.oneHour, cacheReadTokens: cacheRead))
  }

  private static func add(_ usage: BillableUsage, to accumulator: inout Accumulator) {
    accumulator.inputTokens += usage.inputTokens
    accumulator.outputTokens += usage.outputTokens
    accumulator.cacheCreationTokens += usage.cacheCreationTokens
    accumulator.cacheReadTokens += usage.cacheReadTokens
    accumulator.cost += usage.cost
  }

  private static func entries(from accumulators: [String: Accumulator], name: (String) -> String)
    -> [SpendEntry]
  {
    accumulators
      .map { key, value in
        SpendEntry(
          id: key,
          name: name(key),
          inputTokens: value.inputTokens,
          outputTokens: value.outputTokens,
          cacheCreationTokens: value.cacheCreationTokens,
          cacheReadTokens: value.cacheReadTokens,
          estimatedCost: value.cost)
      }
      .sorted { $0.estimatedCost > $1.estimatedCost }
  }

  private static func project(from row: [String: Any]) -> String {
    guard let cwd = row["cwd"] as? String, !cwd.isEmpty else { return "—" }
    return URL(fileURLWithPath: cwd).lastPathComponent
  }

  // O cache write vem detalhado por TTL (`cache_creation: {ephemeral_5m…,
  // ephemeral_1h…}`), que têm preços diferentes (5m=1.25x, 1h=2x). Sem o
  // breakdown, trata o total (`cache_creation_input_tokens`) como 5m.
  private static func cacheWriteTokens(_ usage: [String: Any]) -> (fiveMinute: Int, oneHour: Int) {
    if let detail = usage["cache_creation"] as? [String: Any] {
      let fiveMinute = detail["ephemeral_5m_input_tokens"] as? Int ?? 0
      let oneHour = detail["ephemeral_1h_input_tokens"] as? Int ?? 0
      if fiveMinute > 0 || oneHour > 0 { return (fiveMinute, oneHour) }
    }
    return (usage["cache_creation_input_tokens"] as? Int ?? 0, 0)
  }

  private static func timestamp(_ row: [String: Any]) -> Date? {
    guard let string = row["timestamp"] as? String else { return nil }
    return isoFractional.date(from: string) ?? isoPlain.date(from: string)
  }

  private static func transcriptFiles(in directory: URL) -> [URL] {
    let enumerator = FileManager.default.enumerator(
      at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    let all = enumerator?.allObjects as? [URL] ?? []
    return all.filter { $0.pathExtension == "jsonl" }
  }

  private static func modificationDate(_ file: URL) -> Date {
    let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
    return (attributes?[.modificationDate] as? Date) ?? .distantPast
  }

  private static let isoFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let isoPlain = ISO8601DateFormatter()
}
