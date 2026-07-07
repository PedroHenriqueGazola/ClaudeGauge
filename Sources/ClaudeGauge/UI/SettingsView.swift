import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

@MainActor
struct SettingsView: View {
  let model: UsageModel

  @State private var login = LoginModel.shared
  @AppStorage("refreshIntervalSeconds") private var refreshInterval: Double = 180
  @AppStorage("notifyAt75") private var notifyAt75 = true
  @AppStorage("notifyAt90") private var notifyAt90 = true
  @AppStorage("notifyAt95") private var notifyAt95 = true
  @AppStorage("notifyOnTurnEnd") private var notifyOnTurnEnd = true
  @State private var launchAtLogin = false
  @State private var notificationsDenied = false

  private var isBundled: Bool {
    Bundle.main.bundleIdentifier != nil
  }

  var body: some View {
    @Bindable var login = login

    Form {
      if notificationsDenied {
        permissionWarningSection
      }

      Section("Conta") {
        accountSection(login)
      }

      Section("Atualização") {
        Picker("Intervalo", selection: $refreshInterval) {
          Text("1 min").tag(60.0)
          Text("2 min").tag(120.0)
          Text("3 min").tag(180.0)
          Text("5 min").tag(300.0)
        }
        .onChange(of: refreshInterval) { _, _ in model.scheduleTimer() }
      }

      Section("Notificar quando passar de") {
        Toggle("75%", isOn: $notifyAt75)
        Toggle("90%", isOn: $notifyAt90)
        Toggle("95%", isOn: $notifyAt95)
      }

      Section("Claude Code") {
        Toggle("Avisar quando terminar de responder", isOn: $notifyOnTurnEnd)
          .disabled(!isBundled)
      }

      Section("Sistema") {
        Toggle("Abrir no login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
          .disabled(!isBundled)
        if !isBundled {
          Text("Disponível ao rodar o ClaudeGauge.app (via scripts/make-app.sh).")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 380, height: 460)
    .onAppear {
      launchAtLogin = SMAppService.mainApp.status == .enabled
      refreshNotificationStatus()
    }
  }

  @ViewBuilder
  private var permissionWarningSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        Text("Notificações desativadas").font(.callout).bold()
        Text("O macOS está bloqueando as notificações do ClaudeGauge. Ative para receber os avisos de uso e de fim de resposta.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("Abrir Ajustes de Notificação") { openNotificationSettings() }
      }
    }
  }

  private func openNotificationSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    else { return }
    NSWorkspace.shared.open(url)
  }

  private func refreshNotificationStatus() {
    guard isBundled else { return }
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let denied = settings.authorizationStatus == .denied
      Task { @MainActor in notificationsDenied = denied }
    }
  }

  @ViewBuilder
  private func accountSection(_ login: LoginModel) -> some View {
    if login.isLoggedIn {
      loggedInView(login)
    } else {
      loggedOutView(login)
    }
  }

  @ViewBuilder
  private func loggedInView(_ login: LoginModel) -> some View {
    LabeledContent("Conectado via login do app") {
      Text(login.accountPlan?.capitalized ?? "ativo")
        .foregroundStyle(.secondary)
    }
    Button("Sair da conta", role: .destructive) { login.logout() }
  }

  @ViewBuilder
  private func loggedOutView(_ login: LoginModel) -> some View {
    switch login.phase {
    case .idle, .failed:
      Text("Sem login próprio: usando o Claude Code, se disponível. Para conectar outra conta:")
        .font(.caption)
        .foregroundStyle(.secondary)
      Button("Entrar com Claude") { login.startLogin() }
      if case .failed(let message) = login.phase {
        Text(message).font(.caption).foregroundStyle(.red)
      }
    case .awaitingCode:
      awaitingCodeView(login)
    case .exchanging:
      HStack(spacing: 8) {
        ProgressView().controlSize(.small)
        Text("Conectando...").font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private func awaitingCodeView(_ login: LoginModel) -> some View {
    @Bindable var login = login
    Text("Abri o navegador. Autorize, copie o código exibido e cole abaixo:")
      .font(.caption)
      .foregroundStyle(.secondary)
    TextField("cole o código aqui", text: $login.pastedCode)
      .textFieldStyle(.roundedBorder)
    HStack {
      Button("Concluir") { Task { await login.submitCode() } }
        .disabled(login.pastedCode.isEmpty)
      Button("Cancelar") { login.cancel() }
        .buttonStyle(.borderless)
    }
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      launchAtLogin = SMAppService.mainApp.status == .enabled
    }
  }
}
