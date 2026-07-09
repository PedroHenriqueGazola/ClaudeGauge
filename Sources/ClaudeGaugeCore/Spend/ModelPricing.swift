import Foundation

// Preços dos modelos Claude (USD por 1M de tokens). Cache write depende do TTL:
// 5min custa 1.25x input, 1h custa 2x; cache read é 0.1x input. É a base pra
// estimar o "custo equivalente API" — o assinante não paga por token, mas é a
// melhor unidade pra comparar quem gastou mais, já que pondera os tipos de token
// (output vale ~10x um input; cache read vale ~1/10).
struct ModelPricing {
  let inputPerMillion: Double
  let outputPerMillion: Double
  let cacheWrite5mPerMillion: Double
  let cacheWrite1hPerMillion: Double
  let cacheReadPerMillion: Double

  func cost(
    inputTokens: Int, outputTokens: Int, cacheWrite5mTokens: Int, cacheWrite1hTokens: Int,
    cacheReadTokens: Int
  ) -> Double {
    let perMillion = 1_000_000.0
    let total =
      Double(inputTokens) * inputPerMillion
      + Double(outputTokens) * outputPerMillion
      + Double(cacheWrite5mTokens) * cacheWrite5mPerMillion
      + Double(cacheWrite1hTokens) * cacheWrite1hPerMillion
      + Double(cacheReadTokens) * cacheReadPerMillion
    return total / perMillion
  }
}

enum ModelCatalog {
  // Retorna nil pra `<synthetic>` e modelos desconhecidos — assim linhas sem
  // custo real ficam de fora da agregação automaticamente.
  static func pricing(forModel model: String) -> ModelPricing? {
    guard let base = baseRates(forModel: model) else { return nil }
    return ModelPricing(
      inputPerMillion: base.input,
      outputPerMillion: base.output,
      cacheWrite5mPerMillion: base.input * 1.25,
      cacheWrite1hPerMillion: base.input * 2.0,
      cacheReadPerMillion: base.input * 0.1)
  }

  static func displayName(forModel model: String) -> String {
    let id = model.lowercased()
    guard let family = family(in: id) else { return model }
    let numbers = id.split(separator: "-").map(String.init).filter {
      $0.count <= 2 && $0.allSatisfy(\.isNumber)
    }
    let version = numbers.prefix(2).joined(separator: ".")
    return version.isEmpty ? family : "\(family) \(version)"
  }

  private static func baseRates(forModel model: String) -> (input: Double, output: Double)? {
    let id = model.lowercased()
    if id.isEmpty || id.hasPrefix("<") { return nil }
    if id.contains("opus") { return isLegacyOpus(id) ? (15, 75) : (5, 25) }
    if id.contains("fable") || id.contains("mythos") { return (10, 50) }
    if id.contains("sonnet") { return (3, 15) }
    if id.contains("haiku") { return haikuRates(id) }
    return nil
  }

  private static func isLegacyOpus(_ id: String) -> Bool {
    id.contains("opus-4-1") || id.contains("opus-4-0") || id.contains("opus-4-2025")
      || id.contains("3-opus")
  }

  private static func haikuRates(_ id: String) -> (input: Double, output: Double) {
    if id.contains("3-5-haiku") || id.contains("haiku-3-5") { return (0.80, 4) }
    if id.contains("3-haiku") || id.contains("haiku-3") { return (0.25, 1.25) }
    return (1, 5)
  }

  private static func family(in id: String) -> String? {
    if id.contains("opus") { return "Opus" }
    if id.contains("sonnet") { return "Sonnet" }
    if id.contains("haiku") { return "Haiku" }
    if id.contains("fable") { return "Fable" }
    if id.contains("mythos") { return "Mythos" }
    return nil
  }
}
