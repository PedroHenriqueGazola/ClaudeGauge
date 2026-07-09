import Foundation

public func resetText(for date: Date?) -> String {
  guard let date else { return "" }
  let interval = date.timeIntervalSinceNow
  if interval <= 0 { return "resetando…" }

  let totalMinutes = Int(interval) / 60
  let days = totalMinutes / (60 * 24)
  let hours = (totalMinutes % (60 * 24)) / 60
  let minutes = totalMinutes % 60

  if days > 0 { return "reseta em \(days)d \(hours)h" }
  if hours > 0 { return "reseta em \(hours)h \(minutes)min" }
  return "reseta em \(minutes)min"
}

public func formatCost(_ value: Double) -> String {
  if value <= 0 { return "$0" }
  if value < 0.01 { return "<$0.01" }
  return String(format: "$%.2f", value)
}

public func formatTokens(_ count: Int) -> String {
  let value = Double(count)
  if value >= 1_000_000_000 { return String(format: "%.1fB", value / 1_000_000_000) }
  if value >= 1_000_000 { return String(format: "%.0fM", value / 1_000_000) }
  if value >= 1_000 { return String(format: "%.0fK", value / 1_000) }
  return "\(count)"
}
