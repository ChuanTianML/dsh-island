import XCTest

@testable import DSHIslandCore

final class StatusEngineTests: XCTestCase {
  private let origin = Date(timeIntervalSince1970: 1_720_000_000)

  func testRunningBaselineCountsVisibleSessionsWithoutInventingProgress() {
    var engine = StatusEngine()
    engine.applyBaseline(
      [
        record("a", running: true, title: "Alpha"),
        record("b", running: true, title: "Beta"),
        record("blank", running: false, blank: true),
      ], now: origin)

    let snapshot = engine.snapshot(now: origin)

    XCTAssertTrue(snapshot.connected)
    XCTAssertEqual(snapshot.aggregateStatus, .running)
    XCTAssertEqual(snapshot.counts.running, 2)
    XCTAssertEqual(Set(snapshot.sessions.map(\.title)), Set(["Alpha", "Beta"]))
    XCTAssertTrue(snapshot.sessions.allSatisfy { $0.progress == nil })
  }

  func testTodoProgressUsesOnlyPublishedTodos() {
    var engine = StatusEngine()
    engine.applyBaseline(
      [
        record(
          "a", running: true,
          todos: [
            TodoItem(content: "One", status: .completed),
            TodoItem(content: "Two", status: .completed),
            TodoItem(content: "Build the native island", status: .inProgress),
            TodoItem(content: "Ship", status: .pending),
          ])
      ], now: origin)

    let progress = engine.snapshot(now: origin).sessions.first?.progress

    XCTAssertEqual(
      progress, TodoProgress(completed: 2, total: 4, activeItem: "Build the native island"))
    XCTAssertEqual(progress?.fraction, 0.5)
  }

  func testAttentionOutranksFailureAndRunning() {
    var engine = StatusEngine()
    engine.applyBaseline([record("a", running: true)], now: origin)
    engine.applyHost(
      envelope(
        "host/agent-error",
        [
          "sessionId": .string("a"),
          "message": .string("Provider failed"),
        ]), now: origin.addingTimeInterval(1))
    engine.applyMux(
      envelope(
        "approval/requested",
        [
          "sessionId": .string("a"),
          "approvalId": .string("approval-1"),
          "toolName": .string("bash"),
        ]), now: origin.addingTimeInterval(2))

    let snapshot = engine.snapshot(now: origin.addingTimeInterval(2))

    XCTAssertEqual(snapshot.aggregateStatus, .attention)
    XCTAssertEqual(snapshot.sessions.first?.status, .attention)
    XCTAssertEqual(snapshot.sessions.first?.interaction, .approval(toolName: "bash"))
  }

  func testInteractionReplayIsIdempotentAndResolutionUsesStableIdentity() {
    var engine = StatusEngine()
    engine.applyBaseline([record("a", running: true)], now: origin)
    let requested = envelope("question/requested", ["sessionId": .string("a")], rpcID: "question-1")
    engine.applyMux(requested, now: origin)
    engine.applyMux(requested, now: origin)

    XCTAssertEqual(engine.snapshot(now: origin).counts.attention, 1)

    engine.applyMux(
      envelope(
        "question/resolved",
        [
          "sessionId": .string("a"),
          "questionRpcId": .string("question-1"),
        ]), now: origin)
    XCTAssertEqual(engine.snapshot(now: origin).aggregateStatus, .running)
  }

  func testCompletionRequiresAnObservedRunningEdgeAndExpires() {
    var engine = StatusEngine(completionLifetime: 10)
    engine.applyBaseline([record("idle", running: false)], now: origin)
    XCTAssertEqual(engine.snapshot(now: origin).sessions.first?.status, .idle)

    engine.applyHost(
      envelope(
        "host/session-status",
        [
          "sessionId": .string("idle"),
          "running": .bool(true),
        ]), now: origin.addingTimeInterval(1))
    engine.applyHost(
      envelope(
        "host/session-status",
        [
          "sessionId": .string("idle"),
          "running": .bool(false),
        ]), now: origin.addingTimeInterval(3))

    XCTAssertEqual(engine.snapshot(now: origin.addingTimeInterval(5)).aggregateStatus, .completed)
    XCTAssertEqual(engine.snapshot(now: origin.addingTimeInterval(14)).aggregateStatus, .idle)
  }

  func testFirstRunningFrameMakesANewBlankSessionVisible() {
    var engine = StatusEngine()
    engine.applyBaseline([], now: origin)
    engine.applyHost(
      envelope(
        "host/session-added",
        [
          "sessionId": .string("new"),
          "blank": .bool(true),
          "cwd": .string("/tmp/new-project"),
        ]), now: origin)

    XCTAssertTrue(engine.snapshot(now: origin).sessions.isEmpty)

    engine.applyHost(
      envelope(
        "host/session-status",
        [
          "sessionId": .string("new"),
          "running": .bool(true),
        ]), now: origin.addingTimeInterval(1))

    let row = engine.snapshot(now: origin.addingTimeInterval(1)).sessions.first
    XCTAssertEqual(row?.title, "new-project")
    XCTAssertEqual(row?.status, .running)
  }

