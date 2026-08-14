import XCTest

@testable import DSHIslandCore

final class ProtocolTests: XCTestCase {
  func testSessionListDecodesPublishedFieldsAndProjections() throws {
    let data = Data(
      #"""
      {
        "type": "server-response",
        "rpcId": "list-1",
        "result": {
          "ok": true,
          "value": {
            "items": [{
              "sessionId": "session-a",
              "updatedAt": 1720000000123,
              "running": true,
              "blank": false,
              "parentSessionId": "session-root",
              "origin": "subagent",
              "cwd": "/tmp/alpha",
              "projections": {
                "asOfSeq": 14,
                "values": {
                  "title": "  Build alpha  ",
                  "todos": [
                    {"content": "Inspect", "status": "completed"},
                    {"content": "Implement", "status": "in_progress"}
                  ],
                  "unknown": {"future": true}
                }
              },
              "unknown": "ignored"
            }]
          }
        }
      }
      """#.utf8)

    let records = try DSHWireDecoder.sessionList(from: data)

    XCTAssertEqual(records.count, 1)
    let record = try XCTUnwrap(records.first)
    XCTAssertEqual(record.id, "session-a")
    XCTAssertEqual(record.updatedAt.timeIntervalSince1970, 1_720_000_000.123, accuracy: 0.001)
    XCTAssertTrue(record.running)
    XCTAssertFalse(record.blank)
    XCTAssertEqual(record.parentSessionID, "session-root")
    XCTAssertTrue(record.isSubagent)
    XCTAssertEqual(record.workingDirectory, "/tmp/alpha")
    XCTAssertEqual(record.title, "Build alpha")
    XCTAssertTrue(record.titleProjectionPresent)
    XCTAssertEqual(
      record.todos,
      [
        TodoItem(content: "Inspect", status: .completed),
        TodoItem(content: "Implement", status: .inProgress),
      ])
    XCTAssertTrue(record.todosProjectionPresent)
    XCTAssertEqual(record.projectionSequence, 14)
  }

  func testSessionListPreservesExplicitNullProjectionPresence() throws {
    let data = Data(
      #"""
      {"type":"server-response","rpcId":"r","result":{"ok":true,"value":{"items":[{
        "sessionId":"s","updatedAt":1000,"running":false,"blank":false,
        "projections":{"asOfSeq":2,"values":{"title":null,"todos":null}}
      }]}}}
      """#.utf8)

    let record = try XCTUnwrap(DSHWireDecoder.sessionList(from: data).first)

    XCTAssertNil(record.title)
    XCTAssertTrue(record.titleProjectionPresent)
    XCTAssertNil(record.todos)
    XCTAssertTrue(record.todosProjectionPresent)
  }

  func testSessionListReportsRPCFailure() {
    let data = Data(
      #"{"type":"server-response","rpcId":"r","result":{"ok":false,"error":{"code":"unavailable","message":"not ready"}}}"#
        .utf8)

    XCTAssertThrowsError(try DSHWireDecoder.sessionList(from: data)) { error in
      XCTAssertEqual(
        error as? DSHProtocolError, .rpcFailure(code: "unavailable", message: "not ready"))
    }
  }

  func testInvalidTodoListIsDiscardedAsAWhole() throws {
    let data = Data(
      #"""
      {"type":"server-response","rpcId":"r","result":{"ok":true,"value":{"items":[{
        "sessionId":"s","updatedAt":1000,"running":true,"blank":false,
        "projections":{"asOfSeq":2,"values":{"todos":[{"content":"x","status":"future"}]}}
      }]}}}
      """#.utf8)

    let record = try XCTUnwrap(DSHWireDecoder.sessionList(from: data).first)

    XCTAssertTrue(record.todosProjectionPresent)
    XCTAssertNil(record.todos)
  }

  func testStreamEnvelopeRetainsOuterRPCIdentity() throws {
    let data = Data(
      #"""
      {"type":"server-request","rpcId":"question-42","method":"events.mux","payload":{
        "type":"question/requested","sessionId":"s","questions":[{"id":"q","question":"Continue?"}]
      }}
      """#.utf8)

    let envelope = try DSHWireDecoder.streamEnvelope(from: data)

    XCTAssertEqual(envelope.rpcID, "question-42")
    XCTAssertEqual(envelope.method, "events.mux")
    XCTAssertEqual(envelope.type, "question/requested")
  }

  func testMalformedJSONIsRejected() {
    XCTAssertThrowsError(try DSHWireDecoder.streamEnvelope(from: Data("{".utf8))) { error in
      XCTAssertEqual(error as? DSHProtocolError, .invalidJSON)
    }
  }

  func testEnvelopeDiscriminantsAndStreamIdentityAreRequired() {
    let wrongResponse = Data(
      #"{"type":"client-request","rpcId":"r","result":{"ok":true,"value":{"items":[]}}}"#.utf8)
    XCTAssertThrowsError(try DSHWireDecoder.sessionList(from: wrongResponse)) { error in
      XCTAssertEqual(error as? DSHProtocolError, .invalidEnvelope)
    }

    let missingStreamIdentity = Data(
      #"{"type":"server-request","method":"events.host","payload":{"type":"host/session-removed","sessionId":"s"}}"#
        .utf8)
    XCTAssertThrowsError(try DSHWireDecoder.streamEnvelope(from: missingStreamIdentity)) { error in
      XCTAssertEqual(error as? DSHProtocolError, .invalidEnvelope)
    }
  }

  func testJSONIntegerViewRejectsFractionAndInfinity() {
    XCTAssertEqual(JSONValue.number(3).intValue, 3)
    XCTAssertNil(JSONValue.number(3.2).intValue)
    XCTAssertNil(JSONValue.number(.infinity).intValue)
    XCTAssertNil(JSONValue.number(Double(Int.max)).intValue)
    XCTAssertEqual(JSONValue.number(Double(Int.min)).intValue, Int.min)
  }
}
