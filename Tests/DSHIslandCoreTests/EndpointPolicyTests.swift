import XCTest

@testable import DSHIslandCore

final class EndpointPolicyTests: XCTestCase {
  func testNormalizesLoopbackEndpoint() throws {
    XCTAssertEqual(
      try EndpointPolicy.normalize(" HTTP://LOCALHOST:3080/ ", allowRemote: false).absoluteString,
      "http://localhost:3080"
    )
    XCTAssertEqual(
      try EndpointPolicy.normalize("http://127.42.0.9:4000", allowRemote: false).host,
      "127.42.0.9"
    )
    XCTAssertEqual(
      try EndpointPolicy.normalize("http://[::1]:3080", allowRemote: false).host,
      "::1"
    )
  }

  func testRejectsRemoteEndpointWithoutPermission() {
    XCTAssertThrowsError(try EndpointPolicy.normalize("https://dsh.example", allowRemote: false)) {
      error in
      XCTAssertEqual(error as? EndpointPolicyError, .remoteEndpointNotAllowed)
    }
  }

  func testAllowsExplicitRemoteEndpoint() throws {
    XCTAssertEqual(
      try EndpointPolicy.normalize("https://DSH.EXAMPLE:8443", allowRemote: true).absoluteString,
      "https://dsh.example:8443"
    )
  }

  func testRejectsCredentialsAndNonBasePaths() {
    XCTAssertThrowsError(
      try EndpointPolicy.normalize("http://user:pass@localhost:3080", allowRemote: false)
    ) { error in
      XCTAssertEqual(error as? EndpointPolicyError, .credentialsNotAllowed)
    }
    for value in [
      "http://localhost:3080/api",
      "http://localhost:3080/?token=x",
      "http://localhost:3080/#fragment",
    ] {
      XCTAssertThrowsError(try EndpointPolicy.normalize(value, allowRemote: false)) { error in
        XCTAssertEqual(error as? EndpointPolicyError, .pathNotAllowed)
      }
    }
  }

  func testRejectsUnsupportedOrIncompleteURL() {
    XCTAssertThrowsError(try EndpointPolicy.normalize("localhost:3080", allowRemote: false))
    XCTAssertThrowsError(try EndpointPolicy.normalize("file:///tmp/dsh", allowRemote: false))
  }

  func testLoopbackClassifierRejectsLookalikes() {
    XCTAssertTrue(EndpointPolicy.isLoopback("LOCALHOST"))
    XCTAssertTrue(EndpointPolicy.isLoopback("127.255.255.255"))
    XCTAssertFalse(EndpointPolicy.isLoopback("127.example.com"))
    XCTAssertFalse(EndpointPolicy.isLoopback("127.0.0.999"))
    XCTAssertFalse(EndpointPolicy.isLoopback("10.0.0.1"))
  }
}
