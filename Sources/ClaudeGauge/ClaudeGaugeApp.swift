import AppKit
import SwiftUI

@main
struct ClaudeGaugeApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView(model: UsageModel.shared)
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = UsageModel.shared
  private var statusItem: NSStatusItem!
  private let popover = NSPopover()
  private var appearanceObservation: NSKeyValueObservation?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    setupPopover()
    setupStatusItem()
    model.start()
    observeSnapshot()
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
    NSApp.activate(ignoringOtherApps: true)
    if #available(macOS 14, *) {
      NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
      NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
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
    if let snapshot = model.snapshot, let image = MenuBarImageRenderer.image(for: snapshot, dark: dark) {
      button.image = image
      button.imagePosition = .imageOnly
    } else {
      let fallback = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Uso do Claude")
      fallback?.isTemplate = true
      button.image = fallback
    }
  }
}
