import Foundation

/// The status class used for aggregate and per-session presentation.
public enum IslandStatus: String, Codable, CaseIterable, Equatable, Sendable {
  case attention
  case failure
  case running
  case completed
  case idle
  case offline

  var priority: Int {
    switch self {
    case .attention: return 0
    case .failure: return 1
    case .running: return 2
    case .completed: return 3
    case .idle: return 4
    case .offline: return 5
    }
  }
}

/// The human action currently blocking a session.
public enum InteractionKind: Equatable, Sendable {
  case approval(toolName: String?)
  case question
}

/// A coarse tool class that can be localized without exposing tool arguments.
public enum ToolCategory: Equatable, Sendable {
  case command
  case inspectingFiles
  case editingFiles
  case web
  case agents
  case code
  case other(String)

  static func classify(_ rawName: String) -> ToolCategory {
    let name = rawName.lowercased()
    if name.contains("bash") || name.contains("shell") || name.contains("terminal")
      || name.contains("exec")
    {
      return .command
    }
    if name.contains("read") || name.contains("glob") || name.contains("search")
      || name.contains("find") || name.contains("list")
    {
      return .inspectingFiles
    }
    if name.contains("write") || name.contains("edit") || name.contains("patch")
      || name.contains("replace")
    {
      return .editingFiles
    }
    if name.contains("web") || name.contains("fetch") || name.contains("browser")
      || name.contains("http")
    {
      return .web
    }
    if name.contains("agent") || name.contains("delegate") || name.contains("workflow") {
      return .agents
    }
    if name.contains("code") || name.contains("python") || name.contains("javascript") {
      return .code
    }
    return .other(boundedText(rawName, limit: 28) ?? "tool")
  }
}

/// A descriptive live phase. It never implies a percentage or ETA.
public enum ActivityKind: Equatable, Sendable {
  case preparing
  case reasoning
  case writing
  case usingTool(ToolCategory)
  case reviewingResult
  case stopped
}

/// Determinate progress derived only from a non-empty Todo projection.
public struct TodoProgress: Equatable, Sendable {
  public let completed: Int
  public let total: Int
  public let activeItem: String?

  public init(completed: Int, total: Int, activeItem: String?) {
    self.completed = completed
    self.total = total
    self.activeItem = activeItem
  }

  public var fraction: Double {
    guard total > 0 else { return 0 }
    return Double(completed) / Double(total)
  }
}

/// One presentation-safe row in an island snapshot.
public struct SessionDisplayItem: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let status: IslandStatus
  public let interaction: InteractionKind?
  public let activity: ActivityKind?
  public let progress: TodoProgress?
  public let failureSummary: String?
  public let startedAt: Date?
  public let completedAt: Date?
  public let updatedAt: Date
  public let depth: Int
  public let backgroundJobCount: Int

  public init(
    id: String,
    title: String,
    status: IslandStatus,
    interaction: InteractionKind?,
    activity: ActivityKind?,
    progress: TodoProgress?,
    failureSummary: String?,
    startedAt: Date?,
    completedAt: Date?,
    updatedAt: Date,
    depth: Int,
    backgroundJobCount: Int
  ) {
    self.id = id
    self.title = title
    self.status = status
    self.interaction = interaction
    self.activity = activity
    self.progress = progress
    self.failureSummary = failureSummary
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.updatedAt = updatedAt
    self.depth = depth
    self.backgroundJobCount = backgroundJobCount
  }
}

/// Aggregate counts carried by a stable island snapshot.
public struct IslandCounts: Equatable, Sendable {
  public let attention: Int
  public let failure: Int
  public let running: Int
  public let completed: Int
  public let idle: Int

  public init(attention: Int, failure: Int, running: Int, completed: Int, idle: Int) {
    self.attention = attention
    self.failure = failure
    self.running = running
    self.completed = completed
    self.idle = idle
  }
}

