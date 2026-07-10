import ClaudeGaugeCore
import Foundation
import WinSDK

final class TrayApp {
  private let engine = UsageEngine(tokenStore: FileTokenStore())
  private let settingsStore = SettingsStore()
  private var notifier: NotificationService?

  private var hwnd: HWND?
  private var lastResult: UsageRefreshResult?
  private var iconCache: [String: HICON] = [:]

  // O Explorer descarta os ícones da bandeja quando reinicia; TaskbarCreated
  // é o broadcast pra re-registrar.
  private let taskbarCreatedMessage = wide("TaskbarCreated").withUnsafeBufferPointer {
    RegisterWindowMessageW($0.baseAddress)
  }

  private static let updatedFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
  }()

  private enum MenuID: UInt32 {
    case refresh = 1
    case account = 2
    case quit = 3
    case interval1 = 11
    case interval2 = 12
    case interval3 = 13
    case interval5 = 14
    case notify75 = 21
    case notify90 = 22
    case notify95 = 23
    case autostart = 31
  }

  func start() {
    hwnd = createMainWindow(for: self)
    notifier = NotificationService(hwnd: hwnd)
    addTrayIcon()
    scheduleTimer()
    triggerRefresh(force: false)
  }

  func handle(_ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT? {
    switch message {
    case WM_APP_TRAY:
      let event = UINT(lParam & 0xFFFF)
      if event == UINT(WM_LBUTTONUP) || event == UINT(WM_RBUTTONUP) { showMenu() }
      return 0
    case UINT(WM_TIMER):
      triggerRefresh(force: false)
      return 0
    case UINT(WM_COMMAND):
      // TrackPopupMenu roda sem TPM_RETURNCMD (ver showMenu) porque este SDK importa BOOL
      // como Bool, o que colapsaria o id retornado por TPM_RETURNCMD em true/false — o menu
      // então usa o comportamento padrão do Win32 de postar WM_COMMAND na janela dona.
      handleCommand(UInt32(wParam & 0xFFFF))
      return 0
    case UINT(WM_DESTROY):
      PostQuitMessage(0)
      return 0
    default:
      // TaskbarCreated é um id de mensagem obtido em runtime (RegisterWindowMessageW),
      // não uma constante — não dá pra usar como case do switch.
      if message == taskbarCreatedMessage {
        addTrayIcon()
        updateTrayIcon(lastResult?.snapshot)
        return 0
      }
      return nil
    }
  }

  // MARK: - Ícone da bandeja

  private func addTrayIcon() {
    var data = makeIconData(hwnd)
    data.uFlags = UINT(NIF_MESSAGE | NIF_ICON | NIF_TIP)
    data.uCallbackMessage = WM_APP_TRAY
    data.hIcon = icon(named: "claudegauge")
    assign("ClaudeGauge", to: &data.szTip)
    _ = Shell_NotifyIconW(DWORD(NIM_ADD), &data)
  }

  private func removeTrayIcon() {
    var data = makeIconData(hwnd)
    _ = Shell_NotifyIconW(DWORD(NIM_DELETE), &data)
  }

  // A bandeja do Windows não tem label de texto como o AppIndicator —
  // o "5h X% · 7d Y%" vai no tooltip do ícone.
  private func updateTrayIcon(_ snapshot: UsageSnapshot?) {
    var data = makeIconData(hwnd)
    data.uFlags = UINT(NIF_ICON | NIF_TIP)
    guard let snapshot else {
      data.hIcon = icon(named: "claudegauge")
      assign("ClaudeGauge", to: &data.szTip)
      _ = Shell_NotifyIconW(DWORD(NIM_MODIFY), &data)
      return
    }
    let parts = [("5h", snapshot.fiveHour), ("7d", snapshot.sevenDay)]
      .compactMap { label, window in window.map { "\(label) \(Int($0.percent.rounded()))%" } }
    data.hIcon = icon(named: iconName(for: snapshot.headlinePercent))
    assign("ClaudeGauge — \(parts.joined(separator: " · "))", to: &data.szTip)
    _ = Shell_NotifyIconW(DWORD(NIM_MODIFY), &data)
  }

  private func iconName(for percent: Double) -> String {
    switch percent {
    case ..<60: return "claudegauge"
    case ..<90: return "claudegauge-warn"
    default: return "claudegauge-critical"
    }
  }

  private func icon(named name: String) -> HICON? {
    if let cached = iconCache[name] { return cached }
    let loaded = iconDirectory().flatMap { directory -> HICON? in
      let path = directory.appendingPathComponent("\(name).ico").path
      guard FileManager.default.fileExists(atPath: path) else { return nil }
      return wide(path).withUnsafeBufferPointer {
        LoadImageW(nil, $0.baseAddress, UINT(IMAGE_ICON), 0, 0, UINT(LR_LOADFROMFILE | LR_DEFAULTSIZE))
          .map { $0.assumingMemoryBound(to: HICON__.self) }
      }
    }
    let result = loaded ?? LoadIconW(nil, UnsafePointer<WCHAR>(bitPattern: 32512))  // IDI_APPLICATION
    iconCache[name] = result
    return result
  }

  private func iconDirectory() -> URL? {
    let fileManager = FileManager.default
    var candidates = [AppPaths.appData.appendingPathComponent("icons")]
    let executable = URL(fileURLWithPath: Autostart.executablePath())
    let buildDirectory = executable.deletingLastPathComponent()
    candidates.append(
      buildDirectory.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/windows"))
    candidates.append(
      buildDirectory.deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Resources/windows"))
    return candidates.first { fileManager.fileExists(atPath: $0.path) }
  }

  // MARK: - Menu (reconstruído a cada exibição — o popup Win32 é modal e efêmero)

  private func showMenu() {
    guard let menu = CreatePopupMenu() else { return }
    defer { DestroyMenu(menu) }
    populate(menu)

    // Sem SetForegroundWindow o menu não fecha ao clicar fora (comportamento clássico do Win32).
    _ = SetForegroundWindow(hwnd)
    var point = POINT()
    _ = GetCursorPos(&point)
    // Sem TPM_RETURNCMD/TPM_NONOTIFY: este SDK importa o retorno BOOL do TrackPopupMenu como
    // Bool, então o id do item selecionado (o que TPM_RETURNCMD devolveria) não é recuperável
    // do retorno. Em vez disso deixamos o comportamento padrão do Win32 postar WM_COMMAND pra
    // hwnd, tratado em handle(_:_:_:).
    _ = TrackPopupMenu(
      menu, UINT(TPM_RIGHTBUTTON | TPM_BOTTOMALIGN),
      point.x, point.y, 0, hwnd, nil)
    _ = PostMessageW(hwnd, UINT(WM_NULL), 0, 0)
  }

  private func populate(_ menu: HMENU) {
    // Título em negrito: item 0, id 0 (WM_COMMAND com id 0 não é mapeado por
    // MenuID, então o clique é inofensivo).
    appendData(menu, "ClaudeGauge")
    _ = SetMenuDefaultItem(menu, 0, 0)
    appendSeparator(menu)

    let snapshot = lastResult?.snapshot
    let rows: [(String, UsageWindow?)] = [
      ("Sessão 5h", snapshot?.fiveHour),
      ("Semanal", snapshot?.sevenDay),
      ("Opus", snapshot?.opusWeekly),
      ("Sonnet", snapshot?.sonnetWeekly),
    ]
    var hasRows = false
    for row in rows {
      guard let window = row.1 else { continue }
      hasRows = true
      var name = row.0
      let reset = resetText(for: window.resetsAt)
      if !reset.isEmpty { name += " · \(reset)" }
      let filled = min(8, max(0, Int((window.percent / 12.5).rounded())))
      let bar = String(repeating: "▰", count: filled) + String(repeating: "▱", count: 8 - filled)
      appendData(menu, "\(name)\t\(bar)  \(Int(window.percent.rounded()))%")
    }
    if !hasRows { appendData(menu, "—") }
    if let error = lastResult?.errorMessage { appendData(menu, error) }

    appendSeparator(menu)
    // O erro (se houver) já apareceu no bloco de uso acima; aqui só o horário.
    if lastResult?.errorMessage != nil {
      if let updated = lastResult?.snapshot?.lastUpdated {
        appendInfo(menu, "atualizado \(Self.updatedFormatter.string(from: updated))")
      }
    } else {
      appendInfo(menu, statusText())
    }
    appendCommand(menu, "Atualizar agora", id: MenuID.refresh.rawValue)
    appendSubmenu(menu, "Conta", buildAccountMenu())
    appendSubmenu(menu, "Configurações", buildSettingsMenu())
    appendSeparator(menu)
    appendCommand(menu, "Sair", id: MenuID.quit.rawValue)
  }

  private func buildAccountMenu() -> HMENU? {
    let menu = CreatePopupMenu()
    appendInfo(menu, accountText())
    appendSeparator(menu)
    appendCommand(menu, accountActionText(), id: MenuID.account.rawValue)
    return menu
  }

  private func buildSettingsMenu() -> HMENU? {
    let menu = CreatePopupMenu()

    let intervalMenu = CreatePopupMenu()
    let intervals: [(String, Double, MenuID)] = [
      ("1 min", 60, .interval1),
      ("2 min", 120, .interval2),
      ("3 min", 180, .interval3),
      ("5 min", 300, .interval5),
    ]
    var selected = MenuID.interval3
    for (label, seconds, id) in intervals {
      appendCommand(intervalMenu, label, id: id.rawValue)
      if settingsStore.settings.refreshIntervalSeconds == seconds { selected = id }
    }
    _ = CheckMenuRadioItem(
      intervalMenu, MenuID.interval1.rawValue, MenuID.interval5.rawValue,
      selected.rawValue, UINT(MF_BYCOMMAND))
    appendSubmenu(menu, "Intervalo", intervalMenu)

    let notifyMenu = CreatePopupMenu()
    appendCheck(
      notifyMenu, "75%", id: MenuID.notify75.rawValue, checked: settingsStore.settings.notifyAt75)
    appendCheck(
      notifyMenu, "90%", id: MenuID.notify90.rawValue, checked: settingsStore.settings.notifyAt90)
    appendCheck(
      notifyMenu, "95%", id: MenuID.notify95.rawValue, checked: settingsStore.settings.notifyAt95)
    appendSubmenu(menu, "Notificar quando passar de", notifyMenu)

    appendCheck(menu, "Abrir no login", id: MenuID.autostart.rawValue, checked: Autostart.isEnabled)
    return menu
  }

  private func handleCommand(_ command: UInt32) {
    guard let id = MenuID(rawValue: command) else { return }
    switch id {
    case .refresh:
      triggerRefresh(force: true)
    case .account:
      handleAccountAction()
    case .quit:
      removeTrayIcon()
      PostQuitMessage(0)
    case .interval1: setInterval(60)
    case .interval2: setInterval(120)
    case .interval3: setInterval(180)
    case .interval5: setInterval(300)
    case .notify75: settingsStore.update { $0.notifyAt75.toggle() }
    case .notify90: settingsStore.update { $0.notifyAt90.toggle() }
    case .notify95: settingsStore.update { $0.notifyAt95.toggle() }
    case .autostart: Autostart.setEnabled(!Autostart.isEnabled)
    }
  }

  private func setInterval(_ seconds: Double) {
    settingsStore.update { $0.refreshIntervalSeconds = seconds }
    scheduleTimer()
  }

  // MARK: - Refresh

  private func scheduleTimer() {
    // SetTimer com o mesmo id substitui o timer anterior.
    _ = SetTimer(hwnd, 1, UINT(settingsStore.settings.refreshIntervalSeconds * 1000), nil)
  }

  func triggerRefresh(force: Bool) {
    Task { [weak self] in
      guard let self else { return }
      guard let result = await self.engine.refresh(force: force) else { return }
      runOnMainLoop(self.hwnd) { self.apply(result) }
    }
  }

  private func apply(_ result: UsageRefreshResult) {
    lastResult = result
    updateTrayIcon(result.snapshot)
    if result.errorMessage == nil, let snapshot = result.snapshot {
      notifier?.evaluate(snapshot: snapshot, thresholds: settingsStore.thresholds)
    }
  }

  // MARK: - Conta

  private func statusText() -> String {
    if let error = lastResult?.errorMessage { return error }
    guard let updated = lastResult?.snapshot?.lastUpdated else { return "carregando…" }
    let prefix = (lastResult?.isStale ?? false) ? "desatualizado" : "atualizado"
    return "\(prefix) \(Self.updatedFormatter.string(from: updated))"
  }

  private func accountText() -> String {
    if let tokens = FileTokenStore().load() {
      return "Conectado via login do app (\(tokens.subscriptionType?.capitalized ?? "ativo"))"
    }
    if CredentialsReader().read() != nil { return "Usando o token do Claude Code" }
    return "Nenhuma conta conectada"
  }

  private func accountActionText() -> String {
    FileTokenStore().load() != nil ? "Sair da conta" : "Entrar com Claude"
  }

  private func handleAccountAction() {
    let tokenStore = FileTokenStore()
    if tokenStore.load() != nil {
      tokenStore.clear()
      triggerRefresh(force: true)
    } else {
      notifier?.send(
        title: "ClaudeGauge",
        body: "Rode `claudegauge login` num terminal pra conectar sua conta Claude.")
    }
  }
}
