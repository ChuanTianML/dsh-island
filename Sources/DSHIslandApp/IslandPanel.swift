import AppKit
import DSHIslandCore
import QuartzCore
import SwiftUI

/// A borderless floating panel that can still accept keyboard focus after expansion.
private final class IslandPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

/// Owns panel sizing, all-Spaces behavior, and display-relative position persistence.
@MainActor
final class IslandPanelController: NSObject, NSWindowDelegate {
  private enum PositionKey {
    static let screen = "islandPosition.screen"
    static let centerX = "islandPosition.centerX"
    static let topY = "islandPosition.topY"
    static let saved = "islandPosition.saved"
  }

  private let model: IslandViewModel
  private let defaults: UserDefaults
  private let panel: IslandPanel
  private var theme: IslandTheme
  private var suppressPositionSave = false
  private var resizeGeneration = 0

  init(
    model: IslandViewModel,
    preferences: PreferencesStore,
    defaults: UserDefaults = .standard,
    openSettings: @escaping () -> Void
  ) {
    self.model = model
    self.defaults = defaults
    theme = preferences.theme
    let metrics = preferences.theme.metrics
    let initialSize = NSSize(width: metrics.collapsedWidth, height: metrics.collapsedHeight)
    panel = IslandPanel(
      contentRect: NSRect(origin: .zero, size: initialSize),
      styleMask: [.borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    super.init()

    panel.delegate = self
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = true
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .utilityWindow
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .ignoresCycle,
      .stationary,
    ]
    let hostingController = NSHostingController(
      rootView: IslandView(
        model: model,
        preferences: preferences,
        openSettings: openSettings
      )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    )
    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    hostingController.view.layer?.isOpaque = false
    hostingController.view.layer?.cornerCurve = .continuous
    hostingController.view.layer?.cornerRadius = metrics.collapsedCornerRadius
    hostingController.view.layer?.masksToBounds = true
    panel.contentViewController = hostingController
    restorePosition()
  }

  var isVisible: Bool { panel.isVisible }

  func show() {
    panel.orderFrontRegardless()
  }

  func hide() {
    panel.orderOut(nil)
  }

  func toggleVisibility() {
    isVisible ? hide() : show()
  }

  /// Resizes around a fixed top-center anchor so expansion unfolds downward.
  func setExpanded(_ expanded: Bool, animated: Bool = true) {
    let targetSize = expanded ? expandedSize : collapsedSize
    resize(to: targetSize, expanded: expanded, animated: animated)
  }

  /// Applies presentation metrics without changing expansion state or persisted position.
  func setTheme(_ newTheme: IslandTheme, animated: Bool = true) {
    guard theme != newTheme else { return }
    theme = newTheme
    let expanded = model.isExpanded
    resize(
      to: expanded ? expandedSize : collapsedSize,
      expanded: expanded,
      animated: animated
    )
  }

  private func resize(to targetSize: NSSize, expanded: Bool, animated: Bool) {
    let metrics = theme.metrics
    panel.contentViewController?.view.layer?.cornerRadius =
      expanded ? metrics.expandedCornerRadius : metrics.collapsedCornerRadius
    let oldFrame = panel.frame
    if abs(oldFrame.width - targetSize.width) < 0.5,
      abs(oldFrame.height - targetSize.height) < 0.5
    {
      return
    }
    resizeGeneration &+= 1
    let activeResizeGeneration = resizeGeneration
    var targetFrame = NSRect(
      x: oldFrame.midX - targetSize.width / 2,
      y: oldFrame.maxY - targetSize.height,
      width: targetSize.width,
      height: targetSize.height
    )
    targetFrame = clamped(targetFrame, to: panel.screen ?? preferredScreen())
    suppressPositionSave = true
    let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    if shouldAnimate {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.24
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        panel.animator().setFrame(targetFrame, display: true)
      } completionHandler: { [weak self] in
        Task { @MainActor in
          guard let self, self.resizeGeneration == activeResizeGeneration else { return }
          self.suppressPositionSave = false
        }
      }
    } else {
      panel.setFrame(targetFrame, display: true)
      if resizeGeneration == activeResizeGeneration {
        suppressPositionSave = false
      }
    }
  }

