import Foundation
import XCTest

@testable import DSHIslandCore

final class DSHClientTests: XCTestCase {
  override func tearDown() {
    URLProtocolStub.handler = nil
    super.tearDown()
  }

  func testFetchSessionsSendsCompleteClientRequestAndChecksResponseIdentity() async throws {
    URLProtocolStub.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:3080/api/session.list")
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
      let body = try self.requestBody(from: request)
      let json = try JSONDecoder().decode(JSONValue.self, from: body)
      XCTAssertEqual(json["type"]?.stringValue, "client-request")
      XCTAssertEqual(json["method"]?.stringValue, "session.list")
      XCTAssertNotNil(json["payload"]?.objectValue)
      let rpcID = try XCTUnwrap(json["rpcId"]?.stringValue)
      let response =
        #"{"type":"server-response","rpcId":"\#(rpcID)","result":{"ok":true,"value":{"items":[]}}}"#
      return (200, Data(response.utf8))
    }
    let client = DSHClient(baseURL: URL(string: "http://127.0.0.1:3080")!, session: makeSession())

    let records = try await client.fetchSessions()

    XCTAssertEqual(records, [])
  }

  func testFetchSessionsRejectsHTTPFailureAndMismatchedRPCID() async {
    let client = DSHClient(
      baseURL: URL(string: "http://127.0.0.1:3080")!,
      session: makeSession()
    )
    URLProtocolStub.handler = { _ in (503, Data()) }
    do {
      _ = try await client.fetchSessions()
      XCTFail("Expected an HTTP failure")
    } catch {
      XCTAssertEqual(error as? DSHClientError, .httpStatus(503))
    }

    URLProtocolStub.handler = { _ in
      (
        200,
        Data(
          #"{"type":"server-response","rpcId":"wrong","result":{"ok":true,"value":{"items":[]}}}"#
            .utf8)
      )
    }
    do {
      _ = try await client.fetchSessions()
      XCTFail("Expected an identity failure")
    } catch {
      XCTAssertEqual(error as? DSHProtocolError, .invalidEnvelope)
    }
  }

  func testWebSocketURLsFollowEndpointSecurity() throws {
    let plain = DSHClient(baseURL: URL(string: "http://localhost:3080")!)
    let secure = DSHClient(baseURL: URL(string: "https://dsh.example:443")!)

    XCTAssertEqual(
      try plain.webSocketURL(for: .host).absoluteString, "ws://localhost:3080/api/events.host")
    XCTAssertEqual(
      try secure.webSocketURL(for: .mux).absoluteString, "wss://dsh.example:443/api/events.mux")
  }

  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: configuration)
  }

  private func requestBody(from request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    let stream = try XCTUnwrap(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var body = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count < 0 { throw try XCTUnwrap(stream.streamError) }
      if count == 0 { break }
      body.append(buffer, count: count)
    }
    return body
  }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
  static var handler: ((URLRequest) throws -> (Int, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    do {
      let handler = try XCTUnwrap(Self.handler)
      let (status, data) = try handler(request)
      let response = HTTPURLResponse(
        url: try XCTUnwrap(request.url),
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
      )!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
