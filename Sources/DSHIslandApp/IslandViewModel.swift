import AppKit
import DSHIslandCore
import Foundation
import SwiftUI

/// Main-actor connection lifecycle and presentation state for the island.
@MainActor
final class IslandViewModel: ObservableObject {
  @Published private(set) var snapshot: IslandSnapshot = .starting
  @Published var isExpanded: Bool {
    didSet {
      guard oldValue != isExpanded else { return }
      onExpansionChanged?(isExpanded)
    }
  }

  var onExpansionChanged: ((Bool) -> Void)?

  private let preferences: PreferencesStore
  private let demoMode: Bool
  private let demoWorking: Bool
  private var engine: StatusEngine
  private var client: DSHClient?
  private var generation = UUID()
  private var baselineTask: Task<Void, Never>?
  private var hostTask: Task<Void, Never>?
  private var muxTask: Task<Void, Never>?
  private var baselineInFlight = false

  init(
    preferences: PreferencesStore,
    demoMode: Bool,
    demoWorking: Bool,
    startExpanded: Bool
  ) {
    self.preferences = preferences
    self.demoMode = demoMode
    self.demoWorking = demoWorking
    isExpanded = startExpanded
    engine = StatusEngine(privacyMode: preferences.privacyMode)
    if demoMode {
      installDemoState()
    }
  }

  deinit {
    baselineTask?.cancel()
    hostTask?.cancel()
    muxTask?.cancel()
  }

  /// Begins the polling and two independent event loops.
  func start() {
    guard !demoMode else { return }
    reconnect()
  }

  /// Replaces the connection generation and immediately fetches a new baseline.
  func reconnect() {
    guard !demoMode else {
      installDemoState()
      return
    }
    stopConnection()
    generation = UUID()
    let activeGeneration = generation
    engine = StatusEngine(privacyMode: preferences.privacyMode)
    snapshot = .starting
    let newClient = DSHClient(baseURL: preferences.resolvedEndpoint)
    client = newClient

    baselineTask = Task { [weak self] in
      await self?.runBaselineLoop(client: newClient, generation: activeGeneration)
    }
    hostTask = Task { [weak self] in
      await self?.runStreamLoop(kind: .host, client: newClient, generation: activeGeneration)
    }
    muxTask = Task { [weak self] in
      await self?.runStreamLoop(kind: .mux, client: newClient, generation: activeGeneration)
    }
  }

  /// Applies privacy changes without dropping the current live baseline.
  func applyPrivacyPreference() {
    engine.privacyMode = preferences.privacyMode
    publishSnapshot()
  }

  /// Requests a baseline outside the normal polling interval.
  func refreshNow() {
    guard !demoMode, let client else {
      installDemoState()
      return
    }
    let activeGeneration = generation
    Task { [weak self] in
      await self?.fetchBaseline(client: client, generation: activeGeneration)
    }
  }

  /// Opens DSH, optionally handing a session id to the community deep-link plugin.
  func openDSH(sessionID: String? = nil) {
    var components = URLComponents(
      url: preferences.resolvedEndpoint,
      resolvingAgainstBaseURL: false
    )
    if let sessionID {
      var queryItems = components?.queryItems ?? []
      queryItems.removeAll { $0.name == "session" }
      queryItems.append(URLQueryItem(name: "session", value: sessionID))
      components?.queryItems = queryItems
    }
    if let url = components?.url {
      NSWorkspace.shared.open(url)
    }
  }

  func toggleExpanded() {
    isExpanded.toggle()
  }

  private func stopConnection() {
    baselineTask?.cancel()
    hostTask?.cancel()
    muxTask?.cancel()
    baselineTask = nil
    hostTask = nil
    muxTask = nil
    baselineInFlight = false
    client = nil
  }

  private func runBaselineLoop(client: DSHClient, generation: UUID) async {
    while !Task.isCancelled, generation == self.generation {
      await fetchBaseline(client: client, generation: generation)
      do {
        try await Task.sleep(nanoseconds: 2_000_000_000)
      } catch {
        return
      }
    }
  }

  private func fetchBaseline(client: DSHClient, generation: UUID) async {
    guard generation == self.generation, !baselineInFlight else { return }
    baselineInFlight = true
    defer { baselineInFlight = false }
    do {
      let records = try await client.fetchSessions()
      guard generation == self.generation, !Task.isCancelled else { return }
      engine.applyBaseline(records)
    } catch {
      guard generation == self.generation, !Task.isCancelled else { return }
      engine.markDisconnected(error.localizedDescription)
    }
    publishSnapshot()
  }