  func refreshExpandedSize() {
    guard model.isExpanded else { return }
    setExpanded(true, animated: false)
  }

  func resetPosition() {
    defaults.removeObject(forKey: PositionKey.screen)
    defaults.removeObject(forKey: PositionKey.centerX)
    defaults.removeObject(forKey: PositionKey.topY)
    defaults.set(false, forKey: PositionKey.saved)
    suppressPositionSave = true
    let size = model.isExpanded ? expandedSize : collapsedSize
    panel.setFrame(defaultFrame(on: preferredScreen(), size: size), display: true)
    suppressPositionSave = false
    show()
  }

  func windowDidMove(_ notification: Notification) {
    guard !suppressPositionSave else { return }
    savePosition()
  }

  func windowDidChangeScreen(_ notification: Notification) {
    guard !suppressPositionSave else { return }
    savePosition()
  }

  private var collapsedSize: NSSize {
    let metrics = theme.metrics
    return NSSize(width: metrics.collapsedWidth, height: metrics.collapsedHeight)
  }

  private var expandedSize: NSSize {
    let metrics = theme.metrics
    let height = metrics.expandedHeight(visibleRowCount: model.snapshot.sessions.count)
    return NSSize(width: metrics.expandedWidth, height: height)
  }

  private func restorePosition() {
    let screen = preferredScreen(savedIdentifier: defaults.string(forKey: PositionKey.screen))
    guard defaults.bool(forKey: PositionKey.saved) else {
      panel.setFrame(defaultFrame(on: screen, size: collapsedSize), display: false)
      return
    }
    let visible = screen.visibleFrame
    let centerFraction = defaults.double(forKey: PositionKey.centerX)
    let topFraction = defaults.double(forKey: PositionKey.topY)
    let centerX = visible.minX + visible.width * centerFraction
    let topY = visible.minY + visible.height * topFraction
    let frame = NSRect(
      x: centerX - collapsedSize.width / 2,
      y: topY - collapsedSize.height,
      width: collapsedSize.width,
      height: collapsedSize.height
    )
    panel.setFrame(clamped(frame, to: screen), display: false)
  }

  private func savePosition() {
    let screen = panel.screen ?? preferredScreen()
    let visible = screen.visibleFrame
    guard visible.width > 0, visible.height > 0 else { return }
    let centerFraction = (panel.frame.midX - visible.minX) / visible.width
    let topFraction = (panel.frame.maxY - visible.minY) / visible.height
    defaults.set(screenIdentifier(screen), forKey: PositionKey.screen)
    defaults.set(centerFraction, forKey: PositionKey.centerX)
    defaults.set(topFraction, forKey: PositionKey.topY)
    defaults.set(true, forKey: PositionKey.saved)
  }

  private func defaultFrame(on screen: NSScreen, size: NSSize) -> NSRect {
    let visible = screen.visibleFrame
    return NSRect(
      x: visible.midX - size.width / 2,
      y: visible.maxY - size.height - 12,
      width: size.width,
      height: size.height
    )
  }

  private func clamped(_ frame: NSRect, to screen: NSScreen) -> NSRect {
    let visible = screen.visibleFrame.insetBy(dx: 8, dy: 8)
    var result = frame
    result.origin.x = min(
      max(result.origin.x, visible.minX), max(visible.minX, visible.maxX - result.width))
    result.origin.y = min(
      max(result.origin.y, visible.minY), max(visible.minY, visible.maxY - result.height))
    return result
  }

  private func preferredScreen(savedIdentifier: String? = nil) -> NSScreen {
    if let savedIdentifier,
      let match = NSScreen.screens.first(where: { screenIdentifier($0) == savedIdentifier })
    {
      return match
    }
    return NSScreen.main ?? NSScreen.screens.first!
  }

  private func screenIdentifier(_ screen: NSScreen) -> String {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    return (screen.deviceDescription[key] as? NSNumber)?.stringValue ?? screen.localizedName
  }
}