/// Immutable state consumed by every UI surface.
public struct IslandSnapshot: Equatable, Sendable {
  public let aggregateStatus: IslandStatus
  public let counts: IslandCounts
  public let sessions: [SessionDisplayItem]
  public let connected: Bool
  public let connectionMessage: String?

  public init(
    aggregateStatus: IslandStatus,
    counts: IslandCounts,
    sessions: [SessionDisplayItem],
    connected: Bool,
    connectionMessage: String?
  ) {
    self.aggregateStatus = aggregateStatus
    self.counts = counts
    self.sessions = sessions
    self.connected = connected
    self.connectionMessage = connectionMessage
  }

  /// A deterministic empty state used before the first baseline completes.
  public static let starting = IslandSnapshot(
    aggregateStatus: .offline,
    counts: IslandCounts(attention: 0, failure: 0, running: 0, completed: 0, idle: 0),
    sessions: [],
    connected: false,
    connectionMessage: nil
  )
}

/// Pure all-session fold over DSH list baselines and live event frames.
public struct StatusEngine: Sendable {
  private struct SessionState: Sendable {
    var id: String
    var updatedAt: Date
    var running: Bool
    var blank: Bool
    var parentSessionID: String?
    var isSubagent: Bool
    var workingDirectory: String?
    var title: String?
    var todos: [TodoItem]?
    var projectionSequences: [String: Int]
    var startedAt: Date?
    var completedAt: Date?
    var failedAt: Date?
    var failureSummary: String?
    var activity: ActivityKind?
    var backgroundJobCount: Int
  }

  private struct PendingInteraction: Sendable {
    let sessionID: String
    let kind: InteractionKind
  }

  public var completionLifetime: TimeInterval
  public var failureLifetime: TimeInterval
  public var privacyMode: Bool

  private var sessions: [String: SessionState] = [:]
  private var approvals: [String: PendingInteraction] = [:]
  private var questions: [String: PendingInteraction] = [:]
  private var privacyAliases: [String: Int] = [:]
  private var nextPrivacyAlias = 1
  private var connected = false
  private var connectionMessage: String?

  public init(
    completionLifetime: TimeInterval = 120,
    failureLifetime: TimeInterval = 600,
    privacyMode: Bool = false
  ) {
    self.completionLifetime = completionLifetime
    self.failureLifetime = failureLifetime
    self.privacyMode = privacyMode
  }

  /// Applies the complete `session.list` reconnect baseline.
  public mutating func applyBaseline(_ records: [SessionRecord], now: Date = Date()) {
    let seen = Set(records.map(\.id))
    sessions = sessions.filter { seen.contains($0.key) }
    approvals = approvals.filter { seen.contains($0.value.sessionID) }
    questions = questions.filter { seen.contains($0.value.sessionID) }

    for record in records {
      if var state = sessions[record.id] {
        let wasRunning = state.running
        state.updatedAt = record.updatedAt
        state.running = record.running
        state.blank = record.blank
        state.parentSessionID = record.parentSessionID
        state.isSubagent = record.isSubagent
        state.workingDirectory = record.workingDirectory

        if shouldApplyBaselineProjection(
          key: "title",
          present: record.titleProjectionPresent,
          sequence: record.projectionSequence,
          to: state
        ) {
          state.title = record.title
          if let sequence = record.projectionSequence {
            state.projectionSequences["title"] = sequence
          }
        }
        if shouldApplyBaselineProjection(
          key: "todos",
          present: record.todosProjectionPresent,
          sequence: record.projectionSequence,
          to: state
        ) {
          state.todos = record.todos
          if let sequence = record.projectionSequence {
            state.projectionSequences["todos"] = sequence
          }
        }

        if !wasRunning, record.running {
          beginRun(&state, at: now)
        } else if wasRunning, !record.running {
          completeRun(&state, at: now)
          clearInteractions(for: record.id)
        }
        sessions[record.id] = state
      } else {
        var sequences: [String: Int] = [:]
        if let sequence = record.projectionSequence {
          if record.titleProjectionPresent { sequences["title"] = sequence }
          if record.todosProjectionPresent { sequences["todos"] = sequence }
        }
        sessions[record.id] = SessionState(
          id: record.id,
          updatedAt: record.updatedAt,
          running: record.running,
          blank: record.blank,
          parentSessionID: record.parentSessionID,
          isSubagent: record.isSubagent,
          workingDirectory: record.workingDirectory,
          title: record.title,
          todos: record.todos,
          projectionSequences: sequences,
          startedAt: record.running ? min(record.updatedAt, now) : nil,
          completedAt: nil,
          failedAt: nil,
          failureSummary: nil,
          activity: record.running ? .preparing : nil,
          backgroundJobCount: 0
        )
      }
      assignPrivacyAlias(to: record.id)
    }

    connected = true
    connectionMessage = nil
    expireTransientState(at: now)
  }

