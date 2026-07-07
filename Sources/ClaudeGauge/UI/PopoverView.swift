import AppKit
import SwiftUI

@MainActor
struct PopoverView: View {
  let model: UsageModel
  let onOpenSettings: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      content
      footer
    }
    .frame(width: 296)
    .background(Palette.card)
    .onAppear { Task { await model.refresh() } }
  }

  private var header: some View {
    HStack(spacing: 10) {
      IconBadge(
        systemName: "sparkles",
        iconColor: Palette.headerIcon,
        backgroundColor: Palette.claudeOrange.opacity(0.16),
        size: 28, iconSize: 16, corner: 8)
      Text("Uso do Claude")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Palette.textPrimary)
      Spacer()
      if let plan = model.snapshot?.subscriptionType, !plan.isEmpty {
        Text(plan.capitalized)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Palette.teamText)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(Palette.teamBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .stroke(Palette.teamBorder, lineWidth: 1))
      }
    }
    .padding(.top, 14)
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
  }

  @ViewBuilder
  private var content: some View {
    if let snapshot = model.snapshot {
      metrics(snapshot)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
    } else if let error = model.errorMessage {
      errorView(error)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    } else {
      ProgressView()
        .controlSize(.small)
        .tint(Palette.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
  }

  private func metrics(_ snapshot: UsageSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      if let window = snapshot.fiveHour {
        MetricRow(icon: "clock", title: "Sessão", subtitle: "5h", window: window)
      }
      if let window = snapshot.sevenDay {
        MetricRow(icon: "calendar", title: "Semanal", subtitle: "todos", window: window)
      }
      if let window = snapshot.opusWeekly {
        MetricRow(icon: "sparkles", title: "Opus", subtitle: "semanal", window: window)
      }
      if let window = snapshot.sonnetWeekly {
        MetricRow(icon: "sparkle", title: "Sonnet", subtitle: "semanal", window: window)
      }
    }
  }

  private func errorView(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Não consegui atualizar", systemImage: "exclamationmark.triangle")
        .font(.system(size: 13))
        .foregroundStyle(Palette.amber)
      Text(message)
        .font(.system(size: 12))
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Button("Entrar com Claude / Configurações") { openSettingsWindow() }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(Palette.claudeOrange)
    }
  }

  private var footer: some View {
    VStack(spacing: 0) {
      Rectangle().fill(Palette.divider).frame(height: 1)
      HStack(spacing: 14) {
        Text(updatedText)
          .font(.system(size: 11.5))
          .foregroundStyle(Palette.textMuted)
          .frame(maxWidth: .infinity, alignment: .leading)
        iconButton("arrow.clockwise") { Task { await model.refresh(force: true) } }
          .disabled(model.isRefreshing)
          .help("Atualizar agora")
        iconButton("gearshape") { openSettingsWindow() }
          .help("Configurações")
        iconButton("power") { NSApp.terminate(nil) }
          .help("Sair")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 11)
    }
  }

  private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 15))
        .foregroundStyle(Palette.textSecondary)
    }
    .buttonStyle(.plain)
  }

  private var updatedText: String {
    guard let updated = model.snapshot?.lastUpdated else {
      return model.isRefreshing ? "atualizando…" : ""
    }
    let prefix = model.isStale ? "desatualizado" : "atualizado"
    return "\(prefix) \(updated.formatted(date: .omitted, time: .shortened))"
  }

  private func openSettingsWindow() {
    onOpenSettings()
  }
}
