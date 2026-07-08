import CAyatanaAppIndicator
import ClaudeGaugeCore
import Foundation

final class TrayApp {
  private let engine = UsageEngine(tokenStore: FileTokenStore())
  private let settingsStore = SettingsStore()
  private let notifier = NotificationService()

  private var indicator: UnsafeMutablePointer<AppIndicator>?
  private var timerID: guint = 0
  private var actions: [MenuAction] = []

  private var usageItems: [UnsafeMutablePointer<GtkWidget>?] = []
  private var statusItem: UnsafeMutablePointer<GtkWidget>?
  private var accountItem: UnsafeMutablePointer<GtkWidget>?
  private var loginItem: UnsafeMutablePointer<GtkWidget>?

  private static let updatedFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
  }()

  func start() {
    setupIndicator()
    updateAccount()
    scheduleTimer()
    triggerRefresh(force: false)
  }

  private func setupIndicator() {
    indicator = app_indicator_new(
      "claudegauge", "claudegauge", APP_INDICATOR_CATEGORY_APPLICATION_STATUS)
    if let path = iconThemePath() {
      app_indicator_set_icon_theme_path(indicator, path)
    }
    app_indicator_set_title(indicator, "ClaudeGauge")
    app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE)

    let menu = buildMenu()
    gtk_widget_show_all(menu)
    app_indicator_set_menu(indicator, gtkCast(menu, to: GtkMenu.self))
  }

  private func iconThemePath() -> String? {
    let fileManager = FileManager.default
    var candidates = [XDG.dataHome.appendingPathComponent("claudegauge/icons")]
    let executable = URL(fileURLWithPath: Autostart.executablePath())
    let buildDirectory = executable.deletingLastPathComponent()
    candidates.append(
      buildDirectory.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/linux"))
    candidates.append(
      buildDirectory.deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Resources/linux"))
    return candidates.first { fileManager.fileExists(atPath: $0.path) }?.path
  }

  private func buildMenu() -> UnsafeMutablePointer<GtkWidget>? {
    let menu = gtk_menu_new()

    for _ in 0..<4 {
      let item = gtk_menu_item_new_with_label("—")
      gtk_widget_set_sensitive(item, 0)
      appendItem(menu, item)
      usageItems.append(item)
    }

    appendItem(menu, gtk_separator_menu_item_new())

    statusItem = gtk_menu_item_new_with_label("carregando…")
    gtk_widget_set_sensitive(statusItem, 0)
    appendItem(menu, statusItem)

    let refreshItem = gtk_menu_item_new_with_label("Atualizar agora")
    connect(refreshItem, signal: "activate") { [weak self] in
      self?.triggerRefresh(force: true)
    }
    appendItem(menu, refreshItem)

    appendItem(menu, gtk_separator_menu_item_new())

    accountItem = gtk_menu_item_new_with_label("—")
    gtk_widget_set_sensitive(accountItem, 0)
    appendItem(menu, accountItem)

    loginItem = gtk_menu_item_new_with_label("Entrar com Claude")
    connect(loginItem, signal: "activate") { [weak self] in
      self?.handleAccountAction()
    }
    appendItem(menu, loginItem)

    let settingsItem = gtk_menu_item_new_with_label("Configurações")
    gtk_menu_item_set_submenu(gtkCast(settingsItem, to: GtkMenuItem.self), buildSettingsMenu())
    appendItem(menu, settingsItem)

    appendItem(menu, gtk_separator_menu_item_new())

    let quitItem = gtk_menu_item_new_with_label("Sair")
    connect(quitItem, signal: "activate") {
      gtk_main_quit()
    }
    appendItem(menu, quitItem)

    return menu
  }

  private func buildSettingsMenu() -> UnsafeMutablePointer<GtkWidget>? {
    let menu = gtk_menu_new()

    let intervalItem = gtk_menu_item_new_with_label("Intervalo")
    let intervalMenu = gtk_menu_new()
    var group: UnsafeMutablePointer<GSList>?
    for (label, seconds) in [("1 min", 60.0), ("2 min", 120.0), ("3 min", 180.0), ("5 min", 300.0)]
    {
      let radio = gtk_radio_menu_item_new_with_label(group, label)
      group = gtk_radio_menu_item_get_group(gtkCast(radio, to: GtkRadioMenuItem.self))
      if settingsStore.settings.refreshIntervalSeconds == seconds {
        gtk_check_menu_item_set_active(gtkCast(radio, to: GtkCheckMenuItem.self), 1)
      }
      connect(radio, signal: "toggled") { [weak self] in
        guard let self,
          gtk_check_menu_item_get_active(gtkCast(radio, to: GtkCheckMenuItem.self)) != 0
        else { return }
        self.settingsStore.update { $0.refreshIntervalSeconds = seconds }
        self.scheduleTimer()
      }
      appendItem(intervalMenu, radio)
    }
    gtk_menu_item_set_submenu(gtkCast(intervalItem, to: GtkMenuItem.self), intervalMenu)
    appendItem(menu, intervalItem)

    let notifyItem = gtk_menu_item_new_with_label("Notificar quando passar de")
    let notifyMenu = gtk_menu_new()
    let toggles: [(String, WritableKeyPath<LinuxSettings, Bool>)] = [
      ("75%", \.notifyAt75),
      ("90%", \.notifyAt90),
      ("95%", \.notifyAt95),
    ]
    for (label, keyPath) in toggles {
      let check = gtk_check_menu_item_new_with_label(label)
      gtk_check_menu_item_set_active(
        gtkCast(check, to: GtkCheckMenuItem.self),
        settingsStore.settings[keyPath: keyPath] ? 1 : 0)
      connect(check, signal: "toggled") { [weak self] in
        guard let self else { return }
        let active = gtk_check_menu_item_get_active(gtkCast(check, to: GtkCheckMenuItem.self)) != 0
        self.settingsStore.update { $0[keyPath: keyPath] = active }
      }
      appendItem(notifyMenu, check)
    }
    gtk_menu_item_set_submenu(gtkCast(notifyItem, to: GtkMenuItem.self), notifyMenu)
    appendItem(menu, notifyItem)

    let autostartItem = gtk_check_menu_item_new_with_label("Abrir no login")
    gtk_check_menu_item_set_active(
      gtkCast(autostartItem, to: GtkCheckMenuItem.self), Autostart.isEnabled ? 1 : 0)
    connect(autostartItem, signal: "toggled") {
      let active =
        gtk_check_menu_item_get_active(gtkCast(autostartItem, to: GtkCheckMenuItem.self)) != 0
      Autostart.setEnabled(active)
    }
    appendItem(menu, autostartItem)

    return menu
  }

  private func connect(
    _ widget: UnsafeMutablePointer<GtkWidget>?, signal: String, _ handler: @escaping () -> Void
  ) {
    let action = MenuAction(handler)
    actions.append(action)
    let callback: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, data in
      guard let data else { return }
      Unmanaged<MenuAction>.fromOpaque(data).takeUnretainedValue().run()
    }
    g_signal_connect_data(
      widget.map { UnsafeMutableRawPointer($0) }, signal,
      unsafeBitCast(callback, to: GCallback.self),
      Unmanaged.passUnretained(action).toOpaque(), nil, GConnectFlags(0))
  }

  private func scheduleTimer() {
    if timerID != 0 { g_source_remove(timerID) }
    let callback: GSourceFunc = { data in
      guard let data else { return 0 }
      Unmanaged<TrayApp>.fromOpaque(data).takeUnretainedValue().triggerRefresh(force: false)
      return 1
    }
    timerID = g_timeout_add_seconds(
      guint(settingsStore.settings.refreshIntervalSeconds), callback,
      Unmanaged.passUnretained(self).toOpaque())
  }

  func triggerRefresh(force: Bool) {
    Task { [weak self] in
      guard let self else { return }
      guard let result = await self.engine.refresh(force: force) else { return }
      runOnMainLoop { self.apply(result) }
    }
  }

  private func apply(_ result: UsageRefreshResult) {
    updateIndicator(result.snapshot)
    updateUsageItems(result.snapshot)
    updateStatusItem(result)
    updateAccount()
    if result.errorMessage == nil, let snapshot = result.snapshot {
      notifier.evaluate(snapshot: snapshot, thresholds: settingsStore.thresholds)
    }
  }

  private func updateIndicator(_ snapshot: UsageSnapshot?) {
    guard let snapshot else {
      app_indicator_set_icon_full(indicator, "claudegauge", "Uso do Claude")
      return
    }
    let parts = [("5h", snapshot.fiveHour), ("7d", snapshot.sevenDay)]
      .compactMap { label, window in window.map { "\(label) \(Int($0.percent.rounded()))%" } }
    app_indicator_set_label(indicator, parts.joined(separator: " · "), "5h 100% · 7d 100%")
    app_indicator_set_icon_full(
      indicator, iconName(for: snapshot.headlinePercent), "Uso do Claude")
  }

  private func iconName(for percent: Double) -> String {
    switch percent {
    case ..<60: return "claudegauge"
    case ..<90: return "claudegauge-warn"
    default: return "claudegauge-critical"
    }
  }

  private func updateUsageItems(_ snapshot: UsageSnapshot?) {
    let rows: [(String, UsageWindow?)] = [
      ("Sessão · 5h", snapshot?.fiveHour),
      ("Semanal · todos", snapshot?.sevenDay),
      ("Opus · semanal", snapshot?.opusWeekly),
      ("Sonnet · semanal", snapshot?.sonnetWeekly),
    ]
    for (index, row) in rows.enumerated() {
      let item = usageItems[index]
      guard let window = row.1 else {
        gtk_widget_set_visible(item, 0)
        continue
      }
      var label = "\(row.0) — \(Int(window.percent.rounded()))%"
      let reset = resetText(for: window.resetsAt)
      if !reset.isEmpty { label += " · \(reset)" }
      gtk_menu_item_set_label(gtkCast(item, to: GtkMenuItem.self), label)
      gtk_widget_set_visible(item, 1)
    }
  }

  private func updateStatusItem(_ result: UsageRefreshResult) {
    if let error = result.errorMessage {
      gtk_menu_item_set_label(gtkCast(statusItem, to: GtkMenuItem.self), error)
      return
    }
    guard let updated = result.snapshot?.lastUpdated else { return }
    let prefix = result.isStale ? "desatualizado" : "atualizado"
    gtk_menu_item_set_label(
      gtkCast(statusItem, to: GtkMenuItem.self),
      "\(prefix) \(Self.updatedFormatter.string(from: updated))")
  }

  private func updateAccount() {
    if let tokens = FileTokenStore().load() {
      gtk_menu_item_set_label(
        gtkCast(accountItem, to: GtkMenuItem.self),
        "Conectado via login do app (\(tokens.subscriptionType?.capitalized ?? "ativo"))")
      gtk_menu_item_set_label(gtkCast(loginItem, to: GtkMenuItem.self), "Sair da conta")
    } else if CredentialsReader().read() != nil {
      gtk_menu_item_set_label(
        gtkCast(accountItem, to: GtkMenuItem.self), "Usando o token do Claude Code")
      gtk_menu_item_set_label(gtkCast(loginItem, to: GtkMenuItem.self), "Entrar com Claude")
    } else {
      gtk_menu_item_set_label(
        gtkCast(accountItem, to: GtkMenuItem.self), "Nenhuma conta conectada")
      gtk_menu_item_set_label(gtkCast(loginItem, to: GtkMenuItem.self), "Entrar com Claude")
    }
  }

  private func handleAccountAction() {
    let tokenStore = FileTokenStore()
    if tokenStore.load() != nil {
      tokenStore.clear()
      updateAccount()
      triggerRefresh(force: true)
    } else {
      notifier.send(
        title: "ClaudeGauge",
        body: "Rode `claudegauge login` num terminal pra conectar sua conta Claude.")
    }
  }
}