  func testNewerProjectionWinsOverStaleBaselineAndLiveFrame() {
    var engine = StatusEngine()
    engine.applyBaseline(
      [
        record("a", running: true, title: "Baseline", projectionSequence: 5)
      ], now: origin)
    engine.applyMux(
      envelope(
        "session/projection",
        [
          "sessionId": .string("a"),
          "key": .string("title"),
          "value": .string("Live"),
          "seq": .number(7),
        ]), now: origin)
    engine.applyMux(
      envelope(
        "session/projection",
        [
          "sessionId": .string("a"),
          "key": .string("title"),
          "value": .string("Stale"),
          "seq": .number(6),
        ]), now: origin)
    engine.applyBaseline(
      [
        record("a", running: true, title: "Old reconnect", projectionSequence: 5)
      ], now: origin)

    XCTAssertEqual(engine.snapshot(now: origin).sessions.first?.title, "Live")
  }

  func testPrivacyRedactsEveryRemoteDetailAtSnapshotBoundary() {
    var engine = StatusEngine(privacyMode: true)
    engine.applyBaseline(
      [
        record(
          "secret", running: true, title: "Secret Project", workingDirectory: "/Users/me/Secret",
          todos: [
            TodoItem(content: "Confidential task", status: .inProgress)
          ])
      ], now: origin)
    engine.applyHost(
      envelope(
        "host/agent-error",
        [
          "sessionId": .string("secret"),
          "message": .string("Secret provider detail"),
        ]), now: origin)
    engine.applyMux(
      envelope(
        "approval/requested",
        [
          "sessionId": .string("secret"),
          "approvalId": .string("a"),
          "toolName": .string("secret-tool"),
        ]), now: origin)
    engine.applyMux(
      envelope(
        "session/event",
        [
          "sessionId": .string("secret"),
          "event": .object([
            "type": .string("tool/call"),
            "data": .object(["name": .string("private_custom_tool")]),
          ]),
        ]), now: origin)

    let row = engine.snapshot(now: origin).sessions[0]

    XCTAssertEqual(row.title, "Session 1")
    XCTAssertNil(row.failureSummary)
    XCTAssertEqual(row.interaction, .approval(toolName: nil))
    XCTAssertNil(row.progress?.activeItem)
    XCTAssertEqual(row.activity, .usingTool(.other("tool")))
  }

  func testSubagentStaysBelowParentWhileGroupInheritsItsPriority() {
    var engine = StatusEngine()
    engine.applyBaseline(
      [
        record("other", running: true, title: "Other"),
        record("parent", running: false, title: "Parent"),
        record("child", running: true, parentSessionID: "parent", isSubagent: true, title: "Child"),
      ], now: origin)
    engine.applyMux(
      envelope(
        "approval/requested",
        [
          "sessionId": .string("child"),
          "approvalId": .string("approval"),
          "toolName": .string("bash"),
        ]), now: origin)

    let rows = engine.snapshot(now: origin).sessions

    XCTAssertEqual(rows.map(\.id), ["parent", "child", "other"])
    XCTAssertEqual(rows.map(\.depth), [0, 1, 0])
  }

  func testDisconnectOverridesAggregateAndRedactsConnectionMessageInPrivacyMode() {
    var engine = StatusEngine(privacyMode: true)
    engine.applyBaseline([record("a", running: true)], now: origin)
    engine.markDisconnected("Connection to secret-host.example failed", now: origin)

    let snapshot = engine.snapshot(now: origin)

    XCTAssertFalse(snapshot.connected)
    XCTAssertEqual(snapshot.aggregateStatus, .offline)
    XCTAssertNil(snapshot.connectionMessage)
    XCTAssertEqual(snapshot.counts.running, 1)
  }

  func testToolActivityNeverCarriesArguments() {
    var engine = StatusEngine()
    engine.applyBaseline([record("a", running: true)], now: origin)
    engine.applyMux(
      envelope(
        "session/event",
        [
          "sessionId": .string("a"),
          "event": .object([
            "type": .string("tool/call"),
            "data": .object([
              "name": .string("functions.exec_command"),
              "arguments": .object(["cmd": .string("cat ~/.ssh/id_rsa")]),
            ]),
          ]),
        ]), now: origin)

    XCTAssertEqual(engine.snapshot(now: origin).sessions.first?.activity, .usingTool(.command))
  }

  private func record(
    _ id: String,
    running: Bool,
    blank: Bool = false,
    parentSessionID: String? = nil,
    isSubagent: Bool = false,
    title: String? = nil,
    workingDirectory: String? = nil,
    todos: [TodoItem]? = nil,
    projectionSequence: Int? = nil
  ) -> SessionRecord {
    SessionRecord(
      id: id,
      updatedAt: origin,
      running: running,
      blank: blank,
      parentSessionID: parentSessionID,
      isSubagent: isSubagent,
      workingDirectory: workingDirectory,
      title: title,
      todos: todos,
      projectionSequence: projectionSequence
    )
  }

  private func envelope(
    _ type: String,
    _ fields: [String: JSONValue],
    rpcID: String? = nil
  ) -> DSHStreamEnvelope {
    var payload = fields
    payload["type"] = .string(type)
    return DSHStreamEnvelope(rpcID: rpcID, method: nil, payload: .object(payload))
  }
}
