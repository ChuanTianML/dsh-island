import Foundation

/// A Sendable JSON value used at the independently released DSH wire boundary.
public enum JSONValue: Codable, Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Value is not valid JSON"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case .bool(let value):
      try container.encode(value)
    case .number(let value):
      try container.encode(value)
    case .string(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    }
  }

  /// The object payload, or nil for every other JSON kind.
  public var objectValue: [String: JSONValue]? {
    guard case .object(let value) = self else { return nil }
    return value
  }

  /// The array payload, or nil for every other JSON kind.
  public var arrayValue: [JSONValue]? {
    guard case .array(let value) = self else { return nil }
    return value
  }

  /// The string payload, or nil for every other JSON kind.
  public var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  /// The boolean payload, or nil for every other JSON kind.
  public var boolValue: Bool? {
    guard case .bool(let value) = self else { return nil }
    return value
  }

  /// The numeric payload, or nil for every other JSON kind.
  public var numberValue: Double? {
    guard case .number(let value) = self else { return nil }
    return value
  }

  /// A lossless integer view for JSON numbers in Swift's exact Int range.
  public var intValue: Int? {
    guard let value = numberValue, value.isFinite, value.rounded() == value else { return nil }
    guard value >= Double(Int.min), value < Double(Int.max) else { return nil }
    return Int(value)
  }

  /// Looks up one field when this value is an object.
  public subscript(key: String) -> JSONValue? {
    objectValue?[key]
  }
}