  /// Marks the list baseline unavailable while retaining private recovery state.
  public mutating func markDisconnected(_ message: String?, now: Date = Date()) {
    connected = false
    connectionMessage = boundedText(message, limit: 120)
    expireTransientState(at: now)
  }

  /// Applies one frame from `/api/events.host`.
  public mutating func applyHost(_ envelope: DSHStreamEnvelope, now: Date = Date()) {
    guard let type = envelope.type else { return }
    let payload = envelope.payload
    switch type {
    case "host/session-added":
      guard let id = payload["sessionId"]?.stringValue else { return }
      if sessions[id] == nil {
        sessions[id] = SessionState(
          id: id,
          updatedAt: now,
          running: false,
          blank: payload["blank"]?.boolValue ?? true,
          parentSessionID: payload["parentSessionId"]?.stringValue,
          isSubagent: payload["origin"]?.stringValue == "subagent",
          workingDirectory: boundedText(payload["cwd"]?.stringValue, limit: 512),
          title: nil,
          todos: nil,
          projectionSequences: [:],
          startedAt: nil,
          completedAt: nil,
          failedAt: nil,
          failureSummary: nil,
          activity: nil,
          backgroundJobCount: 0
        )
        assignPrivacyAlias(to: id)
      }
    case "host/session-removed":
      guard let id = payload["sessionId"]?.stringValue else { return }
      sessions.removeValue(forKey: id)
      clearInteractions(for: id)
    case "host/session-status":
      guard let id = payload["sessionId"]?.stringValue,
        let running = payload["running"]?.boolValue,
        var state = sessions[id]
      else { return }
      let wasRunning = state.running
      state.running = running
      if running { state.blank = false }
      state.updatedAt = max(state.updatedAt, now)
      if !wasRunning, running {
        beginRun(&state, at: now)
      } else if wasRunning, !running {
        completeRun(&state, at: now)
        clearInteractions(for: id)
      }
      sessions[id] = state
    case "host/agent-error":
      guard let id = payload["sessionId"]?.stringValue,
        var state = sessions[id]
      else { return }
      state.failedAt = now
      state.failureSummary = boundedText(payload["message"]?.stringValue, limit: 100)
      state.updatedAt = max(state.updatedAt, now)
      sessions[id] = state
    default:
      break
    }
    expireTransientState(at: now)
  }

  /// Applies one frame from `/api/events.mux`.
  public mutating func applyMux(_ envelope: DSHStreamEnvelope, now: Date = Date()) {
    guard let type = envelope.type else { return }
    let payload = envelope.payload
    switch type {
    case "approval/requested":
      guard let id = payload["approvalId"]?.stringValue,
        let sessionID = payload["sessionId"]?.stringValue
      else { return }
      let toolName = boundedText(payload["toolName"]?.stringValue, limit: 32)
      approvals[id] = PendingInteraction(sessionID: sessionID, kind: .approval(toolName: toolName))
    case "approval/resolved":
      guard let id = payload["approvalId"]?.stringValue else { return }
      approvals.removeValue(forKey: id)
    case "question/requested":
      guard let id = envelope.rpcID,
        let sessionID = payload["sessionId"]?.stringValue
      else { return }
      questions[id] = PendingInteraction(sessionID: sessionID, kind: .question)
    case "question/resolved":
      guard let id = payload["questionRpcId"]?.stringValue else { return }
      questions.removeValue(forKey: id)
    case "session/projection":
      applyProjection(payload)
    case "session/jobs":
      applyJobs(payload)
    case "session/event":
      applySessionEvent(payload, now: now)
    default:
      break
    }
    expireTransientState(at: now)
  }

