import Foundation

/// Validation failures for a user-supplied DSH Web endpoint.
public enum EndpointPolicyError: Error, Equatable, LocalizedError, Sendable {
  case missingURL
  case unsupportedScheme
  case credentialsNotAllowed
  case pathNotAllowed
  case remoteEndpointNotAllowed

  public var errorDescription: String? {
    switch self {
    case .missingURL:
      return "Enter a complete DSH URL."
    case .unsupportedScheme:
      return "The DSH URL must use http or https."
    case .credentialsNotAllowed:
      return "Credentials are not allowed in the DSH URL."
    case .pathNotAllowed:
      return "The DSH URL must not contain a path, query, or fragment."
    case .remoteEndpointNotAllowed:
      return "Remote DSH endpoints require explicit permission."
    }
  }
}

/// Normalizes and enforces the trust policy for DSH endpoints.
public enum EndpointPolicy {
  /// Parses a base URL and rejects non-loopback hosts unless explicitly enabled.
  public static func normalize(_ rawValue: String, allowRemote: Bool) throws -> URL {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard var components = URLComponents(string: trimmed),
      let scheme = components.scheme?.lowercased(),
      let encodedHost = components.host?.lowercased(),
      !encodedHost.isEmpty
    else {
      throw EndpointPolicyError.missingURL
    }
    guard scheme == "http" || scheme == "https" else {
      throw EndpointPolicyError.unsupportedScheme
    }
    guard components.user == nil, components.password == nil else {
      throw EndpointPolicyError.credentialsNotAllowed
    }
    guard components.query == nil,
      components.fragment == nil,
      components.path.isEmpty || components.path == "/"
    else {
      throw EndpointPolicyError.pathNotAllowed
    }
    let policyHost =
      encodedHost.hasPrefix("[") && encodedHost.hasSuffix("]")
      ? String(encodedHost.dropFirst().dropLast())
      : encodedHost
    guard allowRemote || isLoopback(policyHost) else {
      throw EndpointPolicyError.remoteEndpointNotAllowed
    }

    components.scheme = scheme
    components.host = encodedHost
    components.path = ""
    guard let url = components.url else { throw EndpointPolicyError.missingURL }
    return url
  }

  /// Whether the normalized host is a loopback name or address.
  public static func isLoopback(_ host: String) -> Bool {
    let lowered = host.lowercased()
    let host =
      lowered.hasPrefix("[") && lowered.hasSuffix("]")
      ? String(lowered.dropFirst().dropLast())
      : lowered
    if host == "localhost" || host == "::1" { return true }
    let octets = host.split(separator: ".")
    guard octets.count == 4, octets.first == "127" else { return false }
    return octets.allSatisfy { part in
      guard let value = Int(part) else { return false }
      return (0...255).contains(value)
    }
  }
}
