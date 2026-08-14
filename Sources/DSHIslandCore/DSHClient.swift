import Foundation

/// The two read-only event channels exposed by the DSH Web host.
public enum DSHStreamKind: String, CaseIterable, Sendable {
  case host = "events.host"
  case mux = "events.mux"
}

/// Transport failures reported by the read-only DSH client.
public enum DSHClientError: Error, Equatable, LocalizedError, Sendable {
  case invalidHTTPResponse
  case httpStatus(Int)
  case invalidWebSocketURL
  case oversizedMessage

  public var errorDescription: String? {
    switch self {
    case .invalidHTTPResponse:
      return "DSH returned a non-HTTP response."
    case .httpStatus(let status):
      return "DSH returned HTTP \(status)."
    case .invalidWebSocketURL:
      return "The DSH URL cannot be used for an event stream."
    case .oversizedMessage:
      return "DSH returned an event larger than the safety limit."
    }
  }
}

/// A read-only HTTP and WebSocket client for the published DSH Web API.
public final class DSHClient: @unchecked Sendable {
  private static let maximumMessageBytes = 2 * 1_024 * 1_024

  private let baseURL: URL
  private let session: URLSession

  /// Creates a client for one normalized DSH endpoint.
  ///
  /// - Parameters:
  ///   - baseURL: An endpoint accepted by ``EndpointPolicy``.
  ///   - session: The URL session used by unary requests and WebSockets.
  public init(baseURL: URL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }

  /// Fetches the authoritative all-session reconnect baseline.
  public func fetchSessions() async throws -> [SessionRecord] {
    let rpcID = UUID().uuidString.lowercased()
    let body: [String: Any] = [
      "type": "client-request",
      "rpcId": rpcID,
      "method": "session.list",
      "payload": [:] as [String: Any],
    ]
    var request = URLRequest(url: apiURL(path: "session.list"))
    request.httpMethod = "POST"
    request.timeoutInterval = 5
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw DSHClientError.invalidHTTPResponse
    }
    guard (200...299).contains(response.statusCode) else {
      throw DSHClientError.httpStatus(response.statusCode)
    }
    guard data.count <= Self.maximumMessageBytes else {
      throw DSHClientError.oversizedMessage
    }

    let records = try DSHWireDecoder.sessionList(from: data)
    guard let json = try? JSONDecoder().decode(JSONValue.self, from: data),
      json["rpcId"]?.stringValue == rpcID
    else {
      throw DSHProtocolError.invalidEnvelope
    }
    return records
  }

  /// Opens one downlink-only event stream. Malformed messages are dropped independently.
  public func stream(_ kind: DSHStreamKind) throws -> AsyncThrowingStream<DSHStreamEnvelope, Error>
  {
    let task = session.webSocketTask(with: try webSocketURL(for: kind))
    return AsyncThrowingStream { continuation in
      task.resume()
      let pump = Task {
        do {
          while !Task.isCancelled {
            let message = try await task.receive()
            let data: Data
            switch message {
            case .data(let value):
              data = value
            case .string(let value):
              guard let valueData = value.data(using: .utf8) else { continue }
              data = valueData
            @unknown default:
              continue
            }
            guard data.count <= Self.maximumMessageBytes else {
              throw DSHClientError.oversizedMessage
            }
            guard let envelope = try? DSHWireDecoder.streamEnvelope(from: data) else {
              continue
            }
            continuation.yield(envelope)
          }
          continuation.finish()
        } catch is CancellationError {
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { @Sendable _ in
        pump.cancel()
        task.cancel(with: .goingAway, reason: nil)
      }
    }
  }

  private func apiURL(path: String) -> URL {
    baseURL.appending(path: "api").appending(path: path)
  }

  func webSocketURL(for kind: DSHStreamKind) throws -> URL {
    var components = URLComponents(url: apiURL(path: kind.rawValue), resolvingAgainstBaseURL: false)
    switch components?.scheme {
    case "http": components?.scheme = "ws"
    case "https": components?.scheme = "wss"
    default: throw DSHClientError.invalidWebSocketURL
    }
    guard let url = components?.url else { throw DSHClientError.invalidWebSocketURL }
    return url
  }
}
