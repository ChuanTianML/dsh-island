import XCTest

@testable import DSHIslandCore

final class IslandThemeTests: XCTestCase {
  func testThemeIdentitiesAndTaglinesAreStable() {
    XCTAssertEqual(
      IslandTheme.allCases.map(\.rawValue),
      ["original", "quiet", "orbital", "editorial", "pulse"])
    XCTAssertEqual(
      IslandTheme.allCases.map(\.displayName),
      ["Original Signal", "Quiet Glass", "Orbital Deck", "Editorial", "Pulse Garden"])
    XCTAssertEqual(
      IslandTheme.allCases.map(\.tagline),
      [
        "Shipped · clear · compact",
        "Native · calm · low-density",
        "Technical · focused · dense",
        "Typographic · ordered · distinct",
        "Ambient · legible · gentle",
      ])
  }

  func testResolveUsesOriginalAsFallback() {
    XCTAssertEqual(IslandTheme.fallback, .original)
    XCTAssertEqual(IslandTheme.resolve(nil), .original)
    XCTAssertEqual(IslandTheme.resolve("future-theme"), .original)
    XCTAssertEqual(IslandTheme.resolve("orbital"), .orbital)
  }

  func testExpandedHeightClampsRowsAndBounds() {
    for theme in IslandTheme.allCases {
      let metrics = theme.metrics
      XCTAssertEqual(metrics.expandedHeight(visibleRowCount: -5), metrics.minExpandedHeight)
      XCTAssertEqual(
        metrics.expandedHeight(visibleRowCount: 500),
        metrics.expandedHeight(visibleRowCount: metrics.maxVisibleRows))
      XCTAssertGreaterThanOrEqual(
        metrics.expandedHeight(visibleRowCount: 2), metrics.minExpandedHeight)
      XCTAssertLessThanOrEqual(
        metrics.expandedHeight(visibleRowCount: 2), metrics.maxExpandedHeight)
    }
  }

  func testOriginalMetricsPreserveShippedGeometry() {
    let metrics = IslandTheme.original.metrics

    XCTAssertEqual(metrics.collapsedWidth, 400)
    XCTAssertEqual(metrics.collapsedHeight, 68)
    XCTAssertEqual(metrics.expandedWidth, 500)
    XCTAssertEqual(metrics.collapsedCornerRadius, 34)
    XCTAssertEqual(metrics.expandedCornerRadius, 28)
    XCTAssertEqual(metrics.rowHeight, 69)
    XCTAssertEqual(metrics.rowSpacing, 7)
    XCTAssertEqual(metrics.maxVisibleRows, 5)
    XCTAssertEqual(metrics.minExpandedHeight, 280)
    XCTAssertEqual(metrics.maxExpandedHeight, 570)
  }

  func testThemePalettesHaveDistinctSurfaces() {
    let themes = IslandTheme.allCases
    for firstIndex in themes.indices {
      for secondIndex in themes.indices where secondIndex > firstIndex {
        XCTAssertNotEqual(themes[firstIndex].palette.surfaceTop, themes[secondIndex].palette.surfaceTop)
        XCTAssertNotEqual(
          themes[firstIndex].palette.surfaceBottom, themes[secondIndex].palette.surfaceBottom)
      }

      let palette = themes[firstIndex].palette
      let primaryStatuses = [
        palette.attention,
        palette.failure,
        palette.running,
        palette.completed,
      ]
      for colorIndex in primaryStatuses.indices {
        for otherIndex in primaryStatuses.indices where otherIndex > colorIndex {
          XCTAssertNotEqual(primaryStatuses[colorIndex], primaryStatuses[otherIndex])
        }
      }
    }
  }

  func testEditorialIsTheOnlyLightTheme() {
    XCTAssertEqual(
      IslandTheme.allCases.filter(\.chrome.prefersLightSurface),
      [.editorial])
  }

  func testEveryThemeUsesTheSameBlackWhale() {
    let expected = IslandColor(hex: 0x0505_05)
    XCTAssertTrue(IslandTheme.allCases.allSatisfy { $0.palette.whaleFill == expected })
  }

