import Foundation

// Dados fictícios pra tirar screenshots da aba Gastos sem expor projetos e
// gastos reais. Ativado pela env var CLAUDEGAUGE_DEMO (ver UsageModel.refreshSpend).
// Escala pela janela pedida pra o filtro 24h/7d/30d parecer real ao trocar.
extension SpendReport {
  public static func demo(windowDays: Int) -> SpendReport {
    let scale = Double(windowDays) / 30.0
    func entry(_ name: String, cost: Double, tokens: Int) -> SpendEntry {
      SpendEntry(
        id: name, name: name, inputTokens: Int(Double(tokens) * scale), outputTokens: 0,
        cacheCreationTokens: 0, cacheReadTokens: 0, estimatedCost: cost * scale)
    }
    let models = [
      entry("Opus 4.8", cost: 612.40, tokens: 1_800_000_000),
      entry("Sonnet 5", cost: 124.80, tokens: 420_000_000),
      entry("Fable 5", cost: 87.00, tokens: 44_000_000),
      entry("Haiku 4.5", cost: 18.30, tokens: 210_000_000),
    ]
    let projects = [
      entry("api-gateway", cost: 214.60, tokens: 640_000_000),
      entry("web-dashboard", cost: 186.30, tokens: 520_000_000),
      entry("infra-terraform", cost: 121.40, tokens: 300_000_000),
      entry("mobile-app", cost: 98.70, tokens: 260_000_000),
      entry("ml-experiments", cost: 77.20, tokens: 180_000_000),
      entry("cron-jobs", cost: 61.10, tokens: 150_000_000),
      entry("landing-site", cost: 49.90, tokens: 120_000_000),
      entry("sandbox", cost: 33.30, tokens: 90_000_000),
    ]
    return SpendReport(
      models: models, projects: projects, windowDays: windowDays, generatedAt: Date())
  }
}
