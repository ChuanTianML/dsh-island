import Foundation

/// A malformed or rejected DSH wire message.
public enum DSHProtocolError: Error, Equatable, LocalizedError, Sendable {
  case invalidJSON
  case invalidEnvelope
  case rpcFailure(code: String, message: String)
  case invalidSessionList

  public var errorDescription: String? {
    switch self {
    case .invalidJSON:
      return "DSH returned invalid JSON."
    case .invalidEnvelope:
      return "DSH returned an invalid RPC envelope."
    case .rpcFailure(let code, let message):
      return "DSH RPC failed (\(code)): \(message)"
    case .invalidSessionList:
      return "DSH returned an invalid session list."
    }
  }
}

/// The lifecycle state of one DSH Todo item.
public enum TodoStatus: String, Codable, Equatable, Sendable {
  case pending
  case inProgress = "in_progress"
  case completed
}

/// One validated item from the `todos` session projection.
public struct TodoItem: Codable, Equatable, Sendable {
  public let content: String
  public let status: TodoStatus

  public init(content: String, status: TodoStatus) {
    self.content = content
    self.status = status
  }
}

/// The fields DSH Island consumes from one `session.list` row.
public struct SessionRecord: Equatable, Sendable {
  public let id: String
  public let updatedAt: Date
  public let running: Bool
  public let blank: Bool
  public let parentSessionID: String?
  public let isSubagent: Bool
  public let workingDirectory: String?
  public let title: String?
  public let titleProjectionPresent: Bool
  public let todos: [TodoItem]?
  public let todosProjectionPresent: Bool
  public let projectionSequence: Int?

  public init(
    id: String,
    updatedAt: Date,
    running: Bool,
    blank: Bool,
    parentSessionID: String? = nil,
    isSubagent: Bool = false,
    workingDirectory: String? = nil,
    title: String? = nil,
    titleProjectionPresent: Bool? = nil,
    todos: [TodoItem]? = nil,
    todosProjectionPresent: Bool? = nil,
    projectionSequence: Int? = nil
  ) {
    self.id = id
    self.updatedAt = updatedAt
    self.running = running
    self.blank = blank
    self.parentSessionID = parentSessionID
    self.isSubagent = isSubagent
    self.workingDirectory = workingDirectory
    self.title = title
    self.titleProjectionPresent = titleProjectionPresent ?? (title != nil)
    self.todos = todos
    self.todosProjectionPresent = todosProjectionPresent ?? (todos != nil)
    self.projectionSequence = projectionSequence
  }
}

/// One server-initiated stream message, retaining the outer RPC identity.
public struct DSHStreamEnvelope: Equatable, Sendable {
  public let rpcID: String?
  public let method: String?
  public let payload: JSONValue

  public init(rpcID: String?, method: String?, payload: JSONValue) {
    self.rpcID = rpcID
    self.method = method
    self.payload = payload
  }

  /// The payload's discriminant, when present.
  public var type: String? { payload["type"]?.stringValue }
}

/// Decodes DSH RPC and stream envelopes without coupling to a particular client release.
public enum DSHWireDecoder {
  /// Decodes a successful `session.list` response.
  public static func sessionList(from data: Data) throws -> [SessionRecord] {
    let json = try decodeJSON(data)
    guard json["type"]?.stringValue == "server-response",
      json["rpcId"]?.stringValue != nil,
      let result = json["result"]
    else {
      throw DSHProtocolError.invalidEnvelope
    }

    if result["ok"]?.boolValue == false {
      let error = result["error"]
      throw DSHProtocolError.rpcFailure(
        code: error?["code"]?.stringValue ?? "unknown",
        message: error?["message"]?.stringValue ?? "Unknown DSH error"
      )
    }

    guard result["ok"]?.boolValue == true,
      let items = result["value"]?["items"]?.arrayValue
    else {
      throw DSHProtocolError.invalidSessionList
    }

    return try items.map(decodeSession)
  }

  /// Decodes one server-request stream envelope.
  public static func streamEnvelope(from data: Data) throws -> DSHStreamEnvelope {
    let json = try decodeJSON(data)
    guard json["type"]?.stringValue == "server-request",
      let rpcID = json["rpcId"]?.stringValue,
      let method = json["method"]?.stringValue,
      let payload = json["payload"],
      payload.objectValue != nil
    else {
      throw DSHProtocolError.invalidEnvelope
    }
    return DSHStreamEnvelope(
      rpcID: rpcID,
      method: method,
      payload: payload
    )
  }

  private static func decodeJSON(_ data: Data) throws -> JSONValue {
    do {
      return try JSONDecoder().decode(JSONValue.self, from: data)
    } catch {
      throw DSHProtocolError.invalidJSON
    }
  }

  private static func decodeSession(_ value: JSONValue) throws -> SessionRecord {
    guard let id = value["sessionId"]?.stringValue,
      let updatedMilliseconds = value["updatedAt"]?.numberValue,
      let running = value["running"]?.boolValue,
      let blank = value["blank"]?.boolValue
    else {
      throw DSHProtocolError.invalidSessionList
    }

    let projections = value["projections"]
    let projectionSequence = projections?["asOfSeq"]?.intValue
    let projectionValues = projections?["values"]
    let projectionObject = projectionValues?.objectValue
    let title = normalizedOptionalText(projectionValues?["title"]?.stringValue)
    let todos = decodeTodos(projectionValues?["todos"])

    return SessionRecord(
      id: id,
      updatedAt: Date(timeIntervalSince1970: updatedMilliseconds / 1_000),
      running: running,
      blank: blank,
      parentSessionID: value["parentSessionId"]?.stringValue,
      isSubagent: value["origin"]?.stringValue == "subagent",
      workingDirectory: normalizedOptionalText(value["cwd"]?.stringValue),
      title: title,
      titleProjectionPresent: projectionObject?["title"] != nil,
      todos: todos,
      todosProjectionPresent: projectionObject?["todos"] != nil,
      projectionSequence: projectionSequence
    )
  }

  /// Returns nil for no projection, JSON null, or an invalid whole-list value.
  static func decodeTodos(_ value: JSONValue?) -> [TodoItem]? {
    guard let value else { return nil }
    if value == .null { return nil }
    guard let rows = value.arrayValue else { return nil }

    var todos: [TodoItem] = []
    todos.reserveCapacity(rows.count)
    for row in rows {
      guard let content = normalizedOptionalText(row["content"]?.stringValue),
        let rawStatus = row["status"]?.stringValue,
        let status = TodoStatus(rawValue: rawStatus)
      else {
        return nil
      }
      todos.append(TodoItem(content: content, status: status))
    }
    return todos
  }
}

func normalizedOptionalText(_ text: String?) -> String? {
  guard let text else { return nil }
  let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
  return normalized.isEmpty ? nil : normalized
}
