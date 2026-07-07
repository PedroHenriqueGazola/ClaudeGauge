import AppKit

enum MenuBarImageRenderer {
  private enum Segment {
    case text(NSAttributedString)
    case icon(NSImage)
    case bar(fraction: Double, color: NSColor)
  }

  private static let height: CGFloat = 18
  private static let horizontalPadding: CGFloat = 2
  private static let gap: CGFloat = 4
  private static let barWidth: CGFloat = 22
  private static let barHeight: CGFloat = 5
  private static let iconPointSize: CGFloat = 12
  private static let fontSize: CGFloat = 12.5

  static func image(for snapshot: UsageSnapshot, dark: Bool) -> NSImage? {
    let windows: [(label: String, window: UsageWindow)] = [
      ("5h", snapshot.fiveHour),
      ("7d", snapshot.sevenDay),
    ].compactMap { label, window in window.map { (label, $0) } }
    guard !windows.isEmpty else { return nil }

    let segments = buildSegments(windows: windows, dark: dark)
    let contentWidth =
      segments.map(width(of:)).reduce(0, +) + gap * CGFloat(max(segments.count - 1, 0))
    let totalWidth = horizontalPadding * 2 + contentWidth

    let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { _ in
      applyGlyphShadow()
      draw(segments: segments, dark: dark)
      return true
    }
    image.isTemplate = false
    return image
  }

  private static func buildSegments(
    windows: [(label: String, window: UsageWindow)], dark: Bool
  ) -> [Segment] {
    var segments: [Segment] = []
    if let icon = sparklesIcon() {
      segments.append(.icon(icon))
    }

    for (index, entry) in windows.enumerated() {
      let percent = entry.window.percent
      segments.append(.text(text(entry.label, color: labelText(dark), weight: .semibold)))
      segments.append(.text(text("\(Int(percent.rounded()))%", color: numberText(dark), weight: .bold)))
      segments.append(.bar(fraction: percent / 100, color: barColor(percent, dark: dark)))
      if entry.label == "5h", let reset = shortReset(entry.window.resetsAt) {
        segments.append(.text(text(reset, color: labelText(dark), weight: .medium)))
      }
      if index < windows.count - 1 {
        segments.append(.text(text("·", color: labelText(dark), weight: .semibold)))
      }
    }
    return segments
  }

  private static func applyGlyphShadow() {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 1
    shadow.shadowOffset = .zero
    shadow.set()
  }

  private static func draw(segments: [Segment], dark: Bool) {
    var x = horizontalPadding
    for segment in segments {
      switch segment {
      case .text(let attributed):
        let size = attributed.size()
        attributed.draw(at: NSPoint(x: x, y: (height - size.height) / 2))
      case .icon(let icon):
        let size = icon.size
        icon.draw(
          in: NSRect(x: x, y: (height - size.height) / 2, width: size.width, height: size.height))
      case .bar(let fraction, let color):
        drawBar(fraction: fraction, color: color, dark: dark, x: x)
      }
      x += width(of: segment) + gap
    }
  }

  private static func drawBar(fraction: Double, color: NSColor, dark: Bool, x: CGFloat) {
    let y = (height - barHeight) / 2
    let track = NSBezierPath(
      roundedRect: NSRect(x: x, y: y, width: barWidth, height: barHeight),
      xRadius: barHeight / 2, yRadius: barHeight / 2)
    trackColor(dark).setFill()
    track.fill()

    let clamped = min(max(fraction, 0), 1)
    let fillWidth = clamped > 0 ? max(barWidth * CGFloat(clamped), 3) : 0
    guard fillWidth > 0 else { return }
    let fill = NSBezierPath(
      roundedRect: NSRect(x: x, y: y, width: fillWidth, height: barHeight),
      xRadius: barHeight / 2, yRadius: barHeight / 2)
    color.setFill()
    fill.fill()
  }

  private static func width(of segment: Segment) -> CGFloat {
    switch segment {
    case .text(let attributed): return ceil(attributed.size().width)
    case .icon(let icon): return icon.size.width
    case .bar: return barWidth
    }
  }

  private static func text(_ string: String, color: NSColor, weight: NSFont.Weight)
    -> NSAttributedString
  {
    NSAttributedString(
      string: string,
      attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
      ])
  }

  private static func shortReset(_ date: Date?) -> String? {
    guard let date else { return nil }
    let interval = date.timeIntervalSinceNow
    guard interval > 0 else { return nil }
    let minutes = Int(interval) / 60
    let hours = minutes / 60
    if hours > 0 { return "\(hours)h\(String(format: "%02d", minutes % 60))" }
    return "\(minutes)m"
  }

  private static func sparklesIcon() -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .bold)
      .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(hex: 0xd97757)]))
    let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration)
    image?.isTemplate = false
    return image
  }

  private static func numberText(_ dark: Bool) -> NSColor {
    dark ? NSColor(hex: 0xf5f5f7) : NSColor(hex: 0x1d1d1f)
  }

  private static func labelText(_ dark: Bool) -> NSColor {
    dark ? NSColor(hex: 0x9a9aa0) : NSColor(hex: 0x6e6e73)
  }

  private static func trackColor(_ dark: Bool) -> NSColor {
    dark ? NSColor.white.withAlphaComponent(0.16) : NSColor.black.withAlphaComponent(0.13)
  }

  private static func barColor(_ percent: Double, dark: Bool) -> NSColor {
    switch percent {
    case ..<60: return dark ? NSColor(hex: 0x32d74b) : NSColor(hex: 0x1f9e46)
    case ..<90: return dark ? NSColor(hex: 0xffb340) : NSColor(hex: 0xd9860a)
    default: return dark ? NSColor(hex: 0xff453a) : NSColor(hex: 0xc70012)
    }
  }
}
