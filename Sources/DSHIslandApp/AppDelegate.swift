import AppKit
import Combine
import DSHIslandCore
import SwiftUI

@main
enum DSHIslandApplication {
  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
    withExtendedLifetime(delegate) {}
  }
}

/// Accessory-app lifecycle, menu-bar recovery surface, and window ownership.
@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
  private var preferences: PreferencesStore!
  private var model: IslandViewModel!
  private var panelController: IslandPanelController!
  private var settingsWindow: NSWindow?
  private var statusItem: NSStatusItem!
  private var showItem: NSMenuItem!
  private var privacyItem: NSMenuItem!
  private var statusSummaryItem: NSMenuItem!
  private var cancellables: Set<AnyCancellable> = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    let arguments = Set(CommandLine.arguments.dropFirst())
    let demoWorking = arguments.contains("--demo-working")
    let demoMode =
      arguments.contains("--demo") || arguments.contains("--demo-expanded") || demoWorking
    let startExpanded = arguments.contains("--demo-expanded")

    preferences = PreferencesStore()
    model = IslandViewModel(
      preferences: preferences,
      demoMode: demoMode,
      demoWorking: demoWorking,
      startExpanded: startExpanded
    )
    panelController = IslandPanelController(
      model: model,
      openSettings: { [weak self] in self?.showPreferences() }
    )
    model.onExpansionChanged = { [weak self] expanded in
      self?.panelController.setExpanded(expanded)
    }
    preferences.onConnectionChanged = { [weak self] in self?.model.reconnect() }
    preferences.onPrivacyChanged = { [weak self] in self?.model.applyPrivacyPreference() }
    preferences.onResetPosition = { [weak self] in self?.panelController.resetPosition() }

    installStatusItem()
    observeState()
    if startExpanded {
      panelController.setExpanded(true, animated: false)
    }
    panelController.show()
    model.start()
    signalReadyIfRequested()
  }

  func applicationWillTerminate(_ notification: Notification) {
    cancellables.removeAll()
  }

  @objc private func togglePanel() {
    panelController.toggleVisibility()
    updateMenuVisibilityTitle()
  }

  @objc private func reconnect() {
    model.reconnect()
  }

  @objc private func openDSH() {
    model.openDSH()
  }

  @objc private func togglePrivacy() {
    preferences.setPrivacyMode(!preferences.privacyMode)
  }

  @objc private func showPreferences() {
    if settingsWindow == nil {
      let controller = NSHostingController(rootView: PreferencesView(preferences: preferences))
      let window = NSWindow(contentViewController: controller)
      window.title = "DSH Island Settings"
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      window.center()
      settingsWindow = window
    }
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func installStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem.button {
      let image = NSImage(
        systemSymbolName: "waveform.path.ecg", accessibilityDescription: "DSH Island")
      image?.isTemplate = true
      button.image = image
    }

    let menu = NSMenu()
    statusSummaryItem = NSMenuItem(title: "DSH Island is starting", action: nil, keyEquivalent: "")
    statusSummaryItem.isEnabled = false
    menu.addItem(statusSummaryItem)
    menu.addItem(.separator())

    showItem = NSMenuItem(title: "Hide Island", action: #selector(togglePanel), keyEquivalent: "i")
    showItem.target = self
    menu.addItem(showItem)

    let openItem = NSMenuItem(title: "Open DSH", action: #selector(openDSH), keyEquivalent: "o")
    openItem.target = self
    menu.addItem(openItem)

    let refreshItem = NSMenuItem(
      title: "Reconnect", action: #selector(reconnect), keyEquivalent: "r")
    refreshItem.target = self
    menu.addItem(refreshItem)

    privacyItem = NSMenuItem(
      title: "Privacy Mode", action: #selector(togglePrivacy), keyEquivalent: "")
    privacyItem.target = self
    menu.addItem(privacyItem)

    menu.addItem(.separator())
    let settingsItem = NSMenuItem(
      title: "Settings…", action: #selector(showPreferences), keyEquivalent: ",")
    settingsItem.target = self
    menu.addItem(settingsItem)

    let quitItem = NSMenuItem(title: "Quit DSH Island", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
    statusItem.menu = menu
  }

  private func observeState() {
    model.$snapshot
      .sink { [weak self] snapshot in self?.updateStatusSummary(snapshot) }
      .store(in: &cancellables)
    preferences.$privacyMode
      .sink { [weak self] enabled in
        self?.privacyItem?.state = enabled ? .on : .off
      }
      .store(in: &cancellables)
  }

  private func updateStatusSummary(_ snapshot: IslandSnapshot) {
    panelController?.refreshExpandedSize()
    let title: String
    switch snapshot.aggregateStatus {
    case .attention:
      title = "\(snapshot.counts.attention) need attention"
    case .failure:
      title = "\(snapshot.counts.failure) failed"
    case .running:
      title = "\(snapshot.counts.running) working"
    case .completed:
      title = "\(snapshot.counts.completed) recently completed"
    case .idle:
      title = "DSH is idle"
    case .offline:
      title = "DSH is offline"
    }
    statusSummaryItem?.title = title
    statusItem.button?.toolTip = "DSH Island — \(title)"
    updateMenuVisibilityTitle()
  }

  private func updateMenuVisibilityTitle() {
    showItem?.title = panelController?.isVisible == true ? "Hide Island" : "Show Island"
  }

  private func signalReadyIfRequested() {
    let arguments = CommandLine.arguments
    guard let flag = arguments.firstIndex(of: "--ready-file"),
      arguments.indices.contains(flag + 1)
    else { return }
    let path = arguments[flag + 1]
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      try? Data("ready\n".utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
  }
}
