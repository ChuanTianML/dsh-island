import AppKit
import DSHIslandCore
import SwiftUI

/// The collapsed capsule and expanded all-session instrument.
struct IslandView: View {
  @ObservedObject var model: IslandViewModel
  @ObservedObject var preferences: PreferencesStore
  let openSettings: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  private var theme: IslandTheme { preferences.theme }

  var body: some View {
    VStack(spacing: 0) {
      header
        .frame(height: CGFloat(theme.metrics.collapsedHeight))
      if model.isExpanded {
        AggregateSummary(snapshot: model.snapshot, theme: theme)
          .frame(height: CGFloat(theme.metrics.summaryHeight))
          .padding(.horizontal, CGFloat(theme.metrics.headerPadding))
          .transition(.opacity)
        sessionList
          .transition(.opacity.combined(with: .move(edge: .top)))
        toolbar
          .transition(.opacity)
      }
    }
    .background { IslandBackground(theme: theme, status: model.snapshot.aggregateStatus) }
    .clipShape(islandShape)
    .overlay {
      islandShape.strokeBorder(
        (contrast == .increased ? theme.palette.borderHighContrast : theme.palette.border)
          .swiftUIColor,
        lineWidth: contrast == .increased ? 1.5 : 1)
    }
    .animation(expansionAnimation, value: model.isExpanded)
    .animation(themeAnimation, value: theme)
    .preferredColorScheme(theme.preferredColorScheme)
  }