  /// Produces the only presentation state exposed to the app.
  public mutating func snapshot(now: Date = Date()) -> IslandSnapshot {
    expireTransientState(at: now)
    let visible = sessions.values.filter { !$0.blank }
    var renderedByID: [String: SessionDisplayItem] = [:]
    renderedByID.reserveCapacity(visible.count)

    for state in visible {
      let interaction = interaction(for: state.id)
      let status = status(of: state, interaction: interaction, now: now)
      let title = displayTitle(for: state)
      let progress = todoProgress(state.todos)
      renderedByID[state.id] = SessionDisplayItem(
        id: state.id,
        title: title,
        status: status,
        interaction: privacyMode ? redact(interaction) : interaction,
        activity: privacyMode ? redact(state.activity) : state.activity,
        progress: privacyMode ? redact(progress) : progress,
        failureSummary: privacyMode ? nil : state.failureSummary,
        startedAt: state.startedAt,
        completedAt: state.completedAt,
        updatedAt: state.updatedAt,
        depth: 0,
        backgroundJobCount: state.backgroundJobCount
      )
    }

    let ordered = orderedRows(renderedByID)
    let counts = IslandCounts(
      attention: ordered.filter { $0.status == .attention }.count,
      failure: ordered.filter { $0.status == .failure }.count,
      running: ordered.filter { $0.status == .running }.count,
      completed: ordered.filter { $0.status == .completed }.count,
      idle: ordered.filter { $0.status == .idle }.count
    )
    let aggregate = aggregateStatus(counts: counts)

    return IslandSnapshot(
      aggregateStatus: aggregate,
      counts: counts,
      sessions: ordered,
      connected: connected,
      connectionMessage: connected || privacyMode ? nil : connectionMessage
    )
  }

  private func shouldApplyBaselineProjection(
    key: String,
    present: Bool,
    sequence: Int?,
    to state: SessionState
  ) -> Bool {
    guard present else { return false }
    if let sequence, let current = state.projectionSequences[key], sequence < current {
      return false
    }
    return true
  }

  private mutating func applyProjection(_ payload: JSONValue) {
    guard let id = payload["sessionId"]?.stringValue,
      let key = payload["key"]?.stringValue,
      let sequence = payload["seq"]?.intValue,
      let value = payload["value"],
      var state = sessions[id]
    else { return }
    if let current = state.projectionSequences[key], sequence <= current { return }

    switch key {
    case "title":
      state.title = normalizedOptionalText(value.stringValue).map {
        boundedText($0, limit: 80) ?? $0
      }
    case "todos":
      state.todos = DSHWireDecoder.decodeTodos(value)
    default:
      return
    }
    state.projectionSequences[key] = sequence
    sessions[id] = state
  }

  private mutating func applyJobs(_ payload: JSONValue) {
    guard let id = payload["sessionId"]?.stringValue,
      let jobs = payload["jobs"]?.arrayValue,
      var state = sessions[id]
    else { return }
    state.backgroundJobCount = jobs.count { row in
      let status = row["status"]?.stringValue
      return status == "running" || status == "stopping"
    }
    sessions[id] = state
  }

