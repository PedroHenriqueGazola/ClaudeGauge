import AppKit
import Carbon
import ClaudeGaugeCore
import SwiftUI

@main
struct ClaudeGaugeApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = UsageModel.shared
  private var statusItem: NSStatusItem!
  private let popover = NSPopover()
  private var settingsWindow: NSWindow?
  private var appearanceObservation: NSKeyValueObservation?
  private var lastRenderKey: String?

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleGetURLEvent(_:withReply:)),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL))
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    setupPopover()
    setupStatusItem()
    model.start()
    observeSnapshot()
  }

  @objc private func handleGetURLEvent(
    _ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor
  ) {
    let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue
    logHookDebug("received url=\(string ?? "nil")")
    guard let string, let url = URL(string: string),
      let hookEvent = ClaudeHookURL.parse(url)
    else { return }
    model.notifyClaudeHook(hookEvent)
  }

  private func logHookDebug(_ message: String) {
    guard ProcessInfo.processInfo.environment["CLAUDEGAUGE_DEBUG"] != nil else { return }
    FileHandle.standardError.write(Data(("[ClaudeGauge hook] " + message + "\n").utf8))
  }

  private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    guard let button = statusItem.button else { return }
    button.target = self
    button.action = #selector(togglePopover)
    appearanceObservation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
      guard let self else { return }
      Task { @MainActor in self.updateStatusImage() }
    }
    updateStatusImage()
  }

  private func setupPopover() {
    popover.behavior = .transient
    popover.animates = true
    popover.contentViewController = NSHostingController(
      rootView: PopoverView(model: model, onOpenSettings: { [weak self] in self?.openSettings() }))
  }

  @objc private func togglePopover() {
    guard let button = statusItem.button else { return }
    if popover.isShown {
      popover.performClose(nil)
      return
    }
    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
  }

  private func openSettings() {
    popover.performClose(nil)
    if settingsWindow == nil {
      let hosting = NSHostingController(rootView: SettingsView(model: model))
      let window = NSWindow(contentViewController: hosting)
      window.title = "ClaudeGauge"
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      window.center()
      settingsWindow = window
    }
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow?.makeKeyAndOrderFront(nil)
  }

  private func observeSnapshot() {
    withObservationTracking {
      _ = model.snapshot
    } onChange: { [weak self] in
      guard let self else { return }
      Task { @MainActor in
        self.updateStatusImage()
        self.observeSnapshot()
      }
    }
  }

  private func updateStatusImage() {
    guard let button = statusItem.button else { return }
    let dark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

    // Setar `button.image` re-dispara o observer de effectiveAppearance, então
    // só redesenhar quando o conteúdo mudou de fato evita um loop de CPU.
    let key = renderKey(dark: dark)
    guard key != lastRenderKey else { return }
    lastRenderKey = key

    if let snapshot = model.snapshot, let image = MenuBarImageRenderer.image(for: snapshot, dark: dark) {
      button.image = image
      button.imagePosition = .imageOnly
    } else {
      let fallback = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Uso do Claude")
      fallback?.isTemplate = true
      button.image = fallback
    }
  }

  private func renderKey(dark: Bool) -> String {
    guard let snapshot = model.snapshot else { return "none:\(dark)" }
    func percent(_ window: UsageWindow?) -> String {
      window.map { "\(Int($0.percent.rounded()))" } ?? "-"
    }
    let resetMinutes = snapshot.fiveHour?.resetsAt.map { Int($0.timeIntervalSinceNow / 60) } ?? -1
    return "\(percent(snapshot.fiveHour)):\(percent(snapshot.sevenDay)):\(resetMinutes):\(dark)"
  }
}
