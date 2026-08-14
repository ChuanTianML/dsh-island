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
  }

  static let defaultEndpoint = "http://127.0.0.1:3080"

  @Published private(set) var endpoint: String
  @Published private(set) var allowRemoteEndpoint: Bool
  @Published private(set) var privacyMode: Bool
  @Published private(set) var launchAtLogin: Bool
  @Published private(set) var launchAtLoginError: String?

  var onConnectionChanged: (() -> Void)?
  var onPrivacyChanged: (() -> Void)?
  var onResetPosition: (() -> Void)?

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    endpoint = defaults.string(forKey: Key.endpoint) ?? Self.defaultEndpoint
    allowRemoteEndpoint = defaults.bool(forKey: Key.allowRemote)
    privacyMode = defaults.bool(forKey: Key.privacy)
    launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)

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
    VStack(alignment: .leading, spacing: 20) {
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
    .frame(width: 500)
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
