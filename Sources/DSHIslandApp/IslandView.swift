import AppKit
import DSHIslandCore
import SwiftUI

private enum IslandPalette {
  static let running = Color(red: 0.33, green: 0.84, blue: 1.00)
  static let attention = Color(red: 1.00, green: 0.72, blue: 0.30)
  static let failure = Color(red: 1.00, green: 0.40, blue: 0.37)
  static let completed = Color(red: 0.38, green: 0.90, blue: 0.65)
  static let idle = Color(red: 0.54, green: 0.58, blue: 0.64)
  static let offline = Color(red: 0.49, green: 0.52, blue: 0.60)
  static let surfaceTop = Color(red: 0.055, green: 0.071, blue: 0.10)
  static let surfaceBottom = Color(red: 0.018, green: 0.024, blue: 0.038)

  static func color(for status: IslandStatus) -> Color {
    switch status {
    case .attention: return attention
    case .failure: return failure
    case .running: return running
    case .completed: return completed
    case .idle: return idle
    case .offline: return offline
    }
  }

  static func symbol(for status: IslandStatus) -> String {
    switch status {
    case .attention: return "exclamationmark"
    case .failure: return "xmark"
    case .running: return "waveform.path"
    case .completed: return "checkmark"
    case .idle: return "minus"
    case .offline: return "bolt.slash"
    }
  }
}