  private mutating func applySessionEvent(_ payload: JSONValue, now: Date) {
    guard let id = payload["sessionId"]?.stringValue,
      let event = payload["event"],
      let type = event["type"]?.stringValue,
      var state = sessions[id]
    else { return }
    let data = event["data"]
    state.updatedAt = max(state.updatedAt, now)

    switch type {
    case "turn/start":
      state.startedAt = now
      state.completedAt = nil
      state.failedAt = nil
      state.failureSummary = nil
      state.activity = .preparing
    case "assistant/chunk":
      let chunkType = data?["chunk"]?["type"]?.stringValue?.lowercased() ?? ""
      state.activity = chunkType.contains("reason") ? .reasoning : .writing
    case "assistant/message":
      state.activity = .writing
    case "tool/call":
      let name = data?["name"]?.stringValue ?? "tool"
      state.activity = .usingTool(ToolCategory.classify(name))
    case "tool/result":
      state.activity = .reviewingResult
    case "turn/end":
      let reasonKind = data?["reason"]?["kind"]?.stringValue
      if reasonKind == "completed" {
        state.completedAt = now
        state.activity = nil
      } else if reasonKind == "error" {
        state.failedAt = now
        state.failureSummary = boundedText(
          data?["reason"]?["error"]?["message"]?.stringValue, limit: 100)
        state.activity = nil
      } else {
        state.activity = .stopped
      }
    default:
      break
    }
    sessions[id] = state
  }

  private mutating func beginRun(_ state: inout SessionState, at now: Date) {
    state.startedAt = now
    state.completedAt = nil
    state.failedAt = nil
    state.failureSummary = nil
    state.activity = .preparing
  }

  private func completeRun(_ state: inout SessionState, at now: Date) {
    state.completedAt = now
    state.activity = nil
  }

  private mutating func clearInteractions(for sessionID: String) {
    approvals = approvals.filter { $0.value.sessionID != sessionID }
    questions = questions.filter { $0.value.sessionID != sessionID }
  }

  private func interaction(for sessionID: String) -> InteractionKind? {
    if let approval = approvals.values.first(where: { $0.sessionID == sessionID }) {
      return approval.kind
    }
    return questions.values.first(where: { $0.sessionID == sessionID })?.kind
  }

  private func status(of state: SessionState, interaction: InteractionKind?, now: Date)
    -> IslandStatus
  {
    if interaction != nil { return .attention }
    if let failedAt = state.failedAt, now.timeIntervalSince(failedAt) <= failureLifetime {
      return .failure
    }
    if state.running { return .running }
    if let completedAt = state.completedAt, now.timeIntervalSince(completedAt) <= completionLifetime
    {
      return .completed
    }
    return .idle
  }

  private func todoProgress(_ todos: [TodoItem]?) -> TodoProgress? {
    guard let todos, !todos.isEmpty else { return nil }
    return TodoProgress(
      completed: todos.filter { $0.status == .completed }.count,
      total: todos.count,
      activeItem: todos.first { $0.status == .inProgress }.flatMap {
        boundedText($0.content, limit: 90)
      }
    )
  }

  private func redact(_ interaction: InteractionKind?) -> InteractionKind? {
    guard let interaction else { return nil }
    switch interaction {
    case .approval: return .approval(toolName: nil)
    case .question: return .question
    }
  }

  private func redact(_ progress: TodoProgress?) -> TodoProgress? {
    guard let progress else { return nil }
    return TodoProgress(completed: progress.completed, total: progress.total, activeItem: nil)
  }

  private func redact(_ activity: ActivityKind?) -> ActivityKind? {
    guard case .usingTool(let category) = activity else { return activity }
    if case .other = category { return .usingTool(.other("tool")) }
    return activity
  }

  private mutating func assignPrivacyAlias(to id: String) {
    guard privacyAliases[id] == nil else { return }
    privacyAliases[id] = nextPrivacyAlias
    nextPrivacyAlias += 1
  }

  private mutating func displayTitle(for state: SessionState) -> String {
    if privacyMode {
      assignPrivacyAlias(to: state.id)
      return "Session \(privacyAliases[state.id] ?? 0)"
    }
    if let title = boundedText(state.title, limit: 80) { return title }
    if let path = state.workingDirectory {
      let name = URL(fileURLWithPath: path).lastPathComponent
      if let bounded = boundedText(name, limit: 80) { return bounded }
    }
    return "Session \(state.id.prefix(8))"
  }

