import AppKit
import DSHIslandCore
import ServiceManagement
import SwiftUI

/// Persisted user choices and their validated mutation entry points.
@MainActor
final class PreferencesStore: ObservableObject {
  private enum Key {
    static let endpoint = "endpoint"
    static let allowRemote = "allowRemoteEndpoint"
    static let privacy = "privacyMode"
    static let launchAtLogin = "launchAtLogin"
    static let islandTheme = "islandTheme"
  }

  static let defaultEndpoint = "http://127.0.0.1:3080"

  @Published private(set) var endpoint: String
  @Published private(set) var allowRemoteEndpoint: Bool
  @Published private(set) var privacyMode: Bool
  @Published private(set) var launchAtLogin: Bool
  @Published private(set) var launchAtLoginError: String?
  @Published private(set) var theme: IslandTheme

  var onConnectionChanged: (() -> Void)?
  var onPrivacyChanged: (() -> Void)?
  var onResetPosition: (() -> Void)?
  var onThemeChanged: ((IslandTheme) -> Void)?

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard, themeOverride: IslandTheme? = nil) {
    self.defaults = defaults
    endpoint = defaults.string(forKey: Key.endpoint) ?? Self.defaultEndpoint
    allowRemoteEndpoint = defaults.bool(forKey: Key.allowRemote)
    privacyMode = defaults.bool(forKey: Key.privacy)
    launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
    theme = themeOverride ?? IslandTheme.resolve(defaults.string(forKey: Key.islandTheme))

    if (try? EndpointPolicy.normalize(endpoint, allowRemote: allowRemoteEndpoint)) == nil {
      endpoint = Self.defaultEndpoint
      allowRemoteEndpoint = false
    }
  }

  /// The saved endpoint, which is always validated before persistence.
  var resolvedEndpoint: URL {
    (try? EndpointPolicy.normalize(endpoint, allowRemote: allowRemoteEndpoint))
      ?? URL(string: Self.defaultEndpoint)!
  }

  /// Validates and saves a new endpoint as one atomic preference change.
  func applyEndpoint(_ rawEndpoint: String, allowRemote: Bool) throws {
    let normalized = try EndpointPolicy.normalize(rawEndpoint, allowRemote: allowRemote)
    endpoint = normalized.absoluteString
    allowRemoteEndpoint = allowRemote
    defaults.set(endpoint, forKey: Key.endpoint)
    defaults.set(allowRemote, forKey: Key.allowRemote)
    onConnectionChanged?()
  }

  /// Enables or disables presentation-safe title and detail redaction.
  func setPrivacyMode(_ enabled: Bool) {
    guard privacyMode != enabled else { return }
    privacyMode = enabled
    defaults.set(enabled, forKey: Key.privacy)
    onPrivacyChanged?()
  }

  /// Applies a presentation theme and remembers an explicit user selection.
  func setTheme(_ newTheme: IslandTheme) {
    guard theme != newTheme else { return }
    theme = newTheme
    defaults.set(newTheme.rawValue, forKey: Key.islandTheme)
    onThemeChanged?(newTheme)
  }

  /// Registers or unregisters the bundled application with macOS login items.
  func setLaunchAtLogin(_ enabled: Bool) {
    guard launchAtLogin != enabled else { return }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      launchAtLogin = enabled
      launchAtLoginError = nil
      defaults.set(enabled, forKey: Key.launchAtLogin)
    } catch {
      launchAtLoginError = error.localizedDescription
    }
  }

  func resetPosition() {
    onResetPosition?()
  }
}

/// Settings editor that commits endpoint changes only after validation.
struct PreferencesView: View {
  @ObservedObject var preferences: PreferencesStore
  @State private var endpointDraft: String
  @State private var allowRemoteDraft: Bool
  @State private var validationMessage: String?

  init(preferences: PreferencesStore) {
    self.preferences = preferences
    _endpointDraft = State(initialValue: preferences.endpoint)
    _allowRemoteDraft = State(initialValue: preferences.allowRemoteEndpoint)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Appearance")
            .font(.headline)
          Text("Choose a visual style. Statuses, controls, and interactions stay the same.")
            .font(.caption)
            .foregroundStyle(.secondary)

          Picker(
            "Island theme",
            selection: Binding(
              get: { preferences.theme.rawValue },
              set: { preferences.setTheme(IslandTheme.resolve($0)) }
            )
          ) {
            ForEach(IslandTheme.allCases, id: \.rawValue) { theme in
              ThemeChoiceCard(theme: theme, isSelected: preferences.theme == theme)
                .tag(theme.rawValue)
            }
          }
          .pickerStyle(.radioGroup)
          .labelsHidden()
          .accessibilityLabel("Island theme")
        }

