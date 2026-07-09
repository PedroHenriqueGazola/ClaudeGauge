import ClaudeGaugeCore
import SwiftUI

func elapsedText(since date: Date) -> String {
  let seconds = Int(Date().timeIntervalSince(date))
  if seconds < 45 { return "agora" }
  let minutes = seconds / 60
  if minutes < 60 { return "\(max(minutes, 1))min" }
  return "\(minutes / 60)h"
}

// Mostra o custo estimado em destaque e os tokens como detalhe secundário —
// tokens crus enganam (cache read é volumoso mas barato), o $ pondera os tipos.
struct SpendRow: View {
  let entry: SpendEntry

  var body: some View {
    HStack(spacing: 9) {
      Text(entry.name)
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(Palette.textPrimary)
        .lineLimit(1)
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 1) {
        Text(formatCost(entry.estimatedCost))
          .font(.system(size: 12.5, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(Palette.claudeOrange)
        Text("\(formatTokens(entry.totalTokens)) tok")
          .font(.system(size: 10))
          .monospacedDigit()
          .foregroundStyle(Palette.textMuted)
      }
    }
  }
}

struct SessionRow: View {
  let session: ClaudeSessionState

  var body: some View {
    HStack(spacing: 9) {
      Circle().fill(color).frame(width: 7, height: 7)
      VStack(alignment: .leading, spacing: 1) {
        Text(session.project ?? "sessão")
          .font(.system(size: 12.5, weight: .medium))
          .foregroundStyle(Palette.textPrimary)
          .lineLimit(1)
        if let title = session.title, !title.isEmpty {
          Text(title)
            .font(.system(size: 11))
            .foregroundStyle(Palette.textSecondary)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 8)
      Text(statusText)
        .font(.system(size: 10.5))
        .foregroundStyle(color)
        .lineLimit(1)
    }
  }

  private var color: Color {
    switch session.status {
    case .awaitingUser: return Palette.claudeOrange
    case .working: return Palette.green
    case .idle: return Palette.textMuted
    }
  }

  private var statusText: String {
    "\(statusLabel) · \(elapsedText(since: session.lastActivityAt))"
  }

  private var statusLabel: String {
    switch session.status {
    case .awaitingUser: return "esperando você"
    case .working: return "trabalhando"
    case .idle: return "ociosa"
    }
  }
}

// Placeholder pulsante enquanto a agregação de gastos roda em background.
struct SpendSkeleton: View {
  @State private var pulse = false

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      group()
      group()
    }
    .opacity(pulse ? 0.4 : 0.85)
    .onAppear {
      withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
        pulse = true
      }
    }
  }

  private func group() -> some View {
    VStack(alignment: .leading, spacing: 12) {
      bar(width: 62, height: 10)
      ForEach(0..<3, id: \.self) { _ in
        HStack {
          bar(width: 120, height: 12)
          Spacer()
          bar(width: 52, height: 12)
        }
      }
    }
  }

  private func bar(width: CGFloat, height: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 4, style: .continuous)
      .fill(Palette.track)
      .frame(width: width, height: height)
  }
}

struct IconBadge: View {
  let systemName: String
  let iconColor: Color
  var backgroundColor: Color?
  var size: CGFloat = 26
  var iconSize: CGFloat = 15
  var corner: CGFloat = 7

  var body: some View {
    RoundedRectangle(cornerRadius: corner, style: .continuous)
      .fill(backgroundColor ?? iconColor.opacity(0.14))
      .frame(width: size, height: size)
      .overlay(
        Image(systemName: systemName)
          .font(.system(size: iconSize))
          .foregroundStyle(iconColor)
      )
  }
}

struct MeterBar: View {
  let percent: Double

  @State private var animated = false

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Palette.track)
        Capsule()
          .fill(colorForPercent(percent))
          .frame(width: animated ? fillWidth(in: geometry.size.width) : 0)
      }
    }
    .frame(height: 8)
    .onAppear {
      withAnimation(.easeOut(duration: 0.5)) { animated = true }
    }
  }

  private func fillWidth(in total: CGFloat) -> CGFloat {
    let fraction = min(max(percent, 0), 100) / 100
    return percent > 0 ? max(fraction * total, 6) : 0
  }
}

struct MetricRow: View {
  let icon: String
  let title: String
  let subtitle: String
  let window: UsageWindow

  private var color: Color { colorForPercent(window.percent) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        IconBadge(systemName: icon, iconColor: color)
        (Text(title).foregroundColor(Palette.textPrimary)
          + Text(" · \(subtitle)").foregroundColor(Palette.textSecondary))
          .font(.system(size: 13.5))
        Spacer()
        Text("\(Int(window.percent.rounded()))%")
          .font(.system(size: 20, weight: .semibold))
          .monospacedDigit()
          .tracking(-0.3)
          .foregroundStyle(color)
      }
      .padding(.bottom, 9)

      MeterBar(percent: window.percent)

      let reset = resetText(for: window.resetsAt)
      if !reset.isEmpty {
        HStack(spacing: 5) {
          Image(systemName: "arrow.clockwise").font(.system(size: 11))
          Text(reset)
        }
        .font(.system(size: 12))
        .foregroundStyle(Palette.textSecondary)
        .padding(.top, 6)
      }
    }
  }
}
