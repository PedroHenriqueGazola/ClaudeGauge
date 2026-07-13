import AppKit
import ClaudeGaugeCore
import SwiftUI

@MainActor
struct PopoverView: View {
  let model: UsageModel
  let onOpenSettings: () -> Void

  private enum Tab {
    case usage
    case spend
  }

  @State private var selectedTab: Tab = .usage
  @AppStorage("spendPeriodDays") private var spendPeriodDays = 7

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      tabBar
      tabContent
      footer
    }
    .frame(width: 296)
    .background(Palette.card)
    .preferredColorScheme(.dark)
    .onAppear {
      Task { await model.refresh() }
      model.refreshSpend(periodDays: spendPeriodDays)
    }
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

  private var tabBar: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        tabButton("Uso", .usage)
        tabButton("Gastos", .spend)
      }
      Rectangle().fill(Palette.divider).frame(height: 1)
    }
  }

  private func tabButton(_ title: String, _ tab: Tab) -> some View {
    let isActive = selectedTab == tab
    return Button {
      selectedTab = tab
      if tab == .spend { model.refreshSpend(periodDays: spendPeriodDays) }
    } label: {
      VStack(spacing: 7) {
        Text(title)
          .font(.system(size: 12.5, weight: isActive ? .semibold : .medium))
          .foregroundStyle(isActive ? Palette.textPrimary : Palette.textMuted)
        Rectangle()
          .fill(isActive ? Palette.claudeOrange : Color.clear)
          .frame(height: 2)
      }
      .padding(.top, 8)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var tabContent: some View {
    switch selectedTab {
    case .usage:
      usageTab
    case .spend:
      spendTab
    }
  }

  // MARK: - Uso

  @ViewBuilder
  private var usageTab: some View {
    content
    sessionsSection
  }

  @ViewBuilder
  private var content: some View {
    if model.needsReauth {
      reauthBanner
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
    } else if let snapshot = model.snapshot {
      metrics(snapshot)
        .padding(.horizontal, 16)
        .padding(.top, 14)
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

  private var reauthBanner: some View {
    let hasAccount = LoginModel.shared.isLoggedIn
    return VStack(alignment: .leading, spacing: 8) {
      Label(
        hasAccount ? "Login expirou" : "Nenhuma conta conectada",
        systemImage: "person.crop.circle.badge.exclamationmark"
      )
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(Palette.amber)
      Text(
        hasAccount
          ? "Não consegui renovar a sessão. Reconecte pra ver o uso atualizado."
          : "Entre com sua conta Claude pra acompanhar o uso."
      )
      .font(.system(size: 12))
      .foregroundStyle(Palette.textSecondary)
      .fixedSize(horizontal: false, vertical: true)
      Button(hasAccount ? "Reconectar" : "Entrar com Claude") { openSettingsWindow() }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.claudeOrange)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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

  @ViewBuilder
  private var sessionsSection: some View {
    let sessions = model.sessionRegistry.sessions
    if !sessions.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        Rectangle().fill(Palette.divider).frame(height: 1)
        HStack {
          Text("SESSÕES")
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Palette.textMuted)
          Spacer()
          Text("\(sessions.count)")
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Palette.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 9)
        VStack(spacing: 11) {
          ForEach(sessions.prefix(6)) { session in
            SessionRow(session: session)
          }
          if sessions.count > 6 {
            Text("+\(sessions.count - 6) outras")
              .font(.system(size: 11))
              .foregroundStyle(Palette.textMuted)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
      }
    }
  }

  // MARK: - Gastos

  @ViewBuilder
  private var spendTab: some View {
    VStack(alignment: .leading, spacing: 0) {
      periodPicker
      spendBody
    }
  }

  private var periodPicker: some View {
    Picker("Período", selection: $spendPeriodDays) {
      Text("24h").tag(1)
      Text("7 dias").tag(7)
      Text("30 dias").tag(30)
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .onChange(of: spendPeriodDays) { _, newValue in
      model.refreshSpend(periodDays: newValue, force: true)
    }
  }

  @ViewBuilder
  private var spendBody: some View {
    if showSpendSkeleton {
      SpendSkeleton()
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
    } else if let report = model.spendReport, report.windowDays == spendPeriodDays,
      !report.isEmpty
    {
      spendReportView(report)
    } else {
      spendEmpty
    }
  }

  private var showSpendSkeleton: Bool {
    model.isComputingSpend && model.spendReport?.windowDays != spendPeriodDays
  }

  private func spendReportView(_ report: SpendReport) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text("TOTAL")
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Palette.textMuted)
          Text("custo equivalente estimado (API)")
            .font(.system(size: 9.5))
            .foregroundStyle(Palette.textMuted)
        }
        Spacer()
        Text("≈ \(formatCost(report.totalCost))")
          .font(.system(size: 18, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(Palette.claudeOrange)
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 4)

      spendGroup("Modelos", entries: report.models)
      spendGroup("Projetos", entries: report.projects)
        .padding(.bottom, 14)
    }
  }

  @ViewBuilder
  private func spendGroup(_ title: String, entries: [SpendEntry]) -> some View {
    if !entries.isEmpty {
      VStack(alignment: .leading, spacing: 9) {
        Text(title)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Palette.textSecondary)
        ForEach(entries.prefix(5)) { entry in
          SpendRow(entry: entry)
        }
        if entries.count > 5 {
          Text("+\(entries.count - 5) outros")
            .font(.system(size: 11))
            .foregroundStyle(Palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
    }
  }

  private var spendEmpty: some View {
    Text("Sem gastos registrados no período.")
      .font(.system(size: 12))
      .foregroundStyle(Palette.textMuted)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 20)
  }

  // MARK: - Comuns

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
        iconButton("arrow.clockwise") { refreshActiveTab() }
          .disabled(isActiveTabRefreshing)
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

  private func refreshActiveTab() {
    switch selectedTab {
    case .usage: Task { await model.refresh(force: true) }
    case .spend: model.refreshSpend(periodDays: spendPeriodDays, force: true)
    }
  }

  private var isActiveTabRefreshing: Bool {
    selectedTab == .usage ? model.isRefreshing : model.isComputingSpend
  }

  private var updatedText: String {
    if selectedTab == .spend {
      if let report = model.spendReport, report.windowDays == spendPeriodDays {
        return "atualizado \(report.generatedAt.formatted(date: .omitted, time: .shortened))"
      }
      return model.isComputingSpend ? "calculando…" : ""
    }
    if model.needsReauth { return "sem conexão com a conta" }
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