        Divider()

        VStack(alignment: .leading, spacing: 6) {
          Text("DSH endpoint")
            .font(.headline)
          HStack(spacing: 8) {
            TextField(PreferencesStore.defaultEndpoint, text: $endpointDraft)
              .textFieldStyle(.roundedBorder)
            Button("Apply") { applyEndpoint() }
              .keyboardShortcut(.defaultAction)
          }
          Toggle("Allow a non-loopback endpoint", isOn: $allowRemoteDraft)
          Text(
            "Remote DSH hosts can expose Agent capabilities. Enable this only for a host you trust."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          if let validationMessage {
            Text(validationMessage)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }

        Divider()

        Toggle(
          "Privacy mode",
          isOn: Binding(
            get: { preferences.privacyMode },
            set: { preferences.setPrivacyMode($0) }
          )
        )
        Text(
          "Replaces session titles and hides Todo text, tool names, errors, and connection details."
        )
        .font(.caption)
        .foregroundStyle(.secondary)

        Toggle(
          "Launch DSH Island at login",
          isOn: Binding(
            get: { preferences.launchAtLogin },
            set: { preferences.setLaunchAtLogin($0) }
          )
        )
        if let error = preferences.launchAtLoginError {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
        }

        HStack {
          Button("Reset island position") { preferences.resetPosition() }
          Spacer()
          Text("Read-only · no telemetry")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
      }
      .padding(24)
    }
    .frame(width: 500, height: 680)
  }

  private func applyEndpoint() {
    do {
      try preferences.applyEndpoint(endpointDraft, allowRemote: allowRemoteDraft)
      endpointDraft = preferences.endpoint
      validationMessage = nil
    } catch {
      validationMessage = error.localizedDescription
    }
  }
}

/// One native radio option with a live miniature rendered from the selected theme's tokens.
private struct ThemeChoiceCard: View {
  let theme: IslandTheme
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 12) {
      ThemeMiniPreview(theme: theme)
        .frame(width: 112, height: 36)

      VStack(alignment: .leading, spacing: 2) {
        Text(theme.displayName)
          .font(.system(size: 13, weight: .semibold))
        Text(theme.tagline)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(
          isSelected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.08),
          lineWidth: isSelected ? 1.5 : 1
        )
    )
    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(theme.displayName)
    .accessibilityHint(theme.tagline)
  }
}

/// A compact token-driven preview that updates immediately with the theme selection.
private struct ThemeMiniPreview: View {
  let theme: IslandTheme

  private var cornerRadius: CGFloat {
    let metrics = theme.metrics
    return CGFloat(metrics.collapsedCornerRadius / metrics.collapsedHeight) * 36
  }

  private var brandCornerRadius: CGFloat {
    let metrics = theme.metrics
    return CGFloat(metrics.brandCornerRadius / metrics.brandTileSize) * 22
  }

  var body: some View {
    HStack(spacing: 6) {
      ZStack {
        RoundedRectangle(cornerRadius: brandCornerRadius, style: .continuous)
          .fill(theme.palette.brandFill.swiftUIColor)
        RoundedRectangle(cornerRadius: brandCornerRadius, style: .continuous)
          .stroke(
            (theme.palette.brandStroke ?? theme.palette.completed).swiftUIColor,
            lineWidth: 1)
        WhaleShape()
          .fill(theme.palette.whaleFill.swiftUIColor)
          .padding(4)
      }
      .frame(width: 22, height: 22)

      VStack(alignment: .leading, spacing: 4) {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(theme.palette.primaryText.swiftUIColor)
          .frame(width: 42, height: 4)
        HStack(spacing: 3) {
          Capsule().fill(theme.palette.attention.swiftUIColor)
          Capsule().fill(theme.palette.running.swiftUIColor)
          Capsule().fill(theme.palette.completed.swiftUIColor)
        }
        .frame(width: 54, height: 3)
      }
    }
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [
          theme.palette.surfaceTop.swiftUIColor,
          theme.palette.surfaceBottom.swiftUIColor,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(theme.palette.border.swiftUIColor, lineWidth: 1)
    )
    .accessibilityHidden(true)
  }
}
