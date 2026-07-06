import AppKit
import SwiftUI

extension Color {
  init(hex: UInt, alpha: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xff) / 255,
      green: Double((hex >> 8) & 0xff) / 255,
      blue: Double(hex & 0xff) / 255,
      opacity: alpha)
  }
}

extension NSColor {
  convenience init(hex: UInt, alpha: CGFloat = 1) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
      green: CGFloat((hex >> 8) & 0xff) / 255,
      blue: CGFloat(hex & 0xff) / 255,
      alpha: alpha)
  }
}

enum Palette {
  static let card = Color(hex: 0x1d1d1f)
  static let textPrimary = Color(hex: 0xf5f5f7)
  static let textSecondary = Color(hex: 0x8e8e93)
  static let textMuted = Color(hex: 0x6e6e73)
  static let amber = Color(hex: 0xffb340)
  static let green = Color(hex: 0x32d74b)
  static let red = Color(hex: 0xff453a)
  static let claudeOrange = Color(hex: 0xd97757)
  static let headerIcon = Color(hex: 0xe08a5f)
  static let teamText = Color(hex: 0xa9a2f5)
  static let teamBackground = Color(hex: 0x635bff, alpha: 0.15)
  static let teamBorder = Color(hex: 0x635bff, alpha: 0.25)
  static let track = Color.white.opacity(0.09)
  static let divider = Color.white.opacity(0.07)
}

func colorForPercent(_ percent: Double) -> Color {
  switch percent {
  case ..<60: return Palette.green
  case ..<90: return Palette.amber
  default: return Palette.red
  }
}