  private var islandShape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: CGFloat(
        model.isExpanded
          ? theme.metrics.expandedCornerRadius : theme.metrics.collapsedCornerRadius),
      style: .continuous)
  }

  private var expansionAnimation: Animation? {
    reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.86)
  }

  private var themeAnimation: Animation? {
    reduceMotion ? nil : .easeInOut(duration: 0.24)
  }

  private var header: some View {
    HStack(spacing: max(10, CGFloat(theme.metrics.headerPadding) * 0.76)) {
      WhaleMark(theme: theme, status: model.snapshot.aggregateStatus)

      VStack(alignment: .leading, spacing: theme == .editorial ? 1 : 3) {
        Text(aggregateTitle)
          .font(
            theme.typography.titleFace.swiftUIFont(
              size: theme.typography.titleSize,
              weight: theme.typography.titleWeight))
          .foregroundStyle(theme.palette.primaryText.swiftUIColor)
          .lineLimit(1)
          .minimumScaleFactor(0.82)
          .allowsTightening(true)
        Text(styledSubtitle)
          .font(
            theme.typography.subtitleFace.swiftUIFont(
              size: theme.typography.subtitleSize,
              weight: .medium))
          .tracking(CGFloat(theme.typography.subtitleTracking))
          .foregroundStyle(theme.palette.color(for: model.snapshot.aggregateStatus).swiftUIColor)
          .lineLimit(1)
      }
      .layoutPriority(1)

      Spacer(minLength: 8)

      if !model.isExpanded {
        AggregateSummary(snapshot: model.snapshot, theme: theme)
          .frame(
            minWidth: 54,
            idealWidth: max(70, CGFloat(theme.metrics.collapsedWidth) * 0.205),
            maxWidth: max(70, CGFloat(theme.metrics.collapsedWidth) * 0.205))
          .frame(height: max(4, CGFloat(theme.metrics.summaryHeight)))
      }

      Image(systemName: model.isExpanded ? "chevron.up" : "chevron.down")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(theme.palette.primaryText.swiftUIColor.opacity(0.72))
        .frame(width: 30, height: 30)
        .background(theme.palette.controlFill.swiftUIColor, in: Circle())
        .contentShape(Circle())
        .accessibilityHidden(true)
    }
    .padding(.horizontal, CGFloat(theme.metrics.headerPadding))
    .overlay(alignment: .bottom) {
      if theme.chrome.showsHeaderSeparator {
        Rectangle()
          .fill(theme.palette.separator.swiftUIColor)
          .frame(height: 1)
          .padding(.horizontal, CGFloat(theme.metrics.headerPadding))
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { model.toggleExpanded() }
    .accessibilityHint(model.isExpanded ? "Collapse" : "Show all sessions")
    .accessibilityAddTraits(.isButton)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(aggregateAccessibilityLabel)
  }

  private var sessionList: some View {
    ScrollView {
      LazyVStack(spacing: CGFloat(theme.metrics.rowSpacing)) {
        if model.snapshot.sessions.isEmpty {
          VStack(spacing: 9) {
            Image(
              systemName: model.snapshot.connected
                ? "moon.stars" : "antenna.radiowaves.left.and.right.slash"
            )
            .font(.system(size: 21, weight: .light))
            .foregroundStyle(theme.palette.tertiaryText.swiftUIColor)
            Text(model.snapshot.connected ? "No sessions yet" : "Waiting for DSH")
              .font(
                theme.typography.rowTitleFace.swiftUIFont(
                  size: theme.typography.rowTitleSize,
                  weight: theme.typography.rowTitleWeight))
              .foregroundStyle(theme.palette.secondaryText.swiftUIColor)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 46)
        } else {
          ForEach(Array(model.snapshot.sessions.enumerated()), id: \.element.id) { index, session in
            Button {
              model.openDSH(sessionID: session.id)
            } label: {
              SessionRow(session: session, index: index, theme: theme)
            }
            .buttonStyle(.plain)
            .help("Open this session in DSH")
          }
        }
      }
      .padding(.horizontal, CGFloat(theme.metrics.listPadding))
      .padding(.vertical, CGFloat(theme.metrics.listVerticalPadding))
    }
    .frame(maxHeight: .infinity)
  }

  private var toolbar: some View {
    HStack(spacing: 5) {
      ToolbarButton(symbol: "arrow.clockwise", label: "Refresh", theme: theme) {
        model.refreshNow()
      }
      ToolbarButton(symbol: "arrow.up.right.square", label: "Open DSH", theme: theme) {
        model.openDSH()
      }
      ToolbarButton(symbol: "gearshape", label: "Settings", theme: theme, action: openSettings)
      Spacer()
      if theme.chrome.showsToolbarNote {
        Text("READ ONLY")
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .tracking(1.2)
          .foregroundStyle(theme.palette.tertiaryText.swiftUIColor)
      }
      ToolbarButton(symbol: "chevron.up", label: "Collapse", theme: theme) {
        model.toggleExpanded()
      }
    }
    .padding(.horizontal, max(12, CGFloat(theme.metrics.listPadding)))
    .frame(height: CGFloat(theme.metrics.toolbarHeight))
    .background(theme.palette.controlFill.swiftUIColor.opacity(0.42))
    .overlay(alignment: .top) {
      Rectangle().fill(theme.palette.separator.swiftUIColor).frame(height: 1)
    }
  }

  private var styledSubtitle: String {
    theme.typography.subtitleUppercase ? aggregateSubtitle.uppercased() : aggregateSubtitle
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

private struct IslandBackground: View {
  let theme: IslandTheme
  let status: IslandStatus

  var body: some View {
    ZStack {
      if theme.chrome.usesBackgroundBlur {
        VisualEffectView()
      }
      LinearGradient(
        colors: [
          theme.palette.surfaceTop.swiftUIColor,
          theme.palette.surfaceBottom.swiftUIColor,
        ],
        startPoint: .top,
        endPoint: .bottom)
      RadialGradient(
        colors: [
          theme.palette.color(for: status).swiftUIColor.opacity(theme.palette.accentRowOpacity),
          .clear,
        ],
        center: .topLeading,
        startRadius: 0,
        endRadius: CGFloat(theme.metrics.expandedWidth) * 0.54)
    }
  }
}

private struct WhaleMark: View {
  let theme: IslandTheme
  let status: IslandStatus

  var body: some View {
    ZStack {
      RoundedRectangle(
        cornerRadius: CGFloat(theme.metrics.brandCornerRadius),
        style: .continuous
      )
      .fill(theme.palette.brandFill.swiftUIColor)
      RoundedRectangle(
        cornerRadius: CGFloat(theme.metrics.brandCornerRadius),
        style: .continuous
      )
      .strokeBorder(
        (theme.palette.brandStroke ?? theme.palette.color(for: status).withOpacity(0.42))
          .swiftUIColor,
        lineWidth: 1)
      WhaleShape()
        .fill(theme.palette.whaleFill.swiftUIColor)
        .padding(CGFloat(theme.metrics.brandTileSize) * 0.19)
    }
    .frame(
      width: CGFloat(theme.metrics.brandTileSize),
      height: CGFloat(theme.metrics.brandTileSize))
    .accessibilityHidden(true)
  }
}

private struct AggregateSummary: View {
  let snapshot: IslandSnapshot
  let theme: IslandTheme

  var body: some View {
    Group {
      switch theme.chrome.summaryVisual {
      case .signalRail:
        SignalRail(statuses: displayStatuses, theme: theme)
      case .constellation:
        ConstellationSummary(statuses: displayStatuses, theme: theme)
      case .orbit:
        OrbitSummary(statuses: displayStatuses, theme: theme)
      case .count:
        CountSummary(snapshot: snapshot, statuses: displayStatuses, theme: theme)
      case .veins:
        VeinSummary(statuses: displayStatuses, theme: theme)
      }
    }
    .accessibilityHidden(true)
  }

  private var displayStatuses: [IslandStatus] {
    if !snapshot.connected { return [.offline] }
    let statuses = snapshot.sessions.map(\.status).sorted { statusPriority($0) < statusPriority($1) }
    return statuses.isEmpty ? [.idle] : statuses
  }
}

private struct SignalRail: View {
  let statuses: [IslandStatus]
  let theme: IslandTheme

  var body: some View {
    GeometryReader { proxy in
      let visible = Array(statuses.prefix(18))
      let spacing: CGFloat = 3
      let totalSpacing = spacing * CGFloat(max(0, visible.count - 1))
      let width = max(3, (proxy.size.width - totalSpacing) / CGFloat(max(1, visible.count)))
      HStack(spacing: spacing) {
        ForEach(Array(visible.enumerated()), id: \.offset) { _, status in
          Capsule()
            .fill(theme.palette.color(for: status).swiftUIColor)
            .frame(width: width, height: min(4, proxy.size.height))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

private struct ConstellationSummary: View {
  let statuses: [IslandStatus]
  let theme: IslandTheme

  var body: some View {
    Canvas { context, size in
      let visible = Array(statuses.prefix(12))
      let count = max(1, visible.count)
      var connector = Path()
      for (index, status) in visible.enumerated() {
        let fraction = count == 1 ? 0.5 : CGFloat(index) / CGFloat(count - 1)
        let point = CGPoint(
          x: 2 + fraction * max(0, size.width - 4),
          y: size.height * (index.isMultiple(of: 2) ? 0.35 : 0.65))
        if index == 0 { connector.move(to: point) } else { connector.addLine(to: point) }
        let diameter = max(3, min(5, size.height * 0.7))
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: point.x - diameter / 2,
              y: point.y - diameter / 2,
              width: diameter,
              height: diameter)),
          with: .color(theme.palette.color(for: status).swiftUIColor))
      }
      context.stroke(
        connector,
        with: .color(theme.palette.separator.swiftUIColor),
        lineWidth: 1)
    }
  }
}

private struct OrbitSummary: View {
  let statuses: [IslandStatus]
  let theme: IslandTheme

  var body: some View {
    Canvas { context, size in
      let centerX = size.width / 2
      let centerY = size.height / 2
      let orbitWidth = max(CGFloat.zero, size.width - 2)
      let orbitHeight = max(CGFloat.zero, size.height - 2)
      let outerRect = CGRect(x: 1, y: 1, width: orbitWidth, height: orbitHeight)
      let separatorColor = theme.palette.separator.swiftUIColor
      context.stroke(
        Path(ellipseIn: outerRect),
        with: .color(separatorColor),
        lineWidth: 1)
      let visible = Array(statuses.prefix(10))
      let itemCount = max(1, visible.count)
      let radiusX = max(CGFloat.zero, centerX - 4)
      let radiusY = max(CGFloat.zero, centerY - 3)
      for (index, status) in visible.enumerated() {
        let angle = CGFloat(index) / CGFloat(itemCount) * .pi * 2 - .pi / 2
        let pointX = centerX + cos(angle) * radiusX
        let pointY = centerY + sin(angle) * radiusY
        let dotRect = CGRect(x: pointX - 2, y: pointY - 2, width: 4, height: 4)
        let dotColor = theme.palette.color(for: status).swiftUIColor
        context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
      }
    }
  }
}

private struct CountSummary: View {
  let snapshot: IslandSnapshot
  let statuses: [IslandStatus]
  let theme: IslandTheme

  var body: some View {
    HStack(spacing: 8) {
      Text(String(format: "%02d", snapshot.sessions.count))
        .font(theme.typography.titleFace.swiftUIFont(size: 15, weight: .semibold))
        .foregroundStyle(theme.palette.primaryText.swiftUIColor)
      Text("SESSIONS")
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .tracking(1)
        .foregroundStyle(theme.palette.tertiaryText.swiftUIColor)
      Spacer(minLength: 4)
      HStack(spacing: 3) {
        ForEach(Array(statuses.prefix(8).enumerated()), id: \.offset) { _, status in
          Rectangle()
            .fill(theme.palette.color(for: status).swiftUIColor)
            .frame(width: 7, height: 2)
        }
      }
    }
  }
}

private struct VeinSummary: View {
  let statuses: [IslandStatus]
  let theme: IslandTheme

  var body: some View {
    Canvas { context, size in
      let visible = Array(statuses.prefix(8))
      let count = max(1, visible.count)
      for (index, status) in visible.enumerated() {
        let fraction = CGFloat(index + 1) / CGFloat(count + 1)
        let end = CGPoint(
          x: size.width * fraction,
          y: size.height * (index.isMultiple(of: 2) ? 0.25 : 0.75))
        var vein = Path()
        vein.move(to: CGPoint(x: size.width / 2, y: size.height / 2))
        vein.addCurve(
          to: end,
          control1: CGPoint(x: size.width * 0.42, y: size.height * fraction),
          control2: CGPoint(x: size.width * fraction, y: size.height / 2))
        context.stroke(
          vein,
          with: .color(theme.palette.color(for: status).swiftUIColor.opacity(0.82)),
          lineWidth: index == 0 ? 2 : 1)
        context.fill(
          Path(ellipseIn: CGRect(x: end.x - 2, y: end.y - 2, width: 4, height: 4)),
          with: .color(theme.palette.color(for: status).swiftUIColor))
      }
    }
  }
}

private struct SessionRow: View {
  let session: SessionDisplayItem
  let index: Int
  let theme: IslandTheme

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      HStack(alignment: .top, spacing: rowSpacing) {
        StatusGlyph(status: session.status, index: index, theme: theme)

        VStack(alignment: .leading, spacing: contentSpacing) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(session.title)
              .font(
                theme.typography.rowTitleFace.swiftUIFont(
                  size: theme.typography.rowTitleSize,
                  weight: theme.typography.rowTitleWeight))
              .foregroundStyle(theme.palette.primaryText.swiftUIColor.opacity(0.94))
              .lineLimit(1)
            Spacer(minLength: 5)
            Text(statusText)
              .font(
                IslandFontFace.monospaced.swiftUIFont(
                  size: theme.typography.rowStatusSize,
                  weight: .bold))
              .tracking(0.4)
              .foregroundStyle(theme.palette.color(for: session.status).swiftUIColor)
          }

          HStack(spacing: 6) {
            Text(styledDetailText)
              .font(
                theme.typography.rowDetailFace.swiftUIFont(
                  size: theme.typography.rowDetailSize,
                  weight: .regular))
              .foregroundStyle(theme.palette.secondaryText.swiftUIColor)
              .lineLimit(1)
            Spacer(minLength: 4)
            Text(elapsedText(now: context.date))
              .font(
                IslandFontFace.monospaced.swiftUIFont(
                  size: theme.typography.rowTimeSize,
                  weight: .medium))
              .foregroundStyle(theme.palette.tertiaryText.swiftUIColor)
          }

          if let progress = session.progress {
            HStack(spacing: 8) {
              ProgressRail(
                fraction: progress.fraction,
                color: theme.palette.color(for: session.status).swiftUIColor,
                theme: theme)
              Text("\(progress.completed)/\(progress.total)")
                .font(
                  IslandFontFace.monospaced.swiftUIFont(
                    size: theme.typography.rowStatusSize,
                    weight: .semibold))
                .foregroundStyle(theme.palette.tertiaryText.swiftUIColor)
            }
          } else if session.status == .running {
            HStack(spacing: 7) {
              ProgressView()
                .controlSize(.mini)
                .tint(theme.palette.color(for: session.status).swiftUIColor)
              Text("Progress not published")
                .font(
                  IslandFontFace.monospaced.swiftUIFont(
                    size: theme.typography.rowStatusSize,
                    weight: .medium))
                .foregroundStyle(theme.palette.tertiaryText.swiftUIColor)
            }
          }
        }
      }
      .padding(.leading, CGFloat(session.depth) * 18)
      .padding(.horizontal, rowHorizontalPadding)
      .padding(.vertical, rowVerticalPadding)
      .frame(minHeight: CGFloat(theme.metrics.rowHeight))
      .background { rowBackground }
      .overlay { rowOverlay }
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        "\(session.title), \(statusText), \(detailText), \(elapsedText(now: context.date))")
    }
  }

  private var rowSpacing: CGFloat {
    switch theme.chrome.rowStyle {
    case .ledger: return 9
    case .grid: return 10
    default: return 11
    }
  }

  private var contentSpacing: CGFloat {
    switch theme.chrome.rowStyle {
    case .card: return 6
    case .divider, .grid, .ledger, .vein: return 4
    }
  }

  private var rowHorizontalPadding: CGFloat {
    switch theme.chrome.rowStyle {
    case .card, .vein: return 11
    case .divider: return 6
    case .grid: return 8
    case .ledger: return 4
    }
  }

  private var rowVerticalPadding: CGFloat {
    switch theme.chrome.rowStyle {
    case .card: return 10
    case .divider, .grid, .ledger, .vein: return 8
    }
  }

  @ViewBuilder private var rowBackground: some View {
    let color = accentAwareRowColor
    switch theme.chrome.rowStyle {
    case .card:
      RoundedRectangle(cornerRadius: CGFloat(theme.metrics.rowCornerRadius), style: .continuous)
        .fill(color)
    case .divider, .grid, .ledger:
      Rectangle().fill(color)
    case .vein:
      RoundedRectangle(cornerRadius: CGFloat(theme.metrics.rowCornerRadius), style: .continuous)
        .fill(color)
    }
  }

  @ViewBuilder private var rowOverlay: some View {
    let statusColor = theme.palette.color(for: session.status).swiftUIColor
    switch theme.chrome.rowStyle {
    case .card:
      RoundedRectangle(cornerRadius: CGFloat(theme.metrics.rowCornerRadius), style: .continuous)
        .strokeBorder(statusColor.opacity(0.12), lineWidth: 1)
    case .divider:
      VStack { Spacer(); Rectangle().fill(theme.palette.separator.swiftUIColor).frame(height: 1) }
    case .grid:
      ZStack(alignment: .leading) {
        Rectangle().strokeBorder(theme.palette.separator.swiftUIColor, lineWidth: 1)
        Rectangle().fill(statusColor).frame(width: 2)
      }
    case .ledger:
      VStack { Spacer(); Rectangle().fill(theme.palette.separator.swiftUIColor).frame(height: 1) }
    case .vein:
      RoundedRectangle(cornerRadius: CGFloat(theme.metrics.rowCornerRadius), style: .continuous)
        .strokeBorder(statusColor.opacity(0.18), lineWidth: 1)
        .overlay(alignment: .leading) {
          Capsule().fill(statusColor.opacity(0.76)).frame(width: 2).padding(.vertical, 10)
        }
    }
  }

  private var accentAwareRowColor: Color {
    switch session.status {
    case .attention, .failure:
      return theme.palette.color(for: session.status).swiftUIColor
        .opacity(theme.palette.accentRowOpacity)
    default:
      return theme.palette.rowBackground.swiftUIColor
    }
  }

  private var styledDetailText: String {
    theme.typography.rowDetailUppercase ? detailText.uppercased() : detailText
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
  let theme: IslandTheme

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(theme.palette.separator.swiftUIColor)
        Capsule()
          .fill(color)
          .frame(width: max(4, proxy.size.width * min(max(fraction, 0), 1)))
      }
    }
    .frame(height: theme.chrome.rowStyle == .ledger ? 2 : 4)
    .accessibilityHidden(true)
  }
}