  func testMetricsAreValid() {
    for theme in IslandTheme.allCases {
      let metrics = theme.metrics
      let positiveValues = [
        metrics.collapsedWidth,
        metrics.collapsedHeight,
        metrics.expandedWidth,
        metrics.collapsedCornerRadius,
        metrics.expandedCornerRadius,
        metrics.rowHeight,
        metrics.headerPadding,
        metrics.listPadding,
        metrics.listVerticalPadding,
        metrics.toolbarHeight,
        metrics.summaryHeight,
        metrics.brandTileSize,
        metrics.chromeHeight,
        metrics.minExpandedHeight,
        metrics.maxExpandedHeight,
      ]
      XCTAssertTrue(positiveValues.allSatisfy { $0 > 0 }, "Invalid metrics for \(theme.rawValue)")
      XCTAssertGreaterThanOrEqual(metrics.rowSpacing, 0)
      XCTAssertGreaterThanOrEqual(metrics.rowCornerRadius, 0)
      XCTAssertGreaterThanOrEqual(metrics.brandCornerRadius, 0)
      XCTAssertGreaterThan(metrics.maxVisibleRows, 0)
      XCTAssertLessThanOrEqual(metrics.minExpandedHeight, metrics.maxExpandedHeight)
    }
  }

  func testHexColorAndOpacityReplacement() {
    let color = IslandColor(hex: 0x12_80_FF, opacity: 0.25)

    XCTAssertEqual(color.red, 0x12 as Double / 255, accuracy: 0.000_001)
    XCTAssertEqual(color.green, 0x80 as Double / 255, accuracy: 0.000_001)
    XCTAssertEqual(color.blue, 1, accuracy: 0.000_001)
    XCTAssertEqual(color.opacity, 0.25)
    XCTAssertEqual(
      color.withOpacity(0.75),
      IslandColor(red: color.red, green: color.green, blue: color.blue, opacity: 0.75))
  }

  func testWhalePathKeepsOfficialSubpaths() throws {
    let commands = IslandVectorPath.deepSeekWhale.commands
    let first = try XCTUnwrap(commands.first)
    let last = try XCTUnwrap(commands.last)

    guard case .move(let point) = first else {
      return XCTFail("The official whale must begin with a move command")
    }
    XCTAssertEqual(point, IslandVectorPoint(x: 22.9168, y: 1.43018))
    XCTAssertEqual(last, .close)
    XCTAssertEqual(IslandVectorPath.deepSeekWhaleViewBoxWidth, 23.16)
    XCTAssertEqual(IslandVectorPath.deepSeekWhaleViewBoxHeight, 17.04)
    XCTAssertEqual(commands.count, 80)
    XCTAssertEqual(
      commands.filter {
        if case .move = $0 { return true }
        return false
      }.count,
      4)
    XCTAssertEqual(
      commands.filter {
        if case .close = $0 { return true }
        return false
      }.count,
      4)
    XCTAssertEqual(
      commands.filter {
        if case .line = $0 { return true }
        return false
      }.count,
      1)
    XCTAssertEqual(
      commands.filter {
        if case .curve = $0 { return true }
        return false
      }.count,
      71)
  }

  func testParserSupportsRepeatedCoordinateGroups() {
    let path = IslandVectorPath.parse(
      "M 0 1 2 3 L 4 5 6 7 C 8 9 10 11 12 13 14 15 16 17 18 19 Z")

    XCTAssertEqual(
      path.commands,
      [
        .move(to: IslandVectorPoint(x: 0, y: 1)),
        .line(to: IslandVectorPoint(x: 2, y: 3)),
        .line(to: IslandVectorPoint(x: 4, y: 5)),
        .line(to: IslandVectorPoint(x: 6, y: 7)),
        .curve(
          control1: IslandVectorPoint(x: 8, y: 9),
          control2: IslandVectorPoint(x: 10, y: 11),
          to: IslandVectorPoint(x: 12, y: 13)),
        .curve(
          control1: IslandVectorPoint(x: 14, y: 15),
          control2: IslandVectorPoint(x: 16, y: 17),
          to: IslandVectorPoint(x: 18, y: 19)),
        .close,
      ])
  }

  func testMalformedInputReturnsLegalPrefix() {
    XCTAssertEqual(
      IslandVectorPath.parse("M0 0 L1 1 C2 2 3 3 4").commands,
      [
        .move(to: IslandVectorPoint(x: 0, y: 0)),
        .line(to: IslandVectorPoint(x: 1, y: 1)),
      ])
    XCTAssertEqual(
      IslandVectorPath.parse("M0 0 q 1 2 3 4").commands,
      [.move(to: IslandVectorPoint(x: 0, y: 0))])
  }
}