  private func runStreamLoop(
    kind: DSHStreamKind,
    client: DSHClient,
    generation: UUID
  ) async {
    var attempt = 0
    while !Task.isCancelled, generation == self.generation {
      do {
        let stream = try client.stream(kind)
        for try await envelope in stream {
          guard generation == self.generation, !Task.isCancelled else { return }
          attempt = 0
          switch kind {
          case .host:
            engine.applyHost(envelope)
          case .mux:
            engine.applyMux(envelope)
          }
          publishSnapshot()
        }
      } catch {
        if Task.isCancelled { return }
      }
      guard generation == self.generation, !Task.isCancelled else { return }
      attempt += 1
      let delay = min(5.0, 0.5 * pow(2.0, Double(max(0, attempt - 1))))
      do {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      } catch {
        return
      }
    }
  }

  private func publishSnapshot(now: Date = Date()) {
    snapshot = engine.snapshot(now: now)
  }

  private func installDemoState() {
    let now = Date()
    if demoWorking {
      installWorkingDemoState(now: now)
      return
    }
    var demo = StatusEngine(privacyMode: preferences.privacyMode)
    demo.applyBaseline(
      [
        SessionRecord(
          id: "demo-review",
          updatedAt: now.addingTimeInterval(-92),
          running: true,
          blank: false,
          workingDirectory: "/Users/demo/orbit",
          title: "Review authentication boundary",
          todos: [
            TodoItem(content: "Trace request flow", status: .completed),
            TodoItem(content: "Confirm permission model", status: .inProgress),
            TodoItem(content: "Write regression test", status: .pending),
          ],
          projectionSequence: 18
        ),
        SessionRecord(
          id: "demo-build",
          updatedAt: now.addingTimeInterval(-38),
          running: true,
          blank: false,
          workingDirectory: "/Users/demo/dsh-island",
          title: "Build the native status island",
          todos: [
            TodoItem(content: "Design state engine", status: .completed),
            TodoItem(content: "Implement floating panel", status: .completed),
            TodoItem(content: "Verify multi-session events", status: .inProgress),
            TodoItem(content: "Package release", status: .pending),
          ],
          projectionSequence: 25
        ),
        SessionRecord(
          id: "demo-docs",
          updatedAt: now.addingTimeInterval(-64),
          running: true,
          blank: false,
          workingDirectory: "/Users/demo/docs",
          title: "Refresh plugin documentation"
        ),
        SessionRecord(
          id: "demo-research",
          updatedAt: now.addingTimeInterval(-21),
          running: false,
          blank: false,
          workingDirectory: "/Users/demo/research",
          title: "Compare provider behavior"
        ),
      ], now: now.addingTimeInterval(-120))
    demo.applyHost(
      Self.envelope(
        "host/session-status",
        [
          "sessionId": .string("demo-docs"),
          "running": .bool(false),
        ]), now: now.addingTimeInterval(-18))
    demo.applyHost(
      Self.envelope(
        "host/agent-error",
        [
          "sessionId": .string("demo-research"),
          "message": .string("Provider request timed out"),
        ]), now: now.addingTimeInterval(-21))
    demo.applyMux(
      Self.envelope(
        "approval/requested",
        [
          "sessionId": .string("demo-review"),
          "approvalId": .string("demo-approval"),
          "toolName": .string("bash"),
        ]), now: now.addingTimeInterval(-9))
    demo.applyMux(
      Self.envelope(
        "session/event",
        [
          "sessionId": .string("demo-build"),
          "event": .object([
            "type": .string("tool/call"),
            "data": .object(["name": .string("functions.exec_command")]),
          ]),
        ]), now: now.addingTimeInterval(-3))
    engine = demo
    publishSnapshot(now: now)
  }

  private func installWorkingDemoState(now: Date) {
    var demo = StatusEngine(privacyMode: preferences.privacyMode)
    demo.applyBaseline(
      [
        SessionRecord(
          id: "demo-stream",
          updatedAt: now.addingTimeInterval(-24),
          running: true,
          blank: false,
          workingDirectory: "/workspace/stream",
          title: "Trace multi-session events",
          todos: [
            TodoItem(content: "Map status events", status: .completed),
            TodoItem(content: "Verify reconnect flow", status: .inProgress),
            TodoItem(content: "Document edge cases", status: .pending),
          ],
          projectionSequence: 12
        ),
        SessionRecord(
          id: "demo-release",
          updatedAt: now.addingTimeInterval(-17),
          running: true,
          blank: false,
          workingDirectory: "/workspace/release",
          title: "Prepare the community release"
        ),
        SessionRecord(
          id: "demo-tests",
          updatedAt: now.addingTimeInterval(-11),
          running: true,
          blank: false,
          workingDirectory: "/workspace/tests",
          title: "Run the privacy-safe demo"
        ),
      ], now: now.addingTimeInterval(-60))
    engine = demo
    publishSnapshot(now: now)
  }

  private static func envelope(
    _ type: String,
    _ fields: [String: JSONValue]
  ) -> DSHStreamEnvelope {
    var payload = fields
    payload["type"] = .string(type)
    return DSHStreamEnvelope(rpcID: nil, method: nil, payload: .object(payload))
  }
}