private struct StatusGlyph: View {
  let status: IslandStatus
  let index: Int
  let theme: IslandTheme

  var body: some View {
    glyph
      .frame(width: glyphSize, height: glyphSize)
      .accessibilityHidden(true)
  }

  @ViewBuilder private var glyph: some View {
    let color = theme.palette.color(for: status).swiftUIColor
    switch theme.chrome.glyphStyle {
    case .symbol:
      ZStack {
        Circle().fill(color.opacity(0.13))
        Circle().strokeBorder(color.opacity(0.34), lineWidth: 1)
        Image(systemName: statusSymbol(status))
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(color)
      }
    case .ring:
      ZStack {
        Circle().strokeBorder(theme.palette.separator.swiftUIColor, lineWidth: 1)
        Circle().strokeBorder(color.opacity(0.72), lineWidth: 2).padding(4)
        Circle().fill(color).frame(width: 4, height: 4)
      }
    case .geometric:
      ZStack {
        RoundedRectangle(cornerRadius: 4).strokeBorder(color.opacity(0.72), lineWidth: 1)
        Rectangle().fill(color.opacity(0.16)).padding(5).rotationEffect(.degrees(45))
        Image(systemName: statusSymbol(status))
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(color)
      }
    case .index:
      ZStack {
        Rectangle().strokeBorder(theme.palette.separator.swiftUIColor, lineWidth: 1)
        Text(String(format: "%02d", index + 1))
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .foregroundStyle(color)
      }
    case .organic:
      ZStack {
        Capsule().fill(color.opacity(0.12)).rotationEffect(.degrees(-28))
        Capsule().strokeBorder(color.opacity(0.62), lineWidth: 1).padding(4)
          .rotationEffect(.degrees(28))
        Circle().fill(color).frame(width: 5, height: 5)
      }
    }
  }

  private var glyphSize: CGFloat {
    min(30, max(26, CGFloat(theme.metrics.rowHeight) * 0.45))
  }
}

private struct ToolbarButton: View {
  let symbol: String
  let label: String
  let theme: IslandTheme
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(theme.palette.primaryText.swiftUIColor.opacity(0.62))
        .frame(width: 28, height: 28)
        .background(theme.palette.controlFill.swiftUIColor, in: Circle())
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
  }
}

private func statusSymbol(_ status: IslandStatus) -> String {
  switch status {
  case .attention: return "exclamationmark"
  case .failure: return "xmark"
  case .running: return "waveform.path"
  case .completed: return "checkmark"
  case .idle: return "minus"
  case .offline: return "bolt.slash"
  }
}

private func statusPriority(_ status: IslandStatus) -> Int {
  switch status {
  case .attention: return 0
  case .failure: return 1
  case .running: return 2
  case .completed: return 3
  case .idle: return 4
  case .offline: return 5
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
