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