/// The collapsed capsule and expanded all-session instrument.
struct IslandView: View {
  @ObservedObject var model: IslandViewModel
  let openSettings: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    VStack(spacing: 0) {
      header
        .frame(height: 68)
      if model.isExpanded {
        SignalRail(snapshot: model.snapshot)
          .padding(.horizontal, 18)
          .transition(.opacity)
        sessionList
          .transition(.opacity.combined(with: .move(edge: .top)))
        toolbar
          .transition(.opacity)
      }
    }
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: model.isExpanded ? 28 : 34, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: model.isExpanded ? 28 : 34, style: .continuous)
        .strokeBorder(
          Color.white.opacity(contrast == .increased ? 0.34 : 0.13),
          lineWidth: contrast == .increased ? 1.5 : 1
        )
    }
    .animation(
      reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.86),
      value: model.isExpanded
    )
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    HStack(spacing: 13) {
      BrandMark(status: model.snapshot.aggregateStatus)

      VStack(alignment: .leading, spacing: 3) {
        Text(aggregateTitle)
          .font(.system(size: 15, weight: .semibold, design: .serif))
          .foregroundStyle(.white)
          .lineLimit(1)
        Text(aggregateSubtitle)
          .font(.system(size: 10.5, weight: .medium, design: .monospaced))
          .foregroundStyle(IslandPalette.color(for: model.snapshot.aggregateStatus))
          .textCase(.uppercase)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      if !model.isExpanded {
        SignalRail(snapshot: model.snapshot)
          .frame(width: 82)
      }

      Image(systemName: model.isExpanded ? "chevron.up" : "chevron.down")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white.opacity(0.72))
        .frame(width: 30, height: 30)
        .background(Color.white.opacity(0.07), in: Circle())
        .contentShape(Circle())
        .accessibilityHidden(true)
    }
    .padding(.horizontal, 17)
    .contentShape(Rectangle())
    .onTapGesture {
      model.toggleExpanded()
    }
    .accessibilityHint(model.isExpanded ? "Collapse" : "Show all sessions")
    .accessibilityAddTraits(.isButton)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(aggregateAccessibilityLabel)
  }

  private var sessionList: some View {
    ScrollView {
      LazyVStack(spacing: 7) {
        if model.snapshot.sessions.isEmpty {
          VStack(spacing: 9) {
            Image(
              systemName: model.snapshot.connected
                ? "moon.stars" : "antenna.radiowaves.left.and.right.slash"
            )
            .font(.system(size: 21, weight: .light))
            .foregroundStyle(.secondary)
            Text(model.snapshot.connected ? "No sessions yet" : "Waiting for DSH")
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 46)
        } else {
          ForEach(model.snapshot.sessions) { session in
            Button {
              model.openDSH(sessionID: session.id)
            } label: {
              SessionRow(session: session)
            }
            .buttonStyle(.plain)
            .help("Open this session in DSH")
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
    }
    .frame(maxHeight: .infinity)
  }

  private var toolbar: some View {
    HStack(spacing: 5) {
      ToolbarButton(symbol: "arrow.clockwise", label: "Refresh") { model.refreshNow() }
      ToolbarButton(symbol: "arrow.up.right.square", label: "Open DSH") { model.openDSH() }
      ToolbarButton(symbol: "gearshape", label: "Settings", action: openSettings)
      Spacer()
      Text("READ ONLY")
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .tracking(1.2)
        .foregroundStyle(.white.opacity(0.33))
      ToolbarButton(symbol: "chevron.up", label: "Collapse") { model.toggleExpanded() }
    }
    .padding(.horizontal, 13)
    .frame(height: 48)
    .background(Color.white.opacity(0.025))
    .overlay(alignment: .top) {
      Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }
  }

  private var background: some View {
    ZStack {
      VisualEffectView()
      LinearGradient(
        colors: [
          IslandPalette.surfaceTop.opacity(0.96), IslandPalette.surfaceBottom.opacity(0.985),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      RadialGradient(
        colors: [IslandPalette.color(for: model.snapshot.aggregateStatus).opacity(0.10), .clear],
        center: .topLeading,
        startRadius: 0,
        endRadius: 270
      )
    }
  }

  private var aggregateTitle: String {
    let counts = model.snapshot.counts
    switch model.snapshot.aggregateStatus {
    case .attention:
      return counts.attention == 1 ? "1 session needs you" : "\(counts.attention) sessions need you"
    case .failure:
      return counts.failure == 1 ? "1 session failed" : "\(counts.failure) sessions failed"
    case .running:
      return counts.running == 1 ? "1 session working" : "\(counts.running) sessions working"
    case .completed:
      return counts.completed == 1
        ? "1 session completed" : "\(counts.completed) sessions completed"
    case .idle:
      return "DSH is standing by"
    case .offline:
      return "DSH is offline"
    }
  }

  private var aggregateSubtitle: String {
    let counts = model.snapshot.counts
    if !model.snapshot.connected { return "Retrying local endpoint" }
    let active = counts.attention + counts.failure + counts.running
    if active > 0 {
      let total = model.snapshot.sessions.count
      return "\(active) active · \(total) visible"
    }
    if counts.completed > 0 { return "Recently settled" }
    return "Connection nominal"
  }

  private var aggregateAccessibilityLabel: String {
    let counts = model.snapshot.counts
    return
      "\(aggregateTitle). \(counts.attention) need attention, \(counts.failure) failed, \(counts.running) running, \(counts.completed) recently completed."
  }
}

private struct BrandMark: View {
  let status: IslandStatus

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 11, style: .continuous)
        .fill(Color.white.opacity(0.055))
      RoundedRectangle(cornerRadius: 11, style: .continuous)
        .strokeBorder(IslandPalette.color(for: status).opacity(0.42), lineWidth: 1)
      VStack(spacing: 2) {
        HStack(spacing: 2) {
          ForEach(0..<3, id: \.self) { index in
            Capsule()
              .fill(index == 0 ? IslandPalette.color(for: status) : Color.white.opacity(0.24))
              .frame(width: index == 0 ? 11 : 5, height: 3)
          }
        }
        Text("DSH")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .tracking(0.6)
          .foregroundStyle(.white.opacity(0.88))
      }
    }
    .frame(width: 42, height: 42)
    .accessibilityHidden(true)
  }
}

private struct SignalRail: View {
  let snapshot: IslandSnapshot

  var body: some View {
    GeometryReader { proxy in
      let statuses = Array(displayStatuses.prefix(18))
      let spacing: CGFloat = 3
      let totalSpacing = spacing * CGFloat(max(0, statuses.count - 1))
      let segmentWidth = max(3, (proxy.size.width - totalSpacing) / CGFloat(max(1, statuses.count)))
      HStack(spacing: spacing) {
        ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
          Capsule()
            .fill(IslandPalette.color(for: status))
            .frame(width: segmentWidth, height: 4)
            .shadow(color: IslandPalette.color(for: status).opacity(0.34), radius: 3)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(height: 4)
    .accessibilityHidden(true)
  }

  private var displayStatuses: [IslandStatus] {
    if !snapshot.connected { return [.offline] }
    let statuses = snapshot.sessions.map(\.status).sorted { priority($0) < priority($1) }
    return statuses.isEmpty ? [.idle] : statuses
  }

  private func priority(_ status: IslandStatus) -> Int {
    switch status {
    case .attention: return 0
    case .failure: return 1
    case .running: return 2
    case .completed: return 3
    case .idle: return 4
    case .offline: return 5
    }
  }
}

private struct SessionRow: View {
  let session: SessionDisplayItem

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      HStack(alignment: .top, spacing: 11) {
        StatusGlyph(status: session.status)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(session.title)
              .font(.system(size: 13.5, weight: .semibold))
              .foregroundStyle(.white.opacity(0.94))
              .lineLimit(1)
            Spacer(minLength: 5)
            Text(statusText)
              .font(.system(size: 9.5, weight: .bold, design: .monospaced))
              .tracking(0.4)
              .foregroundStyle(IslandPalette.color(for: session.status))
          }

          HStack(spacing: 6) {
            Text(detailText)
              .font(.system(size: 11.5, weight: .regular))
              .foregroundStyle(.white.opacity(0.56))
              .lineLimit(1)
            Spacer(minLength: 4)
            Text(elapsedText(now: context.date))
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(.white.opacity(0.38))
          }

          if let progress = session.progress {
            HStack(spacing: 8) {
              ProgressRail(
                fraction: progress.fraction,
                color: IslandPalette.color(for: session.status)
              )
              Text("\(progress.completed)/\(progress.total)")
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.46))
            }
          } else if session.status == .running {
            HStack(spacing: 7) {
              ProgressView()
                .controlSize(.mini)
              Text("Progress not published")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.36))
            }
          }
        }
      }
      .padding(.leading, CGFloat(session.depth) * 18)
      .padding(.horizontal, 11)
      .padding(.vertical, 10)
      .background(rowBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
          .strokeBorder(IslandPalette.color(for: session.status).opacity(0.12), lineWidth: 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        "\(session.title), \(statusText), \(detailText), \(elapsedText(now: context.date))")
    }
  }

  private var rowBackground: Color {
    switch session.status {
    case .attention, .failure:
      return IslandPalette.color(for: session.status).opacity(0.07)
    default:
      return Color.white.opacity(0.035)
    }
  }

  private var statusText: String {
    switch session.status {
    case .attention: return "NEEDS YOU"
    case .failure: return "FAILED"
    case .running: return "WORKING"
    case .completed: return "COMPLETE"
    case .idle: return "IDLE"
    case .offline: return "OFFLINE"
    }
  }

  private var detailText: String {
    if let interaction = session.interaction {
      switch interaction {
      case .approval(let toolName):
        return toolName.map { "Approval requested · \($0)" } ?? "Approval requested"
      case .question:
        return "Waiting for an answer"
      }
    }
    if let failure = session.failureSummary { return failure }
    if let progress = session.progress, let item = progress.activeItem { return item }
    if let activity = session.activity { return activityText(activity) }
    if session.backgroundJobCount > 0 {
      return
        "\(session.backgroundJobCount) background job\(session.backgroundJobCount == 1 ? "" : "s")"
    }
    switch session.status {
    case .completed: return "Run settled"
    case .failure: return "Agent reported an error"
    case .running: return "Agent is working"
    case .idle: return "Standing by"
    case .attention: return "Input required"
    case .offline: return "Connection unavailable"
    }
  }

  private func activityText(_ activity: ActivityKind) -> String {
    switch activity {
    case .preparing: return "Preparing the next step"
    case .reasoning: return "Reasoning"
    case .writing: return "Writing a response"
    case .usingTool(let category):
      switch category {
      case .command: return "Running a command"
      case .inspectingFiles: return "Inspecting files"
      case .editingFiles: return "Editing files"
      case .web: return "Researching the web"
      case .agents: return "Coordinating agents"
      case .code: return "Running code"
      case .other(let name): return "Using \(name)"
      }
    case .reviewingResult: return "Reviewing a tool result"
    case .stopped: return "Run stopped"
    }
  }

  private func elapsedText(now: Date) -> String {
    let anchor: Date
    switch session.status {
    case .running, .attention:
      anchor = session.startedAt ?? session.updatedAt
    case .completed:
      anchor = session.completedAt ?? session.updatedAt
    default:
      anchor = session.updatedAt
    }
    let seconds = max(0, Int(now.timeIntervalSince(anchor)))
    if seconds < 60 { return "\(seconds)s" }
    if seconds < 3_600 { return "\(seconds / 60)m" }
    let hours = seconds / 3_600
    let minutes = (seconds % 3_600) / 60
    return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
  }
}

private struct ProgressRail: View {
  let fraction: Double
  let color: Color

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.13))
        Capsule()
          .fill(color)
          .frame(width: max(4, proxy.size.width * min(max(fraction, 0), 1)))
          .shadow(color: color.opacity(0.28), radius: 3)
      }
    }
    .frame(height: 4)
    .accessibilityHidden(true)
  }
}

private struct StatusGlyph: View {
  let status: IslandStatus

  var body: some View {
    ZStack {
      Circle().fill(IslandPalette.color(for: status).opacity(0.13))
      Circle().strokeBorder(IslandPalette.color(for: status).opacity(0.34), lineWidth: 1)
      Image(systemName: IslandPalette.symbol(for: status))
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(IslandPalette.color(for: status))
    }
    .frame(width: 29, height: 29)
    .accessibilityHidden(true)
  }
}

private struct ToolbarButton: View {
  let symbol: String
  let label: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.62))
        .frame(width: 28, height: 28)
        .background(Color.white.opacity(0.045), in: Circle())
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
  }
}

private struct VisualEffectView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