  private func orderedRows(_ rows: [String: SessionDisplayItem]) -> [SessionDisplayItem] {
    let visibleIDs = Set(rows.keys)
    var children: [String: [String]] = [:]
    var roots: [String] = []
    for id in visibleIDs {
      guard let state = sessions[id],
        state.isSubagent,
        let parent = state.parentSessionID,
        visibleIDs.contains(parent),
        parent != id
      else {
        roots.append(id)
        continue
      }
      children[parent, default: []].append(id)
    }

    func groupPriority(_ id: String, visiting: inout Set<String>) -> Int {
      guard visiting.insert(id).inserted else {
        return rows[id]?.status.priority ?? IslandStatus.idle.priority
      }
      var priority = rows[id]?.status.priority ?? IslandStatus.idle.priority
      for child in children[id] ?? [] {
        priority = min(priority, groupPriority(child, visiting: &visiting))
      }
      visiting.remove(id)
      return priority
    }

    roots.sort { lhs, rhs in
      var lhsVisited = Set<String>()
      var rhsVisited = Set<String>()
      let lhsPriority = groupPriority(lhs, visiting: &lhsVisited)
      let rhsPriority = groupPriority(rhs, visiting: &rhsVisited)
      if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
      let lhsDate = rows[lhs]?.updatedAt ?? .distantPast
      let rhsDate = rows[rhs]?.updatedAt ?? .distantPast
      if lhsDate != rhsDate { return lhsDate > rhsDate }
      return lhs < rhs
    }

    var result: [SessionDisplayItem] = []
    var emitted = Set<String>()
    func appendTree(_ id: String, depth: Int) {
      guard emitted.insert(id).inserted, let row = rows[id] else { return }
      result.append(
        SessionDisplayItem(
          id: row.id,
          title: row.title,
          status: row.status,
          interaction: row.interaction,
          activity: row.activity,
          progress: row.progress,
          failureSummary: row.failureSummary,
          startedAt: row.startedAt,
          completedAt: row.completedAt,
          updatedAt: row.updatedAt,
          depth: min(depth, 4),
          backgroundJobCount: row.backgroundJobCount
        ))
      let sortedChildren = (children[id] ?? []).sorted { lhs, rhs in
        guard let left = rows[lhs], let right = rows[rhs] else { return lhs < rhs }
        if left.status.priority != right.status.priority {
          return left.status.priority < right.status.priority
        }
        if left.updatedAt != right.updatedAt { return left.updatedAt > right.updatedAt }
        return lhs < rhs
      }
      for child in sortedChildren { appendTree(child, depth: depth + 1) }
    }

    for root in roots { appendTree(root, depth: 0) }
    for orphan in visibleIDs.subtracting(emitted).sorted() { appendTree(orphan, depth: 0) }
    return result
  }

  private func aggregateStatus(counts: IslandCounts) -> IslandStatus {
    guard connected else { return .offline }
    if counts.attention > 0 { return .attention }
    if counts.failure > 0 { return .failure }
    if counts.running > 0 { return .running }
    if counts.completed > 0 { return .completed }
    return .idle
  }

  private mutating func expireTransientState(at now: Date) {
    for id in sessions.keys {
      guard var state = sessions[id] else { continue }
      if let completedAt = state.completedAt,
        now.timeIntervalSince(completedAt) > completionLifetime
      {
        state.completedAt = nil
      }
      if let failedAt = state.failedAt,
        now.timeIntervalSince(failedAt) > failureLifetime
      {
        state.failedAt = nil
        state.failureSummary = nil
      }
      sessions[id] = state
    }
  }
}

func boundedText(_ rawText: String?, limit: Int) -> String? {
  guard let rawText else { return nil }
  let collapsed =
    rawText
    .split(whereSeparator: { $0.isWhitespace })
    .joined(separator: " ")
  guard !collapsed.isEmpty else { return nil }
  if collapsed.count <= limit { return collapsed }
  return String(collapsed.prefix(max(1, limit - 1))) + "…"
}
